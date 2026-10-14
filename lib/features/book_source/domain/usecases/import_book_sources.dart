import 'dart:convert';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/network/http_client.dart';
import 'package:flutter_reader/core/network/http_response.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/stored_book_source.dart';
import 'package:flutter_reader/features/book_source/domain/repositories/book_source_repository.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'import_book_sources.freezed.dart';

/// The largest file one import accepts, in UTF-8 bytes (ADR-0040 §决策 5).
///
/// The size is derived there rather than guessed: the largest known collection is 20.9 MB, so
/// 32 MiB fits one of the same order while keeping a single `jsonDecode`'s peak memory bounded on
/// a phone. The number is defined **once**, here; `ImportBookSources` takes an override only so a
/// test can exercise the cap without allocating it (production never passes one).
const int bookSourceImportSizeLimitBytes = 32 * 1024 * 1024;

/// Where the JSON of one import comes from (`PLAN.md` 5.1, ADR-0040 §决策 9).
///
/// The two shapes are the ones 5.1 supports without a native dependency; a picked file joins them
/// in 5.8 together with export.
sealed class BookSourceImportInput {
  /// Const constructor for the sealed hierarchy.
  const BookSourceImportInput();
}

/// A JSON document the user pasted.
final class BookSourceImportText extends BookSourceImportInput {
  /// Creates the text input.
  const BookSourceImportText(this.text);

  /// The pasted document.
  final String text;
}

/// A URL the JSON document is downloaded from.
final class BookSourceImportUrl extends BookSourceImportInput {
  /// Creates the URL input.
  const BookSourceImportUrl(this.url);

  /// The download address.
  final String url;
}

/// What one import did (ADR-0040 §决策 6/8).
///
/// `copyWith` is off: a report is a result value nobody derives a variant of (`ParseResult` turns
/// it off for the same reason).
@Freezed(copyWith: false)
abstract class BookSourceImportReport with _$BookSourceImportReport {
  /// Const constructor so the computed count can live next to the fields.
  const BookSourceImportReport._();

  /// Creates an import report.
  const factory BookSourceImportReport({
    /// How many entries were new identities.
    required int inserted,

    /// How many entries matched a stored row and only refreshed its payload.
    required int refreshed,

    /// How many entries were rejected and left out (`ADR-0040` §决策 6).
    required int skipped,
  }) = _BookSourceImportReport;

  /// The count the summary reports as “imported” (ADR-0040 §决策 8's `{count}`).
  ///
  /// A refreshed re-import counts: for the user the import did happen, it just did not add a row.
  int get imported => inserted + refreshed;
}

/// Imports book sources from pasted text or a URL (`PLAN.md` 5.1, ADR-0040).
///
/// The use case owns the **acceptance** decision: the byte cap (before any parsing), the
/// file-level rejections and which single entries are skipped. Storing is delegated to
/// [BookSourceRepository], which owns the identity decision — so “what a valid file is” and
/// “what the same source is” stay in one place each.
final class ImportBookSources {
  /// Creates the use case.
  ///
  /// `sizeLimit` defaults to ADR-0040's number and exists for tests: exercising the cap with the
  /// real value would mean allocating 32 MiB inside a unit test.
  const ImportBookSources({
    required this._repository,
    required this._http,
    required this._logger,
    this._sizeLimit = bookSourceImportSizeLimitBytes,
  });

  final BookSourceRepository _repository;
  final HttpClient _http;
  final AppLogger _logger;
  final int _sizeLimit;

  /// Imports [input] and reports what was stored and what was skipped.
  ///
  /// Failures are file-level and reuse [ParseFailureKind.invalidBookSource] with a locating
  /// `rulePath` (`import.sizeLimit` / `import.notJson` / `import.noEntries`), because the user
  /// consequence of all of them is the same file being unusable (ADR-0040 §决策 7). Single
  /// entries that fail are **skipped and counted**, never silently dropped (C-SRC-4).
  Future<ParseResult<BookSourceImportReport>> execute(
    BookSourceImportInput input,
  ) async {
    final ParseResult<String> json = switch (input) {
      BookSourceImportText(:final String text) => _fromText(text),
      BookSourceImportUrl(:final String url) => await _fromUrl(url),
    };

    return switch (json) {
      ParseFailure<String>(
        :final ParseFailureKind kind,
        rulePath: final String failedAt,
      ) =>
        failureAt<BookSourceImportReport>(kind: kind, rulePath: failedAt),
      ParseSuccess<String>(:final String data) => await _store(data),
    };
  }

