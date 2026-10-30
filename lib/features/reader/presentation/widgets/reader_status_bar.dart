import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reader/core/platform/battery_level.dart';
import 'package:flutter_reader/core/utils/clock.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:m3e_design/m3e_design.dart';

/// How often the status line re-reads the clock and the charge.
const Duration readerStatusRefresh = Duration(seconds: 30);

/// The reading view's status line: chapter, progress, time and charge
/// (`docs/dev/adr/0086-reader-comfort-and-status-bar.md` §决策 6).
///
/// Upstream lets the reader configure a header and a footer (`BgTextConfigSheet.kt`); this is the
/// first slice of that: one line, at the bottom, always visible while reading, showing what a
/// reader actually looks at — which chapter and how far, plus the two system facts the immersive
/// chrome hides (time and charge).
///
/// It is **display only**: no taps, no gestures (`IgnorePointer`), so the reader's three tap zones
/// keep working straight through it.
class ReaderStatusBar extends StatefulWidget {
  /// Creates the status line.
  const ReaderStatusBar({
    required this.progressText,
    required this.clock,
    required this.battery,
    required this.foreground,
    super.key,
  });

  /// The position text, already localized by the caller (`第 2/10 章 · 本章 35%`).
  final String progressText;

  /// The injectable clock (C-TEST: no `DateTime.now()` in tested code).
  final Clock clock;

  /// The charge reader; platforms without one answer `null` and the line omits the charge.
  final BatteryLevel battery;

  /// The colour of the body text, so the line reads as part of the page.
  final Color foreground;

  @override
  State<ReaderStatusBar> createState() => _ReaderStatusBarState();
}

/// State of the status line: the clock tick and the last known charge.
class _ReaderStatusBarState extends State<ReaderStatusBar> {
  Timer? _timer;
  int? _charge;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(readerStatusRefresh, (_) => _refresh());
    unawaited(_readCharge());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;
    final TextStyle style =
        (tokens.typography.base.labelSmall ?? const TextStyle()).copyWith(
          color: widget.foreground.withValues(alpha: 0.72),
        );
    final String time = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(widget.clock.now()),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    final int? charge = _charge;

    return IgnorePointer(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.md,
          vertical: tokens.spacing.xs,
        ),
        child: Row(
          children: <Widget>[
            // 章节名不在这里：正文里每章都有一个章头（ADR-0086 §决策 7），
            // 状态栏再写一遍就是同一个标题出现在两处。
            Expanded(child: Text(widget.progressText, style: style)),
            SizedBox(width: tokens.spacing.md),
            Text(
              charge == null
                  ? time
                  : '$time  ${l10n.readerBatteryLevel(charge)}',
              style: style,
            ),
          ],
        ),
      ),
    );
  }

  /// Re-reads the charge, so the line follows a long session.
  Future<void> _readCharge() async {
    final int? level = await widget.battery.read();
    if (!mounted || level == _charge) {
      return;
    }
    setState(() => _charge = level);
  }

  /// Ticks the clock and the charge; the build reads the clock itself.
  void _refresh() {
    if (!mounted) {
      return;
    }
    setState(() {});
    unawaited(_readCharge());
  }
}
