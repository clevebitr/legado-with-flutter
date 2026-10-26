import 'package:flutter/material.dart';
import 'package:flutter_reader/core/widgets/state_message.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_record.dart';
import 'package:flutter_reader/features/reader/domain/reading_record_days.dart';
import 'package:flutter_reader/features/reader/presentation/notifiers/reading_records_notifier.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reading_record_tile.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_design/m3e_design.dart';

/// What the user read, grouped by day (`docs/dev/roadmap.md` M19).
///
/// The grouping is a pure domain function ([groupRecordsByDay]) so the page only renders: a day
/// header with that day's total, then one row per session. Rules are read-only — the reader
/// appends them on exit (ADR-0066 §决策 4) — so there is no delete action here.
class ReadingRecordsPage extends ConsumerWidget {
  /// Creates the page.
  const ReadingRecordsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;
    final AsyncValue<List<ReadingRecord>> records = ref.watch(
      readingRecordsProvider,
    );

    return Scaffold(
      backgroundColor: tokens.colors.surface,
      appBar: AppBar(
        title: Text(l10n.readingRecordsTitle),
        backgroundColor: tokens.colors.surface,
      ),
      body: switch (records) {
        AsyncData<List<ReadingRecord>>(:final List<ReadingRecord> value) =>
          value.isEmpty
              ? StateMessage(
                  message: l10n.readingRecordsEmpty,
                  icon: Icons.history,
                )
              : _days(context, groupRecordsByDay(value), tokens, l10n),
        AsyncError<List<ReadingRecord>>() => StateMessage(
          message: l10n.readingRecordsLoadFailed,
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  /// Builds one section per day (C-PERF-2: the flattened rows are built lazily).
  Widget _days(
    BuildContext context,
    List<ReadingRecordDay> days,
    M3ETheme tokens,
    AppLocalizations l10n,
  ) {
    final MaterialLocalizations material = MaterialLocalizations.of(context);

    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.sm),
      itemCount: days.length,
      itemBuilder: (BuildContext context, int index) {
        final ReadingRecordDay day = days[index];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(
                tokens.spacing.lg,
                tokens.spacing.md,
                tokens.spacing.lg,
                tokens.spacing.xs,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      material.formatFullDate(day.day),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.typography.base.titleSmall,
                    ),
                  ),
                  SizedBox(width: tokens.spacing.sm),
                  Text(
                    readingDurationLabel(l10n, day.total),
                    style: tokens.typography.base.labelMedium,
                  ),
                ],
              ),
            ),
            // 一天可能有十几条会话，数量有限，不需要再套一层懒加载列表。
            for (final ReadingRecord record in day.records)
              ReadingRecordTile(record: record, showBookName: true),
          ],
        );
      },
    );
  }
}
