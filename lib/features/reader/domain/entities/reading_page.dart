import 'package:freezed_annotation/freezed_annotation.dart';

part 'reading_page.freezed.dart';

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
  }) = _ReadingPage;
}
