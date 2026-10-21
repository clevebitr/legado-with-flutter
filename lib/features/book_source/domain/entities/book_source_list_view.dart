import 'package:flutter_reader/features/book_source/domain/entities/book_source_sort_order.dart';

/// How the book-source list is currently shown (`docs/dev/roadmap.md` 5.5, ADR-0045 §决策 4).
///
/// Two independent choices — the sort key and the group filter — that belong together because both
/// answer "which sources do I see, in what order". They are **view state**, not app settings: the
/// settings page owns the app-wide switches, this one belongs to the list (ADR-0045 §决策 4).
final class BookSourceListView {
  /// Creates a view state.
  const BookSourceListView({
    this.order = BookSourceSortOrder.defaultOrder,
    this.group,
  });

  /// What a list that has stored nothing yet shows: the manual order, every group.
  static const BookSourceListView defaults = BookSourceListView();

  /// The sort key the user picked.
  final BookSourceSortOrder order;

  /// The group the list is filtered to, or `null` for «all groups».
  ///
  /// It is the raw token from `bookSourceGroup`, not an id: groups are free text the user and the
  /// batch check write, and the list re-validates the token against the rows it loaded
  /// (ADR-0045 §决策 4).
  final String? group;

  /// Returns a copy with the given values; [clearGroup] distinguishes "keep" from "all groups".
  BookSourceListView copyWith({
    BookSourceSortOrder? order,
    String? group,
    bool clearGroup = false,
  }) => BookSourceListView(
    order: order ?? this.order,
    group: clearGroup ? null : (group ?? this.group),
  );

  @override
  bool operator ==(Object other) =>
      other is BookSourceListView &&
      other.order == order &&
      other.group == group;

  @override
  int get hashCode => Object.hash(order, group);

  @override
  String toString() => 'BookSourceListView(order: $order, group: $group)';
}
