// 私有字段不能做具名初始化形参，手写赋值是必要的。
// ignore_for_file: prefer_initializing_formals

import 'dart:io' show HttpDate, HttpException;

import 'package:flutter_reader/core/utils/clock.dart';

/// Stores cookies per domain and applies them to later requests.
///
/// Business code never builds a `Cookie` header itself; the HTTP client asks this manager.
abstract interface class CookieManager {
  /// Returns the `Cookie` header value for [url], or `null` when none apply.
  String? cookieHeaderFor(Uri url);

  /// Stores the cookies of the `Set-Cookie` headers returned for [url].
  ///
  /// Unparsable headers are ignored.
  void storeFromResponse(Uri url, List<String> setCookieHeaders);
}

/// In-memory [CookieManager].
final class InMemoryCookieManager implements CookieManager {
  /// Creates the jar; [clock] decides when a cookie has expired.
  InMemoryCookieManager({Clock clock = const SystemClock()}) : _clock = clock;

  final Clock _clock;

  // cookie 先按 domain、再按名称存放。
  final Map<String, Map<String, StoredCookie>> _cookiesByDomain =
      <String, Map<String, StoredCookie>>{};

  @override
  String? cookieHeaderFor(Uri url) {
    final String host = url.host.toLowerCase();
    final List<String> pairs = <String>[];
    final DateTime now = _clock.now();

    for (final MapEntry<String, Map<String, StoredCookie>> entry
        in _cookiesByDomain.entries) {
      if (!_hostMatchesDomain(host, entry.key)) {
        continue;
      }
      for (final StoredCookie cookie in entry.value.values) {
        if (cookie.isExpiredAt(now)) {
          continue;
        }
        if (cookie.matchesPath(url) &&
            (!cookie.isSecure || url.scheme == 'https')) {
          pairs.add('${cookie.name}=${cookie.value}');
        }
      }
    }

    return pairs.isEmpty ? null : pairs.join('; ');
  }

  @override
  void storeFromResponse(Uri url, List<String> setCookieHeaders) {
    for (final String header in setCookieHeaders) {
      final StoredCookie? cookie = StoredCookie.parse(
        url,
        header,
        now: _clock.now(),
      );
      if (cookie != null) {
        store(cookie);
      }
    }
  }

  /// Stores one parsed cookie.
  void store(StoredCookie cookie) {
    final Map<String, StoredCookie> cookies = _cookiesByDomain.putIfAbsent(
      cookie.domain,
      () => <String, StoredCookie>{},
    );
    if (cookie.isDeletion) {
      cookies.remove(cookie.name);
    } else {
      cookies[cookie.name] = cookie;
    }
  }

  /// Every stored cookie, expired ones included (the persistent jar purges them).
  List<StoredCookie> get all => <StoredCookie>[
    for (final Map<String, StoredCookie> byName in _cookiesByDomain.values)
      ...byName.values,
  ];

  /// Replaces the whole jar (hydration from storage).
  void replaceAll(Iterable<StoredCookie> cookies) {
    _cookiesByDomain.clear();
    for (final StoredCookie cookie in cookies) {
      store(cookie);
    }
  }
}

/// One stored cookie.
///
/// Shared by persistence and the WebView bridge so both use the same shape.
final class StoredCookie {
  /// Creates one stored cookie.
  const StoredCookie({
    required this.name,
    required this.value,
    required this.domain,
    required this.path,
    required this.isSecure,
    required this.isDeletion,
    this.expiresAt,
  });

  /// Parses one `Set-Cookie` header, or returns `null` when it has no usable `name=value` pair.
  ///
  /// [now] resolves `Max-Age` into an absolute instant.
  static StoredCookie? parse(Uri url, String header, {required DateTime now}) {
    final List<String> parts = header.split(';');
    final List<String> pair = parts.first.split('=');
    final String name = pair.first.trim();
    if (pair.length < 2 || name.isEmpty) {
      return null;
    }

    // 值里可能含 '='（base64 填充），所以只按第一个 '=' 切分。
    final String value = pair.sublist(1).join('=').trim();
    String? domainAttribute;
    String path = '/';
    bool isSecure = false;
    bool isDeletion = value.isEmpty;
    DateTime? expiresAt;

    for (final String attribute in parts.skip(1)) {
      final List<String> attributePair = attribute.split('=');
      final String attributeName = attributePair.first.trim().toLowerCase();
      final String attributeValue = attributePair.length > 1
          ? attributePair.sublist(1).join('=').trim()
          : '';

      switch (attributeName) {
        case 'domain':
          domainAttribute = attributeValue;
        case 'path':
          if (attributeValue.isNotEmpty) {
            path = attributeValue;
          }
        case 'secure':
          isSecure = true;
        case 'max-age':
          // Max-Age <= 0 是删除指令，正数换算成绝对时间。
          final int? seconds = int.tryParse(attributeValue);
          if (seconds != null && seconds <= 0) {
            isDeletion = true;
          } else if (seconds != null) {
            expiresAt = now.add(Duration(seconds: seconds));
          }
        case 'expires':
          // 只认 HTTP-date 的常见写法；解析不了就当作会话 cookie。
          expiresAt = _parseHttpDate(attributeValue) ?? expiresAt;
        default:
          // httponly / samesite 等不参与本仓的判定。
          break;
      }
    }

    return StoredCookie(
      name: name,
      value: value,
      domain: _cookieDomain(url, domainAttribute) ?? url.host.toLowerCase(),
      path: path,
      isSecure: isSecure,
      isDeletion: isDeletion,
      expiresAt: expiresAt,
    );
  }

  /// Cookie name.
  final String name;

  /// Cookie value.
  final String value;

  /// Cookie domain (no leading dot).
  final String domain;

  /// Cookie path, `/` when the server said nothing.
  final String path;

  /// Whether the cookie may only travel over HTTPS.
  final bool isSecure;

  /// Whether this “cookie” is the server's deletion instruction.
  final bool isDeletion;

  /// When the cookie stops being valid, or `null` for a session cookie.
  final DateTime? expiresAt;

  /// Whether the cookie has expired at [now]; expired cookies are neither sent nor persisted.
  bool isExpiredAt(DateTime now) {
    final DateTime? expires = expiresAt;

    return expires != null && !expires.isAfter(now);
  }

  /// Whether this cookie applies to [url]'s path.
  bool matchesPath(Uri url) =>
      url.path == path ||
      url.path.startsWith(path.endsWith('/') ? path : '$path/');

  // 只接受属于 [url] 且含点的 domain；未实现公共后缀列表。
  static String? _cookieDomain(Uri url, String? attributeValue) {
    final String? domain = attributeValue?.toLowerCase().replaceFirst(
      RegExp(r'^\.'),
      '',
    );
    if (domain == null || domain.isEmpty || !domain.contains('.')) {
      return null;
    }
    final String host = url.host.toLowerCase();

    return host == domain || host.endsWith('.$domain') ? domain : null;
  }
}

bool _hostMatchesDomain(String host, String domain) =>
    host == domain || host.endsWith('.$domain');

// 解析失败按「无过期信息」处理，当作会话 cookie。
DateTime? _parseHttpDate(String value) {
  try {
    return HttpDate.parse(value);
  } on HttpException {
    // HttpDate.parse 抛的是 HttpException，不是 FormatException。
    return null;
  }
}
