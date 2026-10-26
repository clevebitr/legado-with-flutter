import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/di/platform_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/book_source/di.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source_import_preview.dart';
import 'package:flutter_reader/features/book_source/domain/usecases/import_book_sources.dart';
import 'package:flutter_reader/features/book_source/presentation/notifiers/book_source_list_notifier.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'book_source_import_notifier.freezed.dart';
part 'book_source_import_notifier.g.dart';

/// What the import form currently shows.
@freezed
sealed class BookSourceImportState with _$BookSourceImportState {
  /// Nothing was submitted yet in this screen.
  const factory BookSourceImportState.idle() = BookSourceImportIdle;

  /// A submission is in flight (the file is being read and checked).
  const factory BookSourceImportState.importing() = BookSourceImporting;

  /// The file was read; nothing is stored until the user commits.
  const factory BookSourceImportState.preview(BookSourceImportPreview preview) =
      BookSourceImportPreviewing;

  /// The ticked entries are being stored.
  const factory BookSourceImportState.committing() = BookSourceImportCommitting;

  /// The import finished; [report] carries inserted / refreshed / skipped.
  const factory BookSourceImportState.done(BookSourceImportReport report) =
      BookSourceImportDone;

  /// The whole file was refused; [kind] is the message the UI shows.
  const factory BookSourceImportState.failed(ParseFailureKind kind) =
      BookSourceImportFailed;
}

/// Runs one book source import from the form.
@riverpod
class BookSourceImportNotifier extends _$BookSourceImportNotifier {
  @override
  BookSourceImportState build() => const BookSourceImportState.idle();

  /// Asks the platform for a file and imports it; a cancelled dialog changes nothing.
  Future<void> pickFile() async {
    final ParseResult<String?> picked = await ref
        .read(jsonFilePickerProvider)
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

  /// Reads [input] and publishes the preview; nothing is stored yet.
  Future<void> submit(BookSourceImportInput input) async {
    state = const BookSourceImportState.importing();

    try {
      final ParseResult<BookSourceImportPreview> result = await ref
          .read(importBookSourcesProvider)
          .preview(input);

      state = switch (result) {
        ParseSuccess<BookSourceImportPreview>(
          :final BookSourceImportPreview data,
        ) =>
          BookSourceImportState.preview(data),
        ParseFailure<BookSourceImportPreview>(:final ParseFailureKind kind) =>
          BookSourceImportState.failed(kind),
      };
    } on Exception catch (error, stackTrace) {
      ref
          .read(appLoggerProvider)
          .error('Book source import failed', error, stackTrace);

      state = const BookSourceImportState.failed(ParseFailureKind.parseFailed);
    }
  }

  /// Stores the previewed entries whose `entry.index` is in [selected].
  Future<void> commit(Set<int> selected) async {
    final BookSourceImportState current = state;
    if (current is! BookSourceImportPreviewing) {
      return;
    }
    final BookSourceImportPreview preview = current.preview;
    state = const BookSourceImportState.committing();

    try {
      final ParseResult<BookSourceImportReport> result = await ref
          .read(importBookSourcesProvider)
          .commit(preview, selected: selected);

      switch (result) {
        case ParseSuccess<BookSourceImportReport>(
          :final BookSourceImportReport data,
        ):
          state = BookSourceImportState.done(data);
          // 导入可能新增行、也可能只刷新既有行；列表页读的是按排序/筛选投影后的
          // `bookSourceListDataProvider`，只失效源列表会让它继续显示导入前的行。
          ref.invalidate(bookSourceListProvider);
          ref.invalidate(bookSourceListDataProvider);
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

  /// Drops the preview and returns to the form, e.g. to paste a different file.
  void restart() => state = const BookSourceImportState.idle();
}
