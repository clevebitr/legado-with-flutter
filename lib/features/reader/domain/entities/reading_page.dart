import 'package:freezed_annotation/freezed_annotation.dart';

part 'reading_page.freezed.dart';

/// How an image source lays its pages out (`ruleContent.imageStyle`, ADR-0069 G5).
///
/// Upstream's names are kept so the source text maps one-to-one; what each one does is the
/// reader's business, and only the first two are implemented today.
enum MangaImageStyle {
  /// Full width, one under the next (upstream `FULL`, and this repository's default).
  full,

  /// One image per screen, scaled to fit inside the viewport (upstream `SINGLE`).
  single,

  /// Centered at its own size (upstream's default). Behaves like [full] until the alignment
  /// branch exists — registered in `docs/dev/roadmap.md` §3.7.
  centered,

  /// Aligned left at its own size; behaves like [centered] today.
  left,

  /// Aligned right at its own size; behaves like [centered] today.
  right,
}

/// One image page of a manga chapter, as the **reader** sees it
/// (`docs/dev/roadmap.md` §3.10 M16, ADR-0053 §决策 2).
///
/// [headers] are the source's request headers: an image host often checks the `Referer` the rule
/// chain used, and a gallery that loads through a bare URL would show broken tiles on those sites.
@freezed
abstract class ReadingPage with _$ReadingPage {
  /// Creates one image page.
  const factory ReadingPage({
    /// The absolute image URL.
    required String url,

    /// Headers the image request must carry.
    @Default(<String, String>{}) Map<String, String> headers,

    /// How the source wants its pages laid out.
    @Default(MangaImageStyle.centered) MangaImageStyle style,
  }) = _ReadingPage;
}
