// coverage:ignore-file
import 'package:flutter_reader/features/bookshelf/domain/entities/shelf_status.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'shelved_book.freezed.dart';

/// One book on the shelf (`docs/dev/roadmap.md` 5.4).
///
/// The page-derived fields (`name` … `lastChapter`) are a **snapshot** taken when the book was
/// added: the shelf must render without touching the network, and a source that disappeared
/// cannot blank the user's shelf. Refreshing them is the job of the re-add path, which is the
/// same call ("加入书架" on a book that is already there refreshes it).
///
/// 本文件只含重定向工厂声明（方法体由生成器内联），属 ADR-0019 §2 的「无可测量行」子情形，
/// 已登记在 `tool/coverage_allowlist.txt`；行为由 `test/core/storage/bookshelf_dao_test.dart`
/// 与 `test/features/bookshelf/data/bookshelf_repository_impl_test.dart` 构造并读取保证。
@freezed
abstract class ShelvedBook with _$ShelvedBook {
  /// Creates a shelf entry.
  const factory ShelvedBook({
    required int id,
    required String sourceUrl,
    required String bookUrl,

    /// The table-of-contents URL the detail page resolved; `null` for rows stored before 5.3.
    String? tocUrl,

    /// The title shown on the shelf.
    required String name,
    String? author,
    String? kind,
    String? coverUrl,
    String? intro,
    String? lastChapter,
    @Default(ShelfStatus.tracking) ShelfStatus status,
    @Default(false) bool isPinned,

    /// The shelf group this entry belongs to, or `null` for 「未分组」 (ADR-0066 §决策 2).
    int? groupId,

    /// Absolute path of the cover the user picked, or `null` to use [coverUrl].
    String? customCoverPath,

    /// The introduction the user wrote, which wins over [intro] when set (M33, ADR-0092).
    String? customIntro,
    required DateTime addedAt,
    ReadingProgressPosition? progress,
  }) = _ShelvedBook;
}

/// Where the reader stopped in one book (ADR-0041 §决策 4).
///
/// The shelf owns this type because it owns the table; the reader writes it through its own
/// port and never sees this class (C-ARCH-2).
@freezed
abstract class ReadingProgressPosition with _$ReadingProgressPosition {
  /// Creates a reading position.
  const factory ReadingProgressPosition({
    required String chapterUrl,
    String? chapterName,
    @Default(0) int charOffset,
    required DateTime updatedAt,
  }) = _ReadingProgressPosition;
}
