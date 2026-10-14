import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/di/platform_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/book_source/di.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/import_book_sources.dart';
import 'package:flutter_reader/features/book_source/presentation/notifiers/book_source_list_notifier.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'book_source_import_notifier.freezed.dart';
part 'book_source_import_notifier.g.dart';

/// What the import form currently shows (`PLAN.md` 5.1).
///
/// A state machine instead of an `AsyncValue`: "nothing submitted yet" and "submitted, nothing
/// usable inside" are both non-errors the form has to tell apart, and the report of a successful
/// import is not an error object to unwrap either.
@freezed
sealed class BookSourceImportState with _$BookSourceImportState {
  /// Nothing was submitted yet in this screen.
  const factory BookSourceImportState.idle() = BookSourceImportIdle;

  /// A submission is in flight.
  const factory BookSourceImportState.importing() = BookSourceImporting;

  /// The import finished; [report] carries inserted / refreshed / skipped.
  const factory BookSourceImportState.done(BookSourceImportReport report) =
      BookSourceImportDone;

  /// The whole file was refused; [kind] is the message the UI shows (C-ERR-7).
  const factory BookSourceImportState.failed(ParseFailureKind kind) =
      BookSourceImportFailed;
}

/// Runs one book source import from the form.
@riverpod
class BookSourceImportNotifier extends _$BookSourceImportNotifier {
  @override
  BookSourceImportState build() => const BookSourceImportState.idle();

  /// Asks the platform for a file and imports it.
  ///
  /// A cancelled dialog (or a platform without one) changes **nothing**: `ParseSuccess(null)` is not
  /// an outcome the reader has to explain, so the form simply stays as it was. An oversized file is
  /// [ParseFailureKind.invalidBookSource] with `rulePath: import.sizeLimit` — the same verdict the
  /// paste path gives — and the picked text then goes through the ordinary import path, so the cap
  /// and the entry-level rules are one implementation.
  Future<void> pickFile() async {
    final ParseResult<String?> picked = await ref
        .read(bookSourceFilePickerProvider)
        .pick(maxBytes: bookSourceImportSizeLimitBytes);

    switch (picked) {
      case ParseFailure<String?>(:final ParseFailureKind kind):
        state = BookSourceImportState.failed(kind);
      case ParseSuccess<String?>(:final String? data):
        if (data == null) {
          return;
        }
        await submit(BookSourceImportText(data));
    }
  }

  /// Imports [input] and publishes the outcome.
  ///
  /// The use case answers with a `ParseResult` (C-ERR-1), so the two file-level outcomes are
  /// values. A collaborator that breaks that contract with an [Exception] is degraded to
  /// [ParseFailureKind.parseFailed] with a log line — the storage layer is the only thing that can
  /// throw here, and a stuck form is worse than a message. An [Error] is deliberately not caught
  /// (C-ERR-2).
  Future<void> submit(BookSourceImportInput input) async {
    state = const BookSourceImportState.importing();

    try {
      final ParseResult<BookSourceImportReport> result = await ref
          .read(importBookSourcesProvider)
          .execute(input);

      switch (result) {
        case ParseSuccess<BookSourceImportReport>(
          :final BookSourceImportReport data,
        ):
          state = BookSourceImportState.done(data);
          // 导入可能新增行、也可能只刷新既有行；两种情况都让列表与「当前源」按新库重算。
          ref.invalidate(bookSourceListProvider);
        case ParseFailure<BookSourceImportReport>(:final ParseFailureKind kind):
          state = BookSourceImportState.failed(kind);
      }
    } on Exception catch (error, stackTrace) {
      ref
          .read(appLoggerProvider)
          .error('Book source import failed', error, stackTrace);

      state = const BookSourceImportState.failed(ParseFailureKind.parseFailed);
    }
  }
}
