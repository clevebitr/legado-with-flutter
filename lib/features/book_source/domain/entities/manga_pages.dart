import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';

/// One chapter's images, as `ruleContent` produced them (`docs/dev/roadmap.md` §3.10 M16).
///
/// The addresses are **absolute** and de-duplicated in rule order; [headers] is the source's own
/// request-header table (static or `header`-rule result), carried along because an image host often
/// checks the `Referer` the rule chain used (ADR-0053 §决策 2).
///
/// It is a value object, not a `freezed` class: nothing derives a variant of it and the reader
/// adapter copies the two fields across the feature boundary once (C-ARCH-5 allows final fields).
final class MangaPages {
  /// Creates one chapter's image list.
  const MangaPages({
    required this.urls,
    required this.headers,
    this.imageStyle,
  });

  /// The image URLs, in reading order.
  final List<String> urls;

  /// Headers every image request must carry, or `null` when the source declares none.
  final Map<String, String>? headers;

  /// The source's `ruleContent.imageStyle` verbatim (`full` / `single` / `left` / `right`),
  /// or `null` when it declares none (`docs/dev/book-source.md` §2, ADR-0069 G5).
  ///
  /// Reading the value is a presentation decision, so it stays a string here and the reader
  /// adapter turns it into its own enum.
  final String? imageStyle;
}

/// The failure rule path for the image list, used by every failure this use case reports.
const String mangaPagesRulePath = 'contentRule.content';

/// Whether [source] is an image source, i.e. the reader must show pages instead of text.
///
/// Kept next to [MangaPages] because two places ask the same question: the reader dispatch (via
/// its port) and the check page's type filter.
bool isMangaSource(BookSource source) =>
    source.sourceType == BookSourceType.image;
