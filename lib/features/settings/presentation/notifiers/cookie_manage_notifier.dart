import 'package:flutter_reader/core/di/clock_provider.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/di/storage_provider.dart';
import 'package:flutter_reader/core/network/cookie_manager.dart';
import 'package:flutter_reader/core/network/cookie_store.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'cookie_manage_notifier.g.dart';

/// One domain's worth of cookies, as the page shows them
/// (`docs/dev/roadmap.md` M22, ADR-0072 §决策 2).
typedef CookieDomainGroup = ({String domain, List<StoredCookie> cookies});

/// The cookie jar, grouped by domain, and the ways to drop it.
///
/// The jar is **global by domain** on purpose: per-source isolation is registered as open
/// (`roadmap.md` §3.7), so this page is the honest view of what is stored — not a per-source one it
/// could not deliver.
@riverpod
class CookieManage extends _$CookieManage {
  @override
  Future<List<CookieDomainGroup>> build() async {
    final CookieStore store = ref.watch(cookieStoreProvider);
    final List<StoredCookie> cookies = await store.loadAll();
    final Map<String, List<StoredCookie>> byDomain =
        <String, List<StoredCookie>>{};
    for (final StoredCookie cookie in cookies) {
      byDomain.putIfAbsent(cookie.domain, () => <StoredCookie>[]).add(cookie);
    }
    final List<String> domains = byDomain.keys.toList()..sort();

    return <CookieDomainGroup>[
      for (final String domain in domains)
        (domain: domain, cookies: byDomain[domain]!),
    ];
  }

  /// Drops one cookie.
  Future<void> remove(StoredCookie cookie) =>
      _apply((CookieStore store) => store.remove(cookie));

  /// Drops every cookie of one domain.
  Future<void> clearDomain(String domain) =>
      _apply((CookieStore store) => store.deleteByDomain(domain));

  /// Drops every expired cookie.
  Future<void> clearExpired() => _apply(
    (CookieStore store) => store.deleteExpired(ref.read(clockProvider).now()),
  );

  /// Drops the whole jar.
  Future<void> clearAll() => _apply((CookieStore store) => store.deleteAll());

  Future<void> _apply(Future<Object?> Function(CookieStore store) write) async {
    final CookieStore store = ref.read(cookieStoreProvider);

    try {
      await write(store);
    } on Exception catch (error, stackTrace) {
      // C-ERR-2 的 presentation 兜底：删不掉不该把页面变成错误态，重读后照旧显示真相。
      ref
          .read(appLoggerProvider)
          .warning('Changing the cookie jar failed.', error, stackTrace);
    }

    state = await AsyncValue.guard<List<CookieDomainGroup>>(build);
  }
}