  /// Checks the pasted document against the byte cap **before** anything parses it.
  ParseResult<String> _fromText(String text) =>
      text.length > _sizeLimit || utf8.encode(text).length > _sizeLimit
      ? failureAt<String>(
          kind: ParseFailureKind.invalidBookSource,
          rulePath: 'import.sizeLimit',
        )
      : ParseSuccess<String>(text);

  /// Downloads [url] with the cap applied to the **download** (C-PERF-5).
  Future<ParseResult<String>> _fromUrl(String url) async {
    final ParseResult<HttpResponse> response = await _http.get(
      url,
      rulePath: 'import.url',
      maxBytes: _sizeLimit,
    );

    return switch (response) {
      // 请求层只知道自己被限流，不知道调用方要这些字节做什么；上限触发时它把上限对象放进
      // `cause`，由这里改写成导入契约的 rulePath（ADR-0040 §决策 5）。
      ParseFailure<HttpResponse>(cause: final BodyTooLargeException _) =>
        failureAt<String>(
          kind: ParseFailureKind.invalidBookSource,
          rulePath: 'import.sizeLimit',
        ),
      ParseFailure<HttpResponse>(
        :final ParseFailureKind kind,
        rulePath: final String failedAt,
      ) =>
        failureAt<String>(kind: kind, rulePath: failedAt),
      ParseSuccess<HttpResponse>(:final HttpResponse data) =>
        ParseSuccess<String>(data.body),
    };
  }

  /// Decodes [json], keeps the usable entries and stores them.
  Future<ParseResult<BookSourceImportReport>> _store(String json) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      return failureAt<BookSourceImportReport>(
        kind: ParseFailureKind.invalidBookSource,
        rulePath: 'import.notJson',
      );
    }

    // 单条导出与批量导出的顶层形状不同：一个对象也是一个合法的导入文件。
    final List<Object?> entries = decoded is List<Object?>
        ? decoded
        : <Object?>[decoded];
    if (entries.isEmpty) {
      return failureAt<BookSourceImportReport>(
        kind: ParseFailureKind.invalidBookSource,
        rulePath: 'import.noEntries',
      );
    }

    final List<Map<String, Object?>> accepted = <Map<String, Object?>>[];
    var skipped = 0;
    for (var index = 0; index < entries.length; index++) {
      final Object? entry = entries[index];
      if (entry is! Map<String, Object?>) {
        skipped++;
        _logSkipped(index: index, entry: null, field: 'entry');

        continue;
      }
      final String? invalidField = _invalidField(entry);
      if (invalidField != null) {
        skipped++;
        _logSkipped(index: index, entry: entry, field: invalidField);

        continue;
      }
      accepted.add(entry);
    }

    final BookSourceSaveReport saved = await _repository.saveAll(accepted);

    return ParseSuccess<BookSourceImportReport>(
      BookSourceImportReport(
        inserted: saved.inserted,
        refreshed: saved.refreshed,
        skipped: skipped,
      ),
    );
  }

  /// The field that makes [entry] unusable, or `null` when it can be stored.
  ///
  /// The required fields are checked here because ADR-0040 §决策 6 names them; everything else is
  /// the model's call, and checked mode (ADR-0022) turns a malformed entry into a nameable
  /// exception rather than an `Error`.
  String? _invalidField(Map<String, Object?> entry) {
    final Object? url = entry['bookSourceUrl'];
    if (url is! String || url.trim().isEmpty) {
      return 'bookSourceUrl';
    }
    final Object? name = entry['bookSourceName'];
    if (name is! String || name.trim().isEmpty) {
      return 'bookSourceName';
    }

    try {
      BookSource.fromLegadoJson(entry);
    } on CheckedFromJsonException catch (error) {
      return error.key ?? 'ruleSearch/ruleToc/ruleContent';
    }

    return null;
  }

  /// Logs one skipped entry so it can be found again without logging its body (C-ERR-8).
  ///
  /// The id, the URL and the failing field are what an author needs to fix a file; the entry's
  /// JSON is not, and must not end up in a log (C-SEC-4). An entry that is not even an object has
  /// no URL to name, which is exactly why the index is part of the message.
  void _logSkipped({
    required int index,
    required Map<String, Object?>? entry,
    required String field,
  }) {
    _logger.warning(
      'Skipping imported book source: index=$index field=$field '
      'url=${_label(entry?['bookSourceUrl'])} '
      'name=${_label(entry?['bookSourceName'])}',
    );
  }

  /// A log-safe rendering of an entry's identifying fields.
  String _label(Object? value) =>
      value is String && value.trim().isNotEmpty ? value : '<missing>';
}
