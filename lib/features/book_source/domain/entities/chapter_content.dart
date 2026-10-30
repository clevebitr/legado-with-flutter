/// One chapter body as the content stage produced it (`ruleContent`, ADR-0078 S2).
///
/// The reader only needs [body], which is why the reader port still answers a plain string — but
/// three more values belong to the same read, and dropping them would mean re-reading the page:
///
/// * [title] / [reviewImg] — `ruleContent.title` renames the chapter from the **content page**
///   (some sites only carry the real name there) and may carry a review image
///   (upstream `BookContent.kt:165-190`);
/// * [lyric] — an audio source's `subContent` (upstream stores it as the chapter's `lyric`
///   variable, `BookContent.kt:144-163`).
///
/// For a text source `subContent` is already **appended to [body]** (upstream `appendContent`), so
/// [body] is always the finished text: paged, sub-content included, `replaceRegex` applied.
final class ChapterContent {
  /// Creates the result of one chapter read.
  const ChapterContent({
    required this.body,
    this.title,
    this.reviewImg,
    this.lyric,
  });

  /// The finished body: every page joined, sub-content appended, replacement applied.
  final String body;

  /// The chapter name the content page carried, or `null` when the rule matched nothing.
  final String? title;

  /// The review image the [title] rule carried, or `null`.
  final String? reviewImg;

  /// An audio source's `subContent` (lyrics), or `null` for a text source or an empty rule.
  final String? lyric;
}
