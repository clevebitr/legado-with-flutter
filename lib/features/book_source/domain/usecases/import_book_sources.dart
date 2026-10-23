import 'dart:convert';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/network/http_client.dart';
import 'package:flutter_reader/core/network/http_response.dart';
import 'package:flutter_reader/features/book_source/domain/book_source_fingerprint.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source_import_preview.dart';
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

/// Where the JSON of one import comes from (`docs/dev/roadmap.md` 5.1, ADR-0040 §决策 9).
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

/// Imports book sources from pasted text or a URL (`docs/dev/roadmap.md` 5.1, ADR-0040).
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
  /// It is [preview] followed by [commit] over every usable entry: the two-step form the page
  /// shows, collapsed for callers that do not want to look first (`docs/dev/roadmap.md` §3.10 V5).
  /// File-level failures reuse [ParseFailureKind.invalidBookSource] with a locating `rulePath`
  /// (`import.sizeLimit` / `import.notJson` / `import.noEntries`), because the user consequence of
  /// all of them is the same file being unusable (ADR-0040 §决策 7).
  Future<ParseResult<BookSourceImportReport>> execute(
    BookSourceImportInput input,
  ) async {
    final ParseResult<BookSourceImportPreview> preview = await this.preview(
      input,
    );

    return switch (preview) {
      ParseFailure<BookSourceImportPreview>(
        :final ParseFailureKind kind,
        rulePath: final String failedAt,
      ) =>
        failureAt<BookSourceImportReport>(kind: kind, rulePath: failedAt),
      ParseSuccess<BookSourceImportPreview>(
        :final BookSourceImportPreview data,
      ) =>
        await commit(data),
    };
  }

  /// Reads [input] and answers what could be stored, **without writing anything**
  /// (ADR-0052 §决策 5).
  ///
  /// Rejected entries stay in the preview with their reason, so the page can show the user which
  /// lines of the file were dropped instead of only counting them (C-SRC-4). The byte cap and the
  /// per-entry sanitising are exactly the `execute` ones: splitting the step did not loosen them.
  Future<ParseResult<BookSourceImportPreview>> preview(
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
        failureAt<BookSourceImportPreview>(kind: kind, rulePath: failedAt),
      ParseSuccess<String>(:final String data) => await _previewOf(data),
    };
  }

  /// Stores the entries of [preview] the caller kept, and reports what landed.
  ///
  /// [selected] is the set of `entry.index` values to store, or `null` for every usable entry.
  /// Rejected entries are never stored and are reported as `skipped`; usable entries the user
  /// unticked are simply not imported (they are not invalid, so counting them as skipped would
  /// blame the file for the user's choice).
  Future<ParseResult<BookSourceImportReport>> commit(
    BookSourceImportPreview preview, {
    Set<int>? selected,
  }) async {
    final List<Map<String, Object?>> entries = <Map<String, Object?>>[
      for (final BookSourceImportEntry entry in preview.entries)
        if (entry.isUsable &&
            (selected == null || selected.contains(entry.index)))
          entry.entry,
    ];
    final BookSourceSaveReport saved = await _repository.saveAll(entries);

    return ParseSuccess<BookSourceImportReport>(
      BookSourceImportReport(
        inserted: saved.inserted,
        refreshed: saved.refreshed,
        skipped: preview.rejectedCount,
      ),
    );
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

  /// Decodes [json] and answers one preview entry per element, rejected ones included.
  ///
  /// The identity lookup is what tells "new" from "refresh"; it happens **before** any write, so
  /// the preview is a prediction the store confirms in [commit] (ADR-0052 §决策 5).
  Future<ParseResult<BookSourceImportPreview>> _previewOf(String json) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      return failureAt<BookSourceImportPreview>(
        kind: ParseFailureKind.invalidBookSource,
        rulePath: 'import.notJson',
      );
    }

    // 单条导出与批量导出的顶层形状不同：一个对象也是一个合法的导入文件。
    final List<Object?> entries = decoded is List<Object?>
        ? decoded
        : <Object?>[decoded];
    if (entries.isEmpty) {
      return failureAt<BookSourceImportPreview>(
        kind: ParseFailureKind.invalidBookSource,
        rulePath: 'import.noEntries',
      );
    }

    final List<BookSourceImportEntry> previews = <BookSourceImportEntry>[];
    for (var index = 0; index < entries.length; index++) {
      final Object? entry = entries[index];
      if (entry is! Map<String, Object?>) {
        _logSkipped(index: index, entry: null, field: 'entry');
        previews.add(_rejected(index, BookSourceImportRejection.notAnObject));

        continue;
      }
      final String? missing = _missingRequiredField(entry);
      if (missing != null) {
        _logSkipped(index: index, entry: entry, field: missing);
        previews.add(
          _rejected(
            index,
            missing == 'bookSourceUrl'
                ? BookSourceImportRejection.missingUrl
                : BookSourceImportRejection.missingName,
          ),
        );

        continue;
      }
      // 其余字段由模型裁决（checked 模式点名出错的 JSON 键，ADR-0022）；这里只决定拿这份裁决
      // 怎么办：可降级的字段去掉后照常导入，别的（结构缺失）拒绝该条。
      final Map<String, Object?>? usable = _sanitise(entry, index: index);
      if (usable == null) {
        previews.add(_rejected(index, BookSourceImportRejection.unreadable));

        continue;
      }
      final String url = _textOf(usable['bookSourceUrl']);
      final bool exists = await _repository.exists(
        url: url,
        fingerprint: bookSourceFingerprint(usable),
      );
      final ({String? name, String? url, String? group}) fields =
          previewFieldsOf(usable);
      previews.add(
        BookSourceImportEntry(
          index: index,
          entry: usable,
          isRefresh: exists,
          rejection: null,
          name: fields.name,
          url: fields.url,
          group: fields.group,
        ),
      );
    }

    return ParseSuccess<BookSourceImportPreview>(
      BookSourceImportPreview(entries: previews),
    );
  }

  /// One entry the preview shows as rejected.
  BookSourceImportEntry _rejected(
    int index,
    BookSourceImportRejection reason,
  ) => BookSourceImportEntry(
    index: index,
    entry: const <String, Object?>{},
    isRefresh: false,
    rejection: reason,
  );

  /// A non-empty [String] field, or `''` when the raw value is missing or of another type.
  String _textOf(Object? value) => value is String ? value : '';

  /// The **required** field [entry] misses, or `null` when both are there.
  ///
  /// ADR-0040 §决策 6 names exactly these two, and a blank string counts as missing the same way the
  /// model treats a missing key.
  String? _missingRequiredField(Map<String, Object?> entry) {
    final Object? url = entry['bookSourceUrl'];
    if (url is! String || url.trim().isEmpty) {
      return 'bookSourceUrl';
    }
    final Object? name = entry['bookSourceName'];
    if (name is! String || name.trim().isEmpty) {
      return 'bookSourceName';
    }

    return null;
  }

  /// Returns [entry] with its unreadable **optional** fields removed, or `null` when it cannot be
  /// imported at all.
  ///
  /// This is where ADR-0026's spirit reaches the import path: one bad optional field must not cost
  /// the whole source. The model is the judge — checked mode names the offending JSON key
  /// (ADR-0022) — and this method decides what to do with that verdict:
  ///
  /// * a [_degradableFields] key is dropped **with a warning**, so the source keeps working with the
  ///   model's default for it (no UA header, type `text`) instead of disappearing;
  /// * anything else (a missing rule object, an unknown structural problem) skips the entry, which
  ///   the caller counts and reports.
  ///
  /// The loop is bounded by the number of degradable keys: every iteration removes one.
  Map<String, Object?>? _sanitise(
    Map<String, Object?> entry, {
    required int index,
  }) {
    Map<String, Object?> candidate = entry;

    while (true) {
      try {
        BookSource.fromLegadoJson(candidate);

        return candidate;
      } on CheckedFromJsonException catch (error) {
        final String? key = error.key;
        if (key == null ||
            !_degradableFields.contains(key) ||
            !candidate.containsKey(key)) {
          _logSkipped(
            index: index,
            entry: entry,
            field: key ?? 'ruleSearch/ruleToc/ruleContent',
          );

          return null;
        }
        _logDegraded(index: index, entry: entry, field: key);
        candidate = Map<String, Object?>.of(candidate)..remove(key);
      }
    }
  }

  /// The single-entry fields an import may drop so the rest of the entry still arrives.
  ///
  /// **Only `header`.** A real 504-source export wrote 27 headers in forms this build cannot read —
  /// a rule (`@js:` / `<js>`) or malformed/lenient JSON — and losing a source over its user agent is
  /// a worse outcome than importing it without one, so the field is dropped with a warning and the
  /// requests simply carry the policy default (ADR-0040 §决策 6's revision note). The raw value
  /// stays in the stored payload, so nothing is lost from the file itself.
  ///
  /// Deliberately **not** here: `bookSourceType`. An unknown type must keep failing the entry
  /// instead of silently becoming `text`, because that would present an audio or image source as a
  /// text one (ADR-0022 §决策 5); the enum models every value the fork documents (0-4), and this
  /// build has no fifth meaning to guess.
  static const List<String> _degradableFields = <String>['header'];

  /// Logs one entry that imports **without** a field, naming which one.
  ///
  /// Degrading silently is what C-SRC-4 forbids; this line is what makes the loss visible and
  /// located (index + field + URL), while still not logging the entry's body (C-ERR-8).
  void _logDegraded({
    required int index,
    required Map<String, Object?>? entry,
    required String field,
  }) {
    _logger.warning(
      'Importing book source with a degraded field: index=$index field=$field '
      'url=${_label(entry?['bookSourceUrl'])} '
      'name=${_label(entry?['bookSourceName'])}',
    );
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
