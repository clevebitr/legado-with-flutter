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

/// The largest file one import accepts, in UTF-8 bytes.
///
/// `ImportBookSources` overrides it only so a test can exercise the cap cheaply.
const int bookSourceImportSizeLimitBytes = 32 * 1024 * 1024;

/// Where the JSON of one import comes from.
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

/// What one import did.
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

    /// How many entries were rejected and left out.
    required int skipped,
  }) = _BookSourceImportReport;

  /// The count reported as “imported”; refreshed entries count too.
  int get imported => inserted + refreshed;
}

/// Imports book sources from pasted text or a URL.
///
/// Owns the acceptance decisions (byte cap, file-level rejections, per-entry skips); storing is
/// delegated to [BookSourceRepository], which owns identity.
final class ImportBookSources {
  /// Creates the use case.
  ///
  /// [_sizeLimit] defaults to the production cap and is overridden only in tests.
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
  /// Equivalent to [preview] followed by [commit] over every usable entry.
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

  /// Reads [input] and answers what could be stored, without writing anything.
  ///
  /// Rejected entries stay in the preview with their reason so the page can show them.
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

  /// Stores the usable entries of [preview] and reports what landed.
  ///
  /// [selected] holds the entry indexes to store, or `null` for every usable entry.
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

  // 解析之前先卡字节上限。
  ParseResult<String> _fromText(String text) =>
      text.length > _sizeLimit || utf8.encode(text).length > _sizeLimit
      ? failureAt<String>(
          kind: ParseFailureKind.invalidBookSource,
          rulePath: 'import.sizeLimit',
        )
      : ParseSuccess<String>(text);

  Future<ParseResult<String>> _fromUrl(String url) async {
    final ParseResult<HttpResponse> response = await _http.get(
      url,
      rulePath: 'import.url',
      maxBytes: _sizeLimit,
    );

    return switch (response) {
      // 上限触发时请求层把异常放进 `cause`，这里改写成导入契约的 rulePath。
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

    // 单条导出与批量导出的顶层形状不同：一个对象也是合法的导入文件。
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
      // 其余字段由模型裁决：可降级的字段去掉后照常导入，结构缺失则拒绝该条。
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

  String _textOf(Object? value) => value is String ? value : '';

  // 只有 URL 与名称是必需字段；空白字符串同样视为缺失。
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

  // 可降级的字段去掉后照常导入；其他结构问题返回 null，由调用方记为跳过。
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

  // 只有 `header` 可以丢弃后继续导入；未知的 `bookSourceType` 必须让该条失败。
  static const List<String> _degradableFields = <String>['header'];

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

  // 记录被跳过的条目：只写 index / 字段 / URL / 名称，不写条目内容。
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

  String _label(Object? value) =>
      value is String && value.trim().isNotEmpty ? value : '<missing>';
}
