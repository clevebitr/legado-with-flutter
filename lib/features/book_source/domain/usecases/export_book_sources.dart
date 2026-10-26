import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/book_source/domain/repositories/book_source_repository.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'export_book_sources.freezed.dart';

/// One ready-to-save book-source document (`docs/dev/roadmap.md` 5.8, ADR-0071 §决策 3).
@freezed
abstract class BookSourceExport with _$BookSourceExport {
  /// Creates a document.
  const factory BookSourceExport({
    /// The file name to suggest to the save dialog.
    required String fileName,

    /// The JSON text to write.
    required String contents,

    /// How many sources the document holds.
    required int count,
  }) = _BookSourceExport;
}

/// Writes stored book sources as an upstream-compatible document
/// (`docs/dev/roadmap.md` 5.8, ADR-0071 §决策 3).
///
/// The bytes come from the stored payloads, not from the model: that is what keeps the keys this
/// build never modelled (ADR-0021, ADR-0040 §决策 4) — and it is why the only thing this use case
/// does is join them into an array and name the file.
final class ExportBookSources {
  /// Creates the use case.
  const ExportBookSources({required this._repository});

  final BookSourceRepository _repository;

  /// Builds the document for [ids], or for every source when it is `null` or empty.
  Future<ParseResult<BookSourceExport>> execute({Set<int>? ids}) async {
    final List<String> payloads = await _repository.exportPayloads(ids: ids);
    if (payloads.isEmpty) {
      // 一个源都没有时写一个空数组文件是没用的动作：让页面说「没有可导出的源」。
      return failureAt<BookSourceExport>(
        kind: ParseFailureKind.notFound,
        rulePath: 'bookSource.export.empty',
      );
    }

    return ParseSuccess<BookSourceExport>(
      BookSourceExport(
        fileName: 'bookSources-${payloads.length}.json',
        // 每条 payload 已经是 JSON 文本：直接拼成数组，不再解码再编码，键序与未知键一字不动。
        contents: '[\n${payloads.join(',\n')}\n]',
        count: payloads.length,
      ),
    );
  }
}
