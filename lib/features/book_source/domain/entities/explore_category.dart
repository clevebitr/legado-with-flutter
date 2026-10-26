// coverage:ignore-file
import 'package:freezed_annotation/freezed_annotation.dart';

part 'explore_category.freezed.dart';

/// One entry of a source's discover page (`exploreUrl`, `docs/dev/book-source.md` §4.2).
///
/// The pair is what upstream's `ExploreKind` carries for a **URL** category: the label the
/// discover page shows and the page it opens. M1 models nothing else on purpose — the form
/// categories (`type` `text` / `button` / `toggle` / `select`) and their parameters are rejected
/// where they are parsed (ADR-0035 §决策 4/6), so a category that exists here is always a URL
/// category.
///
/// [url] is the **raw** template the source wrote: it is rendered through the shared URL path
/// when the category is opened (`{{page}}` / `{{baseUrl}}`, ADR-0035 §决策 5), not here.
///
/// A `null` url is a **section header**, not a broken entry: real `exploreUrl` scripts emit labels
/// such as `══ 推荐 ══` with an empty url to group the chips under it (ADR-0069). Upstream keeps
/// them as `ExploreKind(title, "")`; the page shows them as a non-clickable label.
@freezed
abstract class ExploreCategory with _$ExploreCategory {
  /// Creates a discover-page category.
  const factory ExploreCategory({required String title, String? url}) =
      _ExploreCategory;
}
