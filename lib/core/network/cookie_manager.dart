/// Stores cookies per domain and applies them to later requests (C-NET-5).
///
/// Business code never builds a `Cookie` header itself; the HTTP client asks
/// this manager instead.
///
/// Cookies live for the lifetime of the process. The positive `Max-Age` and
/// `Expires` attributes are **not** enforced yet, because that needs an injected
/// clock (`docs/dev/testing.md` §4) and belongs with cookie persistence in a
/// later phase; deletion (`Max-Age=0` or an empty value) needs no clock and is
/// honoured today. Expiring cookies later than the server asked would be unsafe,
/// so the process lifetime is the only bound — document it when persistence
/// lands.
abstract interface class CookieManager {
  /// Returns the `Cookie` header value for [url], or `null` when none apply.
  String? cookieHeaderFor(Uri url);

  /// Stores the cookies of the `Set-Cookie` headers returned for [url].
  ///
  /// Unparsable headers are ignored: a malformed cookie must not break the
  /// session that is already stored.
  void storeFromResponse(Uri url, List<String> setCookieHeaders);
}

/// In-memory [CookieManager].
final class InMemoryCookieManager implements CookieManager {
  /// Cookies keyed by cookie domain, then by name.
  final Map<String, Map<String, _StoredCookie>> _cookiesByDomain =
      <String, Map<String, _StoredCookie>>{};

  @override
  String? cookieHeaderFor(Uri url) {
    final String host = url.host.toLowerCase();
    final List<String> pairs = <String>[];

    for (final MapEntry<String, Map<String, _StoredCookie>> entry
        in _cookiesByDomain.entries) {
      if (!_hostMatchesDomain(host, entry.key)) {
        continue;
      }
      for (final _StoredCookie cookie in entry.value.values) {
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
      final _StoredCookie? cookie = _StoredCookie.parse(url, header);
      if (cookie == null) {
        continue;
      }
      final Map<String, _StoredCookie> cookies = _cookiesByDomain.putIfAbsent(
        cookie.domain,
        () => <String, _StoredCookie>{},
      );
      if (cookie.isDeletion) {
        cookies.remove(cookie.name);
      } else {
        cookies[cookie.name] = cookie;
      }
    }
  }
}

/// One stored cookie.
final class _StoredCookie {
  const _StoredCookie({
    required this.name,
    required this.value,
    required this.domain,
    required this.path,
    required this.isSecure,
    required this.isDeletion,
  });

  /// Parses one `Set-Cookie` header, or returns `null` when it carries no usable
  /// `name=value` pair.
  static _StoredCookie? parse(Uri url, String header) {
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
          // Max-Age=0 是删除指令，不需要时钟；正数过期时间见类文档。
          if (int.tryParse(attributeValue) == 0) {
            isDeletion = true;
          }
        default:
          // expires / httponly / samesite 等暂不参与判定（见类文档）。
          break;
      }
    }

    return _StoredCookie(
      name: name,
      value: value,
      domain: _cookieDomain(url, domainAttribute) ?? url.host.toLowerCase(),
      path: path,
      isSecure: isSecure,
      isDeletion: isDeletion,
    );
  }

  final String name;
  final String value;
  final String domain;
  final String path;
  final bool isSecure;
  final bool isDeletion;

  /// Whether this cookie applies to [url]'s path.
  bool matchesPath(Uri url) =>
      url.path == path ||
      url.path.startsWith(path.endsWith('/') ? path : '$path/');

  /// Returns the domain the cookie may be stored for, or `null` when the
  /// attribute is absent or does not belong to [url] (RFC 6265 §5.3.6).
  ///
  /// A public suffix list is not implemented, so a single-label domain such as
  /// `com` is rejected by requiring a dot; deeper suffix rules are out of scope.
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

/// Whether [host] belongs to cookie [domain].
bool _hostMatchesDomain(String host, String domain) =>
    host == domain || host.endsWith('.$domain');
