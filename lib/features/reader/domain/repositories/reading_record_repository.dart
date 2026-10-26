// coverage:ignore-file
import 'package:flutter_reader/features/reader/domain/entities/reading_record.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_session.dart';

/// How many recent sessions a list page asks for (ADR-0066 §决策 4).
///
/// The pages show "what I read lately", not an archive: two hundred rows is several weeks of
/// reading for a heavy reader and still one bounded query (C-PERF-6).
const int readingRecordPageLimit = 200;

/// Persistence for the reading records (`docs/dev/roadmap.md` M19, ADR-0066 §决策 4).
///
/// The port is total like `BookmarkRepository`: every read answers with data, and [record] is a
/// no-op for a session below `minimumRecordedSeconds` (see `ReadingSession.shouldRecord`) rather
/// than an error — the caller (the reader, on dispose) has nothing to show and nothing to retry.
///
/// 本文件只有抽象方法签名（无可测量行），已按 ADR-0019 §2 登记在 `tool/coverage_allowlist.txt`；
/// 契约由 `ReadingRecordRepositoryImpl` 与其测试行使。
abstract interface class ReadingRecordRepository {
  /// Appends [session] when it is long enough to be worth a row.
  Future<void> record(ReadingSession session);

  /// The most recent sessions across every book, newest first.
  Future<List<ReadingRecord>> getRecent({int limit = readingRecordPageLimit});

  /// The most recent sessions of one book, newest first.
  Future<List<ReadingRecord>> getForBook({
    required String sourceUrl,
    required String bookUrl,
    int limit = readingRecordPageLimit,
  });
}
