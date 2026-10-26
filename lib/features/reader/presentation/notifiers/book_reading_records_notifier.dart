import 'package:flutter_reader/features/reader/di.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_record.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'book_reading_records_notifier.g.dart';

/// The recent reading sessions of one book (`docs/dev/roadmap.md` M19).
///
/// The book identity is passed as a small record of primitives instead of `ReaderBook`: the detail
/// page's entry point only knows `(sourceUrl, bookUrl)`, and the port that carries it is primitive
/// by construction (ADR-0042). The title is not needed here — the page's app bar gets it from the
/// route.
@riverpod
Future<List<ReadingRecord>> bookReadingRecords(
  Ref ref,
  ({String sourceUrl, String bookUrl}) book,
) => ref
    .watch(readingRecordRepositoryProvider)
    .getForBook(sourceUrl: book.sourceUrl, bookUrl: book.bookUrl);
