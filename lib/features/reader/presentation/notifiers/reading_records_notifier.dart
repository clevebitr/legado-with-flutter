import 'package:flutter_reader/features/reader/di.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_record.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reading_records_notifier.g.dart';

/// The most recent reading sessions across every book (`docs/dev/roadmap.md` M19).
///
/// Read-only: records are appended by the reader on exit (ADR-0066 §决策 4), so there is no
/// mutation to expose here. The page groups the rows by day with the pure helper in
/// `domain/reading_record_days.dart` rather than asking the database for a second projection.
@riverpod
Future<List<ReadingRecord>> readingRecords(Ref ref) =>
    ref.watch(readingRecordRepositoryProvider).getRecent();
