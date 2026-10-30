import 'package:flutter/material.dart';
import 'package:flutter_reader/core/utils/clock.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_status_bar.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_reader_platform_ports.dart';

/// A clock frozen at one instant.
final class _FixedClock implements Clock {
  _FixedClock(this._now);

  final DateTime _now;

  @override
  DateTime now() => _now;
}

/// Pumps the status line with [battery] and a fixed clock at 09:05.
Future<void> _pump(
  WidgetTester tester, {
  required FakeBatteryLevel battery,
  String progressText = '第 1/2 章 · 本章 35%',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ReaderStatusBar(
          progressText: progressText,
          clock: _FixedClock(DateTime(2026, 10, 28, 9, 5)),
          battery: battery,
          foreground: const Color(0xFF000000),
        ),
      ),
    ),
  );
  // 电量是异步读的：等它落地。
  await tester.pump();
}

void main() {
  group('ReaderStatusBar', () {
    testWidgets('build_givenACharge_showsChapterProgressAndCharge', (
      WidgetTester tester,
    ) async {
      final FakeBatteryLevel battery = FakeBatteryLevel(level: 80);

      await _pump(tester, battery: battery);

      expect(find.text('第 1/2 章 · 本章 35%'), findsOneWidget);
      // 时间与电量：沉浸式把两者都藏起来了，状态栏负责放回来。
      expect(find.textContaining('9:05'), findsOneWidget);
      expect(find.textContaining('80% battery'), findsOneWidget);
      expect(battery.reads, 1);
    });

    testWidgets('build_givenAnUnknownCharge_omitsIt', (
      WidgetTester tester,
    ) async {
      await _pump(tester, battery: FakeBatteryLevel(level: null));

      expect(find.textContaining('9:05'), findsOneWidget);
      // 读不到电量就不写：不画假数字（C-UI-7）。
      expect(find.textContaining('battery'), findsNothing);
    });

    testWidgets('build_givenTheLine_isNotInteractive', (
      WidgetTester tester,
    ) async {
      await _pump(tester, battery: FakeBatteryLevel());

      // 状态栏盖在正文上：它必须让点击穿过去，否则三区点击会少一条边。
      expect(
        find.descendant(
          of: find.byType(ReaderStatusBar),
          matching: find.byType(IgnorePointer),
        ),
        findsOneWidget,
      );
    });
  });
}
