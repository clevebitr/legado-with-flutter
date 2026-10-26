import 'dart:async';

import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/network/cookie_manager.dart';
import 'package:flutter_reader/core/network/cookie_store.dart';
import 'package:flutter_reader/core/utils/clock.dart';

// 私有字段不能做具名初始化形参，三个参数只能手写赋值。
// ignore_for_file: prefer_initializing_formals

/// The app's cookie jar: memory for reads, storage for the next launch.
/// Reads stay synchronous, writes are write-through, and the jar is shared with the WebView.
final class PersistentCookieManager implements CookieManager {
  /// Creates the jar on top of [store]; the clock decides expiry.
  PersistentCookieManager({
    required CookieStore store,
    required Clock clock,
    required AppLogger logger,
  }) : _store = store,
       _clock = clock,
       _memory = InMemoryCookieManager(clock: clock),
       _logger = logger;

  final CookieStore _store;
  final Clock _clock;
  final InMemoryCookieManager _memory;
  final AppLogger _logger;

  /// Loads the stored jar and drops entries that expired since the last launch.
  ///
  /// Called once at startup; a failure leaves an empty jar (the user may have to log in again).
  Future<void> hydrate() async {
    final List<StoredCookie> stored = await _store.loadAll();
    final DateTime now = _clock.now();
    final List<StoredCookie> alive = stored
        .where((StoredCookie cookie) => !cookie.isExpiredAt(now))
        .toList();
    _memory.replaceAll(alive);
    if (alive.length != stored.length) {
      unawaited(_store.deleteExpired(now));
    }
  }

  @override
  String? cookieHeaderFor(Uri url) => _memory.cookieHeaderFor(url);

  @override
  void storeFromResponse(Uri url, List<String> setCookieHeaders) {
    for (final String header in setCookieHeaders) {
      final StoredCookie? cookie = StoredCookie.parse(
        url,
        header,
        now: _clock.now(),
      );
      if (cookie != null) {
        _storeOne(cookie);
      }
    }
  }

  /// Takes over the cookies a visible WebView collected.
  ///
  /// The WebView is authoritative for its domain: an expired or empty cookie here is a deletion.
  Future<void> importFromWebView(Iterable<StoredCookie> cookies) async {
    final List<StoredCookie> imported = cookies.toList();
    if (imported.isEmpty) {
      _logger.debug('The verification page returned no cookies.');
    }
    for (final StoredCookie cookie in imported) {
      _storeOne(cookie);
    }
    await Future<void>.value();
  }

  /// The stored cookies that apply to [url], used to seed the verification WebView.
  List<StoredCookie> cookiesFor(Uri url) {
    final String header = _memory.cookieHeaderFor(url) ?? '';
    if (header.isEmpty) {
      return const <StoredCookie>[];
    }
    final Set<String> names = header
        .split('; ')
        .map((String pair) => pair.split('=').first)
        .toSet();

    return _memory.all
        .where(
          (StoredCookie cookie) =>
              names.contains(cookie.name) && !cookie.isDeletion,
        )
        .toList();
  }

  // 删除或已过期的 cookie 从存储移除，其余写穿。
  void _storeOne(StoredCookie cookie) {
    _memory.store(cookie);
    if (cookie.isDeletion || cookie.isExpiredAt(_clock.now())) {
      unawaited(_store.remove(cookie));

      return;
    }
    unawaited(_store.save(cookie));
  }
}
