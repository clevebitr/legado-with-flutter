/// The group tokens the batch check writes into a source's `bookSourceGroup`
/// (`docs/dev/roadmap.md` §5.10, ADR-0043 §决策 1).
///
/// These strings are **data written into the book source**, not UI copy: a group is a user-visible
/// tag the user may also assign by hand, and the values are upstream's own tokens
/// (`BookSourceCheckRepository.kt:196-247`). They therefore live here instead of in ARB — ARB is
/// for interface text (C-UI-5), and a localised group would stop matching what upstream and other
/// clients write.
library;

/// The search stage produced no book.
const String searchInvalidGroup = '搜索失效';

/// The explore stage produced no book.
const String exploreInvalidGroup = '发现失效';

/// The book found by the search stage has no readable table of contents.
const String searchTocInvalidGroup = '搜索目录失效';

/// The book found by the search stage has no readable body.
const String searchContentInvalidGroup = '搜索正文失效';

/// The book found by the explore stage has no readable table of contents.
const String exploreTocInvalidGroup = '发现目录失效';

/// The book found by the explore stage has no readable body.
const String exploreContentInvalidGroup = '发现正文失效';

/// The source declares no `searchUrl`, so the search stage cannot run.
const String searchUrlMissingGroup = '搜索链接规则为空';

/// The source declares no usable explore entry, so the explore stage cannot run.
const String exploreRuleMissingGroup = '发现规则为空';

/// The source did not finish within the per-source timeout.
const String checkTimeoutGroup = '校验超时';

/// A `@js:` rule failed, so the source depends on a script that no longer works.
const String jsInvalidGroup = 'js失效';

/// The site itself failed (network, encoding, or a rule that no longer fits the page).
const String siteInvalidGroup = '网站失效';

/// Every group token the check owns, i.e. the ones a re-check clears first.
///
/// The three failure buckets ([checkTimeoutGroup], [jsInvalidGroup], [siteInvalidGroup]) are kept
/// apart because they tell the user what to fix: a timeout is retried, a JS invalid source needs
/// its script fixed, and a site invalid source is broken on the site's side.
const Set<String> checkOwnedGroups = <String>{
  searchInvalidGroup,
  exploreInvalidGroup,
  searchTocInvalidGroup,
  searchContentInvalidGroup,
  exploreTocInvalidGroup,
  exploreContentInvalidGroup,
  searchUrlMissingGroup,
  exploreRuleMissingGroup,
  checkTimeoutGroup,
  jsInvalidGroup,
  siteInvalidGroup,
};

/// Splits one `bookSourceGroup` value into its group names.
///
/// The separator set is upstream's (`AppPattern.kt:39`, `[,;，；]`), so a group written by upstream
/// and one written here stay interchangeable; names are trimmed, empties dropped, and duplicates
/// collapsed while keeping the first occurrence's order.
List<String> splitGroups(String? group) {
  if (group == null) {
    return <String>[];
  }

  final List<String> names = <String>[];
  for (final String part in group.split(_groupSeparator)) {
    final String name = part.trim();
    if (name.isNotEmpty && !names.contains(name)) {
      names.add(name);
    }
  }

  return names;
}

/// Joins [names] the way upstream does (`joinToString()`, i.e. a comma and a space).
String joinGroups(Iterable<String> names) => names.join(', ');

/// Whether [name] is a group the check should clear before it runs again.
///
/// Upstream's rule is broader than [checkOwnedGroups]: any group containing `失效` and the literal
/// `校验超时` are cleared (`BookSource.kt:243-249`). Keeping the broader rule means a group the user
/// built by hand (`翻译失效`) survives, while anything a previous check wrote is replaced.
bool isInvalidGroup(String name) =>
    name.contains('失效') || name == checkTimeoutGroup;

/// Removes every invalid group from [group] and keeps the rest in order.
///
/// This is the "re-check starts from a clean slate" half of ADR-0043 §后果: without it a source
/// that was fixed would collect groups forever and never look healthy again.
String? withoutInvalidGroups(String? group) {
  final List<String> kept = splitGroups(group)
      .where((String name) => !isInvalidGroup(name))
      .toList(growable: false);

  return kept.isEmpty ? null : joinGroups(kept);
}

/// Adds [names] to [group] without duplicating what is already there.
String? withGroups(String? group, Iterable<String> names) {
  final List<String> merged = splitGroups(group);
  for (final String name in names) {
    if (!merged.contains(name)) {
      merged.add(name);
    }
  }

  return merged.isEmpty ? null : joinGroups(merged);
}

/// Removes [names] from [group], returning `null` when nothing is left.
String? withoutGroups(String? group, Iterable<String> names) {
  final Set<String> removed = names.toSet();
  final List<String> kept = splitGroups(group)
      .where((String name) => !removed.contains(name))
      .toList(growable: false);

  return kept.isEmpty ? null : joinGroups(kept);
}

/// Prefixes the error lines the check writes into `bookSourceComment`.
///
/// `// Error: ` is upstream's marker (`BookSource.kt:215-226`), and it is what makes the note
/// removable: [withoutErrorComment] drops exactly these blocks and keeps the user's own comment.
const String errorCommentMarker = '// Error: ';

/// Prepends an error note to [comment], keeping whatever the user wrote after it.
///
/// The separator is a blank line, again upstream's shape: one note per run, the user's text below.
String withErrorComment(String? comment, String message) {
  final String note = '$errorCommentMarker$message';
  final String? rest = withoutErrorComment(comment);

  return rest == null ? note : '$note\n\n$rest';
}

/// Removes every `// Error: ` block from [comment], keeping the user's own text.
String? withoutErrorComment(String? comment) {
  if (comment == null) {
    return null;
  }

  final List<String> kept = comment
      .split(_commentSeparator)
      .where((String block) => !block.trimLeft().startsWith(errorCommentMarker))
      .toList(growable: false);
  final String rest = kept.join('\n\n').trim();

  return rest.isEmpty ? null : rest;
}

/// The group separators upstream splits on (`AppPattern.kt:39`).
final RegExp _groupSeparator = RegExp('[,;，；]');

/// The blank line upstream uses between comment blocks (`BookSource.kt:216`).
final RegExp _commentSeparator = RegExp('\n\n');
