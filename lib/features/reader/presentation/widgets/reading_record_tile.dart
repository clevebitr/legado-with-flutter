import 'package:flutter/material.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_record.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:m3e_design/m3e_design.dart';

/// One reading session as a list row (`docs/dev/roadmap.md` M19).
///
/// It is shared by the two record pages — 「按天」 shows the book title, 「按书」 does not (every row
/// there is the same book) — and it is a [ListTile] so the row has an accessible name from its own
/// text (C-UI-7).
class ReadingRecordTile extends StatelessWidget {
  /// Creates the row for [record].
  const ReadingRecordTile({
    required this.record,
    required this.showBookName,
    super.key,
  });

  /// The session to show.
  final ReadingRecord record;

  /// Whether the title line is the book (the day view) or the chapter (the book view).
  final bool showBookName;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;
    final String chapter = record.chapterName ?? '';
    final String? subtitle = switch (showBookName) {
      true when chapter.isNotEmpty => chapter,
      _ => null,
    };

    return ListTile(
      title: Text(switch (showBookName) {
        true => record.bookName,
        false => chapter.isEmpty ? record.bookName : chapter,
      }),
      subtitle: Text(
        subtitle == null
            ? _timeRange(context, record)
            : '${_timeRange(context, record)} · $subtitle',
      ),
      trailing: Text(
        readingDurationLabel(l10n, Duration(seconds: record.durationSeconds)),
        style: tokens.typography.base.labelMedium,
      ),
    );
  }

  /// The start and end of the session in the platform's localized time format.
  String _timeRange(BuildContext context, ReadingRecord record) {
    final MaterialLocalizations material = MaterialLocalizations.of(context);
    final TimeOfDay start = TimeOfDay.fromDateTime(record.startedAt.toLocal());
    final TimeOfDay end = TimeOfDay.fromDateTime(record.endedAt.toLocal());

    return '${material.formatTimeOfDay(start)} – '
        '${material.formatTimeOfDay(end)}';
  }
}

/// Formats [duration] the way both record pages show it.
///
/// A session below a minute cannot reach this helper (the store drops it, ADR-0066 §决策 4), so the
/// "less than a minute" fallback exists only for a day total that rounds there.
String readingDurationLabel(AppLocalizations l10n, Duration duration) {
  final int minutes = duration.inMinutes;
  if (minutes < 1) {
    return l10n.readingRecordMinutes(1);
  }
  if (minutes < 60) {
    return l10n.readingRecordMinutes(minutes);
  }
  final int hours = minutes ~/ 60;
  final int rest = minutes % 60;

  return rest == 0
      ? l10n.readingRecordHours(hours)
      : l10n.readingRecordHoursMinutes(hours, rest);
}
