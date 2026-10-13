import 'dart:convert';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/explore_category.dart';
import 'package:flutter_reader/features/book_source/domain/explore_categories.dart';
import 'package:flutter_reader/features/book_source/domain/page_fetch_service.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_engine.dart';
import 'package:flutter_reader/features/book_source/domain/rule_engine/rule_scope.dart';

/// Reads the discover-page categories of one book source (`book-source.md` §4.2).
///
/// `exploreUrl` has two mutually exclusive forms, decided by its prefix (ADR-0035 §决策 3):
///
/// * **a category string** — entries `标题::URL` separated by runs of `&&` or newlines;
/// * **one whole-field script** — `@js:…` or `<js>…</js>`, whose result may be a JSON array of
///   objects or the very same separated string (both are read).
///
/// The script runs in the sandbox with the field's own bindings (ADR-0035 §决策 4): `baseUrl` is
/// the **book source URL**, `page` is `1`, there is no `key` and no `result`, and `infoMap` — a
/// host-side table M1 does not have — is a `js:error` rather than a silent `undefined`. The
/// variables of `@put:` / `@get:` / `java.*` are the source's own (ADR-0034).
///
/// A field that names a script but is not one, a script that fails, or a result that is neither
/// shape is a **field failure** (`parseFailed`) instead of an invented “ERROR:” category: the
/// upstream behaviour of showing the error as content is registered as a deliberate difference
/// (ADR-0035 §决策 4). Categories that the parse rejects are **logged and skipped**, so the rest of
/// the discover page still opens (C-SRC-4).
final class FetchExploreCategories {
  /// Creates the use case.
  const FetchExploreCategories({required this._engine, required this._pages});

  final RuleEngine _engine;
  final PageFetchService _pages;

  /// Returns [source]'s discover categories, in the order its `exploreUrl` lists them.
  ///
  /// A source without an `exploreUrl` is a normal source, not a broken one: it answers an **empty
  /// list**, which is what the discover page shows as its empty state. Only a *declared*
  /// `exploreUrl` that cannot be read is a failure.
  Future<ParseResult<List<ExploreCategory>>> execute(BookSource source) async {
    final String text = (source.exploreUrl ?? '').trim();
    if (text.isEmpty) {
      return const ParseSuccess<List<ExploreCategory>>(<ExploreCategory>[]);
    }

    final _ExploreUrlForm form = _formOf(text);

    return switch (form) {
      _CategoryStringForm(:final String value) => _collect(
        parseExploreSource(value),
        source,
      ),
      _WholeFieldScriptForm(:final String script) => await _evaluate(
        script,
        source,
      ),
      _BrokenScriptForm(:final String reason) =>
        failureAt<List<ExploreCategory>>(
          kind: ParseFailureKind.parseFailed,
          rulePath: 'exploreUrl:$reason',
        ),
    };
  }

  /// Runs the whole-field script and reads its result (`ADR-0035 §决策 4`).
  Future<ParseResult<List<ExploreCategory>>> _evaluate(
    String script,
    BookSource source,
  ) async {
    final ParseResult<Object?> evaluated = await _engine.evaluateJs(
      script,
      rulePath: 'exploreUrl',
      context: JsPageContext(
        baseUrl: source.url,
        page: 1,
        source: source.jsSourceInfo,
        headers: source.headers,
      ),
    );

    return switch (evaluated) {
      ParseFailure<Object?>(
        :final ParseFailureKind kind,
        :final String rulePath,
      ) =>
        failureAt<List<ExploreCategory>>(kind: kind, rulePath: rulePath),
      // 脚本返回数组时桥给的是解码后的 JSON 值，返回字符串时两种形态都在 `parseExploreSource` 里认。
      ParseSuccess<Object?>(:final Object? data) => switch (data) {
        final List<Object?> entries => _collect(
          parseExploreSource(jsonEncode(entries)),
          source,
        ),
        final String text => _collect(parseExploreSource(text), source),
        _ => failureAt<List<ExploreCategory>>(
          kind: ParseFailureKind.parseFailed,
          rulePath: 'exploreUrl',
        ),
      },
    };
  }

  /// Keeps the parsed categories, and records every rejected entry (C-SRC-4).
  ParseResult<List<ExploreCategory>> _collect(
    ExploreCategoryParse parsed,
    BookSource source,
  ) {
    for (final String rejection in parsed.rejected) {
      _pages.warn(
        'Explore category rejected: source=${source.url} field=exploreUrl '
        'kind=${ParseFailureKind.unsupportedRule.name} reason=$rejection',
      );
    }

    return ParseSuccess<List<ExploreCategory>>(parsed.categories);
  }

  /// Decides which of `exploreUrl`'s mutually exclusive forms [text] uses.
  ///
  /// The `<js>` form must **end** with `</js>`: upstream truncates at its last `<`
  /// (`BookSourceExtensions.kt:66-78`), which quietly accepts trailing garbage, while this
  /// repository reports the field instead (ADR-0035 §决策 3, registered difference ①).
  _ExploreUrlForm _formOf(String text) {
    final String lower = text.toLowerCase();
    if (lower.startsWith('<js>')) {
      if (!lower.endsWith('</js>')) {
        return const _BrokenScriptForm('js-not-closed');
      }

      return _WholeFieldScriptForm(text.substring(4, text.length - 5));
    }
    if (lower.startsWith('@js:')) {
      return _WholeFieldScriptForm(text.substring(4));
    }

    return _CategoryStringForm(text);
  }
}

/// Which form an `exploreUrl` declaration uses (`book-source.md` §4.2).
sealed class _ExploreUrlForm {
  const _ExploreUrlForm();
}

/// The separated `标题::URL` form.
final class _CategoryStringForm extends _ExploreUrlForm {
  const _CategoryStringForm(this.value);

  /// The declaration itself.
  final String value;
}

/// A whole-field script, with its flag (and its `</js>` suffix) already removed.
final class _WholeFieldScriptForm extends _ExploreUrlForm {
  const _WholeFieldScriptForm(this.script);

  /// The JavaScript to run.
  final String script;
}

/// A `<js>` declaration that does not close with `</js>` (registered difference ①).
final class _BrokenScriptForm extends _ExploreUrlForm {
  const _BrokenScriptForm(this.reason);

  /// The marker appended to the field path, e.g. `js-not-closed`.
  final String reason;
}
