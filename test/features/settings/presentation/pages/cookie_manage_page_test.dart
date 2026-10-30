import 'package:flutter/material.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/di/storage_provider.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/network/cookie_manager.dart';
import 'package:flutter_reader/core/network/cookie_store.dart';
import 'package:flutter_reader/core/theme/app_theme.dart';
import 'package:flutter_reader/features/settings/presentation/pages/cookie_manage_page.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

/// One stored cookie, expiring at [expiresAt] (or a session cookie).
StoredCookie _cookie(
  String domain,
  String name, {
  DateTime? expiresAt,
  bool isDeletion = false,
}) => StoredCookie(
  domain: domain,
  path: '/',
  name: name,
  value: '$name-value',
  isSecure: false,
  isDeletion: isDeletion,
  expiresAt: expiresAt,
);

/// A store that answers [rows] and records what the page asked to delete.
final class _FakeStore implements CookieStore {
  _FakeStore(this.rows);

  List<StoredCookie> rows;

  /// Every deletion the page asked for, in order.
  final List<String> calls = <String>[];

  @override
  Future<List<StoredCookie>> loadAll() async => rows;

  @override
  Future<void> save(StoredCookie cookie) async {}

  @override
  Future<void> remove(StoredCookie cookie) async {
    calls.add('remove|${cookie.domain}|${cookie.name}');
    rows = <StoredCookie>[
      for (final StoredCookie row in rows)
        if (row.domain != cookie.domain || row.name != cookie.name) row,
    ];
  }

  @override
  Future<int> deleteExpired(DateTime now) async {
    calls.add('expired');
    final int before = rows.length;
    rows = <StoredCookie>[
      for (final StoredCookie row in rows)
        if (row.expiresAt == null || !row.isExpiredAt(now)) row,
    ];

    return before - rows.length;
  }

  @override
  Future<int> deleteByDomain(String domain) async {
    calls.add('domain|$domain');
    final int before = rows.length;
    rows = <StoredCookie>[
      for (final StoredCookie row in rows)
        if (row.domain != domain) row,
    ];

    return before - rows.length;
  }

  @override
  Future<int> deleteAll() async {
    calls.add('all');
    final int before = rows.length;
    rows = <StoredCookie>[];

    return before;
  }
}

/// Pumps the page over [store].
Future<void> _pump(WidgetTester tester, _FakeStore store) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        cookieStoreProvider.overrideWithValue(store),
        appLoggerProvider.overrideWithValue(AppLogger()),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildReaderTheme(fallbackLightColorScheme()),
        home: const CookieManagePage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The page's own strings.
AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(CookieManagePage)));

void main() {
  group('CookieManagePage', () {
    testWidgets('build_givenStoredCookies_groupsThemByDomain', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        _FakeStore(<StoredCookie>[
          _cookie('a.test', 'token'),
          _cookie('a.test', 'sid'),
          _cookie('b.test', 'token'),
        ]),
      );
      final AppLocalizations l10n = _l10n(tester);

      expect(find.text('a.test'), findsOneWidget);
      expect(find.text('b.test'), findsOneWidget);
      expect(find.text('token'), findsNWidgets(2));
      expect(find.text('sid'), findsOneWidget);
      // 值是凭据，不显示（ADR-0072 §决策 2）。
      expect(find.textContaining('token-value'), findsNothing);
      expect(find.text(l10n.cookieManageSession), findsNWidgets(3));
    });

    testWidgets('build_givenNoCookie_showsTheEmptyState', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _FakeStore(<StoredCookie>[]));

      expect(find.text(_l10n(tester).cookieManageEmpty), findsOneWidget);
    });

    testWidgets('build_givenAnExpiringCookie_showsWhenItExpires', (
      WidgetTester tester,
    ) async {
      final DateTime expiry = DateTime(2026, 11, 1, 12);
      await _pump(
        tester,
        _FakeStore(<StoredCookie>[_cookie('a.test', 't', expiresAt: expiry)]),
      );

      // 页面用平台短日期 + 时间格式化（不带毫秒），测试按同一套本地化算期望值。
      final DateTime local = expiry.toLocal();
      final MaterialLocalizations material = MaterialLocalizations.of(
        tester.element(find.byType(CookieManagePage)),
      );
      final String moment =
          '${material.formatShortDate(local)} '
          '${material.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';

      expect(
        find.textContaining(_l10n(tester).cookieManageExpiresAt(moment)),
        findsOneWidget,
      );
    });

    testWidgets('delete_whenPressed_removesOnlyThatCookie', (
      WidgetTester tester,
    ) async {
      final _FakeStore store = _FakeStore(<StoredCookie>[
        _cookie('a.test', 'token'),
        _cookie('a.test', 'sid'),
      ]);
      await _pump(tester, store);

      await tester.tap(find.byTooltip(_l10n(tester).cookieManageDelete).first);
      await tester.pumpAndSettle();

      expect(store.calls.single, 'remove|a.test|token');
      expect(find.text('sid'), findsOneWidget);
      expect(find.text('token'), findsNothing);
    });

    testWidgets('clearDomain_whenPressed_dropsThatDomainOnly', (
      WidgetTester tester,
    ) async {
      final _FakeStore store = _FakeStore(<StoredCookie>[
        _cookie('a.test', 'token'),
        _cookie('b.test', 'token'),
      ]);
      await _pump(tester, store);

      await tester.tap(
        find.byTooltip(_l10n(tester).cookieManageClearDomain).first,
      );
      await tester.pumpAndSettle();

      expect(store.calls.single, 'domain|a.test');
      expect(find.text('b.test'), findsOneWidget);
      expect(find.text('a.test'), findsNothing);
    });

    testWidgets('menu_whenExpiredIsChosen_clearsExpiredCookies', (
      WidgetTester tester,
    ) async {
      final _FakeStore store = _FakeStore(<StoredCookie>[
        _cookie('a.test', 'old', expiresAt: DateTime(2020)),
        _cookie('a.test', 'new'),
      ]);
      await _pump(tester, store);

      await tester.tap(find.byTooltip(_l10n(tester).cookieManageMore));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_l10n(tester).cookieManageClearExpired));
      await tester.pumpAndSettle();

      expect(store.calls.single, 'expired');
      expect(find.text('old'), findsNothing);
      expect(find.text('new'), findsOneWidget);
    });

    testWidgets('menu_whenClearAllIsConfirmed_emptiesTheJar', (
      WidgetTester tester,
    ) async {
      final _FakeStore store = _FakeStore(<StoredCookie>[
        _cookie('a.test', 'token'),
      ]);
      await _pump(tester, store);
      final AppLocalizations l10n = _l10n(tester);

      await tester.tap(find.byTooltip(l10n.cookieManageMore));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.cookieManageClearAll));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.actionDelete));
      await tester.pumpAndSettle();

      expect(store.calls.single, 'all');
      expect(find.text(l10n.cookieManageEmpty), findsOneWidget);
    });
  });
}
