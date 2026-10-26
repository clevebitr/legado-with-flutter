// coverage:ignore-file
import 'package:freezed_annotation/freezed_annotation.dart';

part 'shelf_group.freezed.dart';

/// One user-defined shelf group (`docs/dev/roadmap.md` M19, ADR-0066 §决策 2).
///
/// 「全部」 is a filter view and 「未分组」 is `books.groupId == null`, so neither is one of these
/// rows: the list a chip row renders is exactly what the user created.
@freezed
abstract class ShelfGroup with _$ShelfGroup {
  /// Creates a shelf group.
  const factory ShelfGroup({
    required int id,
    required String name,
    @Default(0) int sortOrder,
  }) = _ShelfGroup;
}
