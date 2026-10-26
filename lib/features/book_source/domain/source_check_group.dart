/// The group tokens the batch check writes into a source's `bookSourceGroup`.
///
/// They are data written into the source, not UI copy, so they never follow the interface
/// language.
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

/// Splits one `bookSourceGroup` value into trimmed, de-duplicated names.
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

/// Joins [names] with a comma and a space.
String joinGroups(Iterable<String> names) => names.join(', ');

/// Whether [name] is a group the check should clear before it runs again.
///
/// Broader than [checkOwnedGroups]: any name containing `失效` is cleared, so a group the
/// user built by hand as `翻译失效` does not survive either.
bool isInvalidGroup(String name) =>
    name.contains('失效') || name == checkTimeoutGroup;

/// Removes every invalid group from [group] and keeps the rest in order.
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

/// The marker every error note the check writes starts with.
const String errorCommentMarker = '// Error: ';

/// Prepends an error note to [comment], keeping whatever the user wrote after it.
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

// 上游使用的分组分隔符。
final RegExp _groupSeparator = RegExp('[,;，；]');

// 上游用空行分隔注释块。
final RegExp _commentSeparator = RegExp('\n\n');
