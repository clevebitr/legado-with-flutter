# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Book source management can finally write: batch edits, search, groups, an editor, export (M13-S2..S5)

- **Selection mode**: long-press a row, then select all / invert and run **enable / disable / delete /
  group** over the whole selection — one transaction each, so a half-applied batch cannot happen. The
  row's “read” marker and the check columns are untouched by batch actions: they only move **user
  state** (ADR-0050 §decision 2).
- **Two filter axes instead of one mixed one** (the reason 「全正常的书源分组」 was impossible): the
  **group** chips read `bookSourceGroup` from the payload, the new **check-status** chips
  (all / healthy / has-failures) read the check's own columns. A checked source used to show
  「搜索失效」 where its author's group should be; now both are visible and independent.
- **Search** filters the visible rows by name / URL / group without touching the store.
- **Group management**: put the selection into an existing group, a new one, or none — it rewrites
  the payload's `bookSourceGroup` only (the fingerprint does not include it, so identities are stable).
- **Editor page** (`/sources/edit`): name / URL / group / type / weight / header and the five rule
  blocks, seeded from the **stored payload** so unmodelled keys survive; saving validates with
  `BookSource.fromLegadoJson` and refuses an edit whose new `(url, fingerprint)` already belongs to
  another row instead of merging two sources (ADR-0050 §decision 3).
- **Single-source check and export** in the row menu: the check reuses M10's `CheckBookSource` (so a
  single check and a batch check cannot disagree), and the export copies the **payload bytes** to the
  clipboard and offers a save dialog — the payload, not `toJson`, is what makes a re-import produce
  the same source (ADR-0050 §decision 4). New `BookSourceFileSaver` port with the `file_selector`
  implementation and an “unsupported platform = not saved” fallback (C-PLT-1).
- Testing: the list page gained selection / search / check-filter / export widget tests, the editor
  has fill / save / invalid-input / identity-conflict tests, the repository got payload, batch,
  group and update tests (including “a row with a broken payload is skipped, not fatal”), and the
  saver's adapter is tested through an injected writer.
- ADR-0050 records all four decisions; roadmap §3.9 marks S1–S6.
- Gates: format 0 changed, analyze clean, **1263** tests, `core` 100%, `domain` 100%, `data` 98.72%,
  license scan `Risky items: none`, generated files in sync.


### Covers everywhere, and a detail page that can start reading (M13-S1/S6, `roadmap.md` §3.9)

- **Book covers are shown at last**: `cached_network_image` had been a dependency since the first UI
  slice and was **never referenced**, so not one cover appeared anywhere. A shared `CoverImage`
  (placeholder / failure state / decode bounded to the thumbnail / decorative for screen readers) now
  backs the discover list, the merged search results, the detail page and the shelf. The URL was
  already resolved to an absolute one by the domain (`Book` / `SearchBook` / `BookInfo` / `ShelvedBook`),
  so this is a pure UI slice.
- **The detail page can start reading**: it had no way in except tapping one chapter row, which only
  works if the reader already knows where to go. It now offers 「开始阅读」(first chapter) and
  「继续阅读」(no chapter URL — the reader restores the stored position, ADR-0044 §decision 4), both
  through the `AppNavigation` port so `book_source` still does not import `reader` (ADR-0042).
- **The introduction collapses to three lines** with a show-more toggle: a thousand-chapter table of
  contents used to be pushed off-screen by one long blurb.
- The shelf keeps its “read” marker as a badge on the cover, because the cover replaced the icon slot.
- Testing: `CoverImage` takes an `ImageProvider` seam, so the loaded and failed branches are reachable
  in a widget test with a 1×1 PNG and with undecodable bytes — no network stack, no cache-manager
  mock. New `FakeAppNavigation` lets a page test assert *what* it asked to open (`chapterUrl == null`
  for “continue”).
- Gates: format 0 changed, analyze clean, **1234** tests, `core` 100%, `domain` 100%, `data` 98.47%.


### Book context reaches the rules, one budget for one source, and Big5 decodes (M12, second slice)

- **`java.get('bookName')` / `java.get('title')` work** (the last rule-surface item of M12): both are
  upstream **built-in** keys, answered *before* the source's variables, so `java.put('title', …)` cannot
  hijack them. `FetchContent` now takes a `ChapterRequest{url, title, bookName}` instead of a bare URL —
  a `@js:` rule can only read what the caller knows, and the reader is the one caller that knows both
  names. The reader's two ports gained optional parameters, so nothing else had to change (ADR-0049).
- **One `SourceBudget` instead of two `.timeout(...)` wrappers**: "this source has had its turn" is now
  one collaborator (limit + remaining + `run`), used by the aggregate search (60 s, ADR-0046) and the
  source check (180 s, ADR-0043) — a third batch caller no longer has to write a third copy. The budget
  only decides *how long we wait*, never *whether it worked*, and it never cancels an in-flight request
  (the HTTP layer has no cancellation primitive, the same reason pause/cancel are cooperative).
- **Big5 / Big5-HKSCS decode now, detect still does not.** `charset` ships no Big5 codec and no permissive
  alternative existed, so the licence policy changed instead: MPL-2.0 is GPL-3.0 compatible, and
  `enough_convert` (pure Dart, zero dependencies) is admitted **through a one-entry allow-list** in
  `tool/scan_licenses.dart` — a second MPL dependency fails the scan until someone writes another ADR
  (ADR-0048). The URL-declared charset (§4.3) and `Content-Type` / `<meta>` declarations all reach it;
  an undeclared Big5 page is still not guessed, and HKSCS' extension区 decodes to U+FFFD.
- `shift-jis` / `euc-jp`'s `RangeError` stays registered: `enough_convert` has no Japanese tables, and a
  byte pre-validation layer would be unverifiable with zero Japanese sources in the corpus.
- ADR-0048 / ADR-0049 record the decisions and the four evidence sets; `NOTICE.md` §5/§6, C-DEP-7 and
  `tech-stack.md` §5 now state the allow-list rule instead of "MPL is forbidden".
- Gates: format 0 changed, analyze clean, **1223** tests, `core` 100%, `domain` 100%, `data` 98.47%,
  license scan `Risky items: none` (166 packages, MPL 1 = the allow-listed one), generated files in sync;
  device probes on Windows and Android, `js_bridge` **25/25** on both (the new built-in-key probe included).


### Real sources actually run: URL rules, `<js>`, and one broken source no longer sinks the batch (M12, first slice)

Measured, not guessed: a new `tool/spot_check/batch_probe.dart` runs a whole collection through the four stages and
prints a `stage/kind/rulePath` histogram. On the 128-source collection this was checked against, **8 of 128 completed**
before this slice and **10** after — and the 118 that still fail are dead sites (DNS gone, 301 to another domain, empty
body, login token required), not rules this repository cannot read. The distribution is in ADR-0047.

- **`searchUrl` is a rule, not an address.** 50 of the 128 sources write `…/search.php,{"method":"POST",
  "body":"searchkey={{key}}"}` or append `{"charset":"gbk"}`. Sending that comma as part of the URL is why so many
  answered 404. `domain/url_rule.dart` now splits the `,{…}` suffix with a tolerant scanner (single quotes, unquoted
  keys, `{{…}}` inside values), and `PageFetchService.fetchRule` owns the whole rule: POST bodies, per-request headers,
  a `charset` that decides both how `{{key}}` is escaped **and** how the response is decoded, and a keyword that stays
  verbatim inside a JSON payload while being percent-encoded in a form (`book-source.md` §4.3).
- **`<js>…</js>` anywhere in a rule** (matrix #31, 50 sources): segments are evaluated in order and each one receives
  the previous one's output as `result`, which is what makes `<js>…</js>https://…/{{result}}.html` produce an address.
  A trailing `@js:` keeps its old single-segment semantics — the chain only runs when `<js>` is really there.
- **List rules accept JavaScript**: `bookList` / `chapterList` written as `@js:` or `<js>` return the element list
  (a string becomes a DOM fragment, an object a JSON item), replacing the old `unsupported:@js:list` refusal.
- **A JSON item's `result` is the item**, not its JSON text (`book-source.md` §6): `@js:result.Name` works on a
  `bookList` entry now, while a fetched page still hands the script its body.
- **`header` written as a rule is evaluated before the first request** (3 sources used to fail at *import*): the text
  lands in `BookSource.headerRule`, `PageFetchService.headersOf` turns it into a header map, and a broken header script
  keeps the static headers with a warning instead of costing the source.
- **`$.[*]`** (a Legado JSONPath spelling RFC 9535 rejects) is normalised, which turned one source's search from
  `parseFailed` into real hits.
- **Two "investigate first, then decide" registrations ended as *no change***: reading default/`@@` rules as JSON on a
  JSON page, and the `page` binding of field rules. Upstream's jayway JsonPath also needs the `$` prefix and field rules
  never consume `page`, so switching the analyser would only move where wrong rules fail (ADR-0047 §decision 6).
- **One broken source can no longer blank the screen**: three separate leaks are closed. `redactUrl` no longer throws on
  a query that is not valid percent-encoded UTF-8 (a GBK keyword does exactly that — and logging must never be what
  fails a request); a `receiveTimeout` that arrives while the body is *read* is mapped to a `ParseFailureKind` instead
  of escaping `HttpClient`; and the aggregate search counts a throwing source as one failed source, keeps the hits it
  already published, and the page only shows the failure message when there is nothing to show.
- ADR-0047 records the decisions, the three "no change" verdicts and the evidence table; `book-source.md` gained §4.3,
  a new `header` row, the `#14`/`#31` matrix statuses and a §10 evidence block.
- Gates: format 0 changed, analyze clean, **1204** tests, `core` 100%, `domain` 100%, `data` 98.47%, generated files in
  sync.


### Aggregate search reaches the screen: scopes, filters, progress and one merged list (M11, second half)

- **The search page searches a scope, not "the selected source"** — a behaviour change worth naming: the default
  scope is every enabled text source, so pressing search on a fresh install queries all of them. The scope chip opens
  one sheet with the radio part (all / a group) and the check-box part (specific sources), and the choice is stored
  (ADR-0046 §decision 1).
- **Filters sheet**: source types (default text only) and the match mode, both applied to the next run
  (ADR-0046 §decision 2/3).
- **One merged list**: a hit shows its author, its update time and how many sources found it; tapping it selects the
  first origin and opens the detail page **through that source**, which is what makes "the same book in six sources"
  behave like one row (ADR-0046 §decision 4).
- **Progress, pause, resume, stop, load more**: the progress line stays visible after a run that had failures ("n
  sources failed"), because results that silently shrink are worse than a visible count (ADR-0046 §decision 5/6).
  When every source fails, the failure keeps the first source's kind instead of a blanket network error.
- **The check page gained the same two axes**: group and type chips narrow which sources are listed; the tick boxes
  still decide what runs, so narrowing never silently changes a selection. That is the 「书源测试分类」the milestone
  asked for, and it shares one meaning of "these sources" with the search page.
- **ADR-0046** records the seven decisions; roadmap §3.8 closes M11 and registers the two deliberate gaps (results are
  not persisted, non-text sources have no reader).
- Gates: format 0 changed, analyze clean, **1155** tests, `core` 1245/1245, `domain` 2458/2458, `data` 98.47%.

### Aggregate search engine: scopes, type filters, match buckets and merging (M11, first half)

- **Search scope** (`BookSearchScope`: all / groups / named sources) with upstream's JSON payload, and the fallback
  rule: a scope that names something gone falls back to "every enabled source" instead of searching nothing
  (ADR-0046 §decision 1).
- **Source-type filter, defaulting to text only.** The app reads text chapters, so pulling audio / image / file
  sources into results would offer rows that cannot be opened — a deliberate difference from upstream, which has
  players for them (ADR-0046 §decision 2).
- **Match modes are bucket ordering, not filtering**, ported from upstream: `equal` / `tags` / `contains` / `other`,
  and `exact` keeps only `equal` — the part that surprises is written out as a table so it cannot be misread
  (ADR-0046 §decision 3).
- **Merging** de-duplicates by `(name, author)` and records every source URL as an origin, which is what the
  "N sources" marker will count; inside a bucket the rows sort by origin count, the cap is 1000, and eviction follows
  upstream's order (ADR-0046 §decision 4/7).
- **One source cannot sink the batch**: per-source 60 s timeout (injected for tests), failures only counted, and an
  all-failed batch is the only failure. "The list rule matched nothing" is read as *no results*, not as an error —
  otherwise a keyword nobody has would be reported as every source being broken (ADR-0046 §decision 5).
- **Pause, resume and cancel** are cooperative and land between sources, and a cancelled batch keeps what it found
  (ADR-0046 §decision 6). Paging skips sources that declare no `page` support instead of asking them for the same
  page again (ADR-0046 §decision 7).
- **`resolveSearchSources`** is the one place that answers "which sources take part", so search and the 5.10 consoles
  will share it instead of growing two selection implementations.
- Not in this slice: the search page's scope / type / match UI and the merged result list (registered in
  `docs/dev/roadmap.md` §3.8 as the remaining half of M11).
- Gates: format 0 changed, analyze clean, **1150** tests, `core` 1245/1245, `domain` 2456/2456, `data` 98.47%.

### The source list can be sorted, filtered and dragged (5.5)

- **Four sort keys with a fixed tie-breaker.** Manual order (the default), weight descending, response time
  ascending and name ascending; every key is followed by enabled-first, then the manual order, then the row id — so
  the same data always comes back in the same order (ADR-0045 §decision 2). A source that was never checked has no
  response time, so it sorts **after** the measured ones instead of looking like `0 ms`.
- **Group filter and drag-to-reorder.** The list filters by the group tokens the rows carry (including the
  `搜索失效` ones the batch check writes), and in the manual order the rows are draggable: dropping renumbers
  `customOrder` as `0..n-1` in one transaction, because swapping neighbours has no defined result when two rows share
  a value (ADR-0045 §decision 3). Other keys disable dragging instead of letting a drop jump back.
- **The list reads the columns, not the payload.** `StoredBookSource` now carries the five column projections
  (`groupName`, `lastUpdateTime`, `respondTime`, `weight`, `comment`); 5.10's check writes those columns while the
  payload stays byte-for-byte, so without this the list would keep showing the state from before the check
  (ADR-0045 §decision 1).
- **Sort key and group filter are remembered** in `book_source/data/` (keys private to that file). A stored group
  that no longer exists falls back to "all groups" while rendering rather than writing a correction from a build.
- Row actions moved into a menu (debug / view note / delete) instead of four trailing icons; the note itself shows
  its first line inline and the whole `// Error:` block in a dialog.
- **ADR-0045** records the four decisions; roadmap §5.5 is closed.
- Gates: format 0 changed, analyze clean, **1083** tests, `core`/`domain` 100%, `data` >= 80%, generated files in
  sync; Windows and Android device-level tests re-run.

### The reader lands: its own typography, both page modes and remembered positions (2026-10-21)

- **New `reader` feature (5.3).** `ReaderPage` / `ReaderRoute` moved out of `book_source`; the page shows one chapter
  with the chapter list, the reading settings and previous / next around it, and it opens from a detail page's chapter
  row (at that chapter) or from a shelf row (where the reader stopped).
- **Reading settings are the reader's own**: text size, line spacing, background and page mode, stored in
  `shared_preferences` and **multiplied on top of** the app-wide text scale instead of sharing one knob. Backgrounds
  are derived from theme colours (system / paper / sepia / dark), so the reader still follows the theme and dynamic
  colour (ADR-0044 §decision 1).
- **Both page modes** (user decision): a scrolling body and pages split by a real `TextPainter` measurement, with an
  end-of-chapter page that offers the next chapter. The character offset is a documented **estimate**
  (fraction read x body length), which is what survives a font change (ADR-0044 §decision 4).
- **Progress is read and written through one port.** ADR-0041 listed only a writer; restoring a position needs a
  reader, so `ReadingProgressStore` is read + write and the composition root binds it to the shelf, which owns the
  table. A cancelled/absent binding degrades to "start at the first chapter" plus a warning (ADR-0044 §decision 2).
- **`books.tocUrl`** (schemaVersion 4 -> 5, dumped schema, migration tests, a real write in `on_disk_database_test`)
  so opening from the shelf does not have to guess where a source keeps its chapters (ADR-0044 §decision 3).
- **Two registered items are closed:** `updateTime` is shown in the hit list, the detail block and the chapter rows
  (empty means no line, never "unknown"), and `canReName` found its consumer: adding an already-stored book only
  overwrites its title and author when the source declares the rule (ADR-0044 §decision 5).
- **ADR-0044** records the four decisions this slice had to make; the new open items (exact character anchors, page
  break approximation, cross-chapter paging, golden baselines) are registered in `docs/dev/roadmap.md` §3.7 with
  their triggers.
- Gates: format 0 changed, analyze clean, **1050** tests, `core` 1225/1225, `domain` 2198/2198, `data` 98.2%,
  generated files in sync; Windows and Android device-level tests re-run.

### The book-source check mechanism lands: batch verdicts and a single-source console (2026-10-21)

- **Batch check (5.10).** `CheckBookSource` walks search -> detail -> chapters -> body (explore the same way) on one
  source and answers with a pure `SourceCheckReport`; `SourceCheck` (the notifier) runs a batch with the user's
  per-source concurrency, holds the long-task marker, and writes each verdict back through `BookSourceRepository`.
- **The verdict lands in columns, not in the payload.** `book_sources` gains a `comment` column (schemaVersion 3 -> 4,
  dumped schema + migration tests + a real write in `on_disk_database_test`); `groupName` takes the upstream tokens
  (`搜索失效` / `搜索目录失效` / ... / `校验超时` / `js失效` / `网站失效`), `respondTime` takes the elapsed time, and the
  previous run's invalid groups and `// Error: ` note are cleared first, so a fixed source becomes healthy again.
  `payload` is untouched: it stays the export source of 5.8 (ADR-0040 §decisions 4).
- **`checkKeyWord` is modelled** (`SearchRule.checkKeyWord`) and its "looks like a rule" predicate is spelled out
  (`resolveCheckKeyword`: `http` / `://` / `::` / `++` / `--` / `##` / `{{`, or a leading `@` / `$`), closing the
  `docs/dev/roadmap.md` §3.7 registration. The fallback keyword is data, not UI copy, so it stays out of ARB.
- **Single-source console (5.10).** `RunSourceDebug` runs one target (search / explore / detail / chapters / body) and
  streams typed events (message / source / error, each with an elapsed time); the page shows them with one-tap examples
  taken from the source itself. A body's text never reaches the console - only `chars=<n>`.
- **Cancellation is `Cancelled`, never `Failed`.** Both runs share a cooperative `TaskCancellation` checked between
  stages; a stopped batch writes nothing back. Upstream's `Incomplete` has no counterpart here (ADR-0043 §consequences).
- **`ParseFailureKind` is unchanged.** Stage failures live in `SourceCheckStageOutcome`; "a script broke" is read from
  the existing `:js:error` / `:js:timeout` rule-path markers, in exactly one place (`checkGroupForFailure`).
- **New platform port `LongRunningTask`** (`core/platform/`): Android holds a `PARTIAL_WAKE_LOCK` (channel + permission,
  no new dependency), Windows / iOS get the no-op. A **foreground service** is registered as open with its trigger.
- **ADR-0043** records the four decisions M10 had to make before any code was written.
- Reproductions of the five judgeable failures (empty search / empty chapters / empty body / timeout / broken script)
  are recorded in `tool/spot_check/source_check_records.md`.
- Gates: format 0 changed, analyze clean, **1003** tests, `core` 1219/1219, `domain` 2168/2168, `data` 142/142,
  generated files in sync; Windows and Android device-level tests re-run for the `core/platform/` change.

### The shelf and the settings page land; the book-source check mechanism is planned (2026-10-21)

- **Shelf (5.4).** `books` + `reading_progress` (schemaVersion 2 -> 3, dumped schema + migration tests + a real
  write in `on_disk_database_test`), `BookshelfDao` / `BookshelfRepository` / `Bookshelf` notifier / `BookshelfPage`.
  The identity is `(sourceUrl, bookUrl)` - the source is referenced by URL, not by `book_sources.id`, because that id
  belongs to one imported row. Re-adding is a snapshot refresh that keeps the user state (`status` / `isPinned`).
  The detail page's "add to shelf" goes through a `BookshelfWriter` port bound at the composition root (ADR-0041).
- **Settings (5.6).** `AppSettings` (clamped in the factory, **not** asserted), `SettingsRepository` over
  `shared_preferences` with keys private to `settings/data/`, and the page (theme, text scale, concurrency, cache).
  Theme and text scale are wired in `app.dart` - the stored scale stacks on top of the platform accessibility scale -
  and the concurrency budget reaches `HttpPolicy` through `concurrencySettingProvider`, which the root binds.
  Cache clearing (5.7 (1)) landed with it: `CacheDao.deleteAll` + a `CachePurger` port.
- **Two registered items are closed:** the `assert`-only concurrency guard (now `budgetOrDefault`, which also runs in
  release: a value `<= 0` falls back to the default and logs) and the auto-disposed HTTP budget
  (`httpClientProvider` is `keepAlive`, so a batch shares one budget instead of getting a fresh one per batch).
- **Four deferred, written down instead of silently skipped:** `java.get('bookName')` (needs Book/Chapter bound into
  the JS variable table), `downloadUrls` / `relatedBooks` (rule-face, no corpus evidence), the "About" entry (it
  belongs to 5.9's legal page - a menu row opening nothing is a dead end) and per-source cache purge (5.7 (2)).
  All four in `docs/dev/roadmap.md` §3.7 with their triggers.
- **ADR-0042:** cross-feature navigation goes through a presentation port (`AppNavigation`, bound by
  `appProviderOverrides()`) because a `domain/` port cannot carry a `BuildContext`; `StateMessage` /
  `FailureMessage` moved to `core/widgets/` since three features now share them.
- **M10 is planned, not built.** `docs/dev/roadmap.md` §5.10 writes down both mechanisms of the upstream repository
  (`BookSourceCheckRepository` batch check + `ui/book/source/debug` single-source console) and the four decisions that
  must be made before implementation starts.
- Gates: format 0 changed, analyze clean, **897** tests, `core` 1184/1184, `domain` 1892/1892, `data` 130/130,
  generated files in sync.

### PLAN.md is the plan plugin's state file now; the roadmap moved to `docs/dev/roadmap.md` (2026-10-21)

- **Why the split.** The `plan` extension only knows its own format (`<!-- plan-bridge:state -->` + `## Milestones`
  + `## Current`) and refuses to overwrite a foreign PLAN.md, while the roadmap's `5.x` acceptance, `G1`-`G7`
  and 17 traps are referenced from ~90 places. So the root `PLAN.md` now holds **only milestone-level state**
  (current milestone / goal / breakpoint, written through the `plan` tool) and everything a human reads moved to
  `docs/dev/roadmap.md` **with the section numbers unchanged**, so existing references keep resolving.
- **Milestones map 1:1 onto the roadmap's steps:** M1-M3 done (5.0 specs, 5.1 book source entry, 5.2 body cache),
  M4-M9 open (5.3 reader … 5.9 platform + legal notice); M4 is current, one-line goal and breakpoint set.
- **~90 references repointed** - `docs/README.md` (entry table, ownership matrix), `AGENTS.md` section 2,
  `README.md`, `book-source.md`, `test-environment.md`, `tool/spot_check/`, and the doc comments in `lib/`,
  `test/`, `integration_test/` (generated files came back through `build_runner`, never hand-edited).
  **ADRs and CHANGELOG keep their historical `PLAN.md` section references**: they are immutable records, and
  `roadmap.md`'s header states that `PLAN.md` §X means `docs/dev/roadmap.md` §X.
- **`DECISIONS.md` is new** - the plugin's append-only `#N` log, for execution-time findings; formal decisions
  still belong in `docs/dev/adr/`. Entry #1 records this split plus the migration trap: `git mv` left the
  extension's own 16-line skeleton at the destination, so copy to `build/` first next time.
- Gates: format 0 changed, analyze clean, **788** tests, `core` 1032/1032, `domain` 1857/1857, `data` 64/64,
  generated files in sync.

### PLAN.md keeps only what is still open (2026-10-14)

- **The finished phases are one line each.** Phase 0-4 (section 3.2-3.5) collapsed from step tables plus dated
  status prose into one line per phase that names its steps and its evidence. The section anchors were kept
  deliberately: ~40 cross-references in `README.md`, `docs/`, the ADRs and code comments name 3.2-3.6, so they
  still resolve. The status table in 3.1 is three rows and delegates the detail here.
- **Section 3.7 shrank from 59 rows to 17.** Everything closed or withdrawn (the concurrency budget, M1 #15-#19,
  rule variables not persisted, `ruleBookInfo.init`, b1b's rework and its real-source run, `{{…}}` + `##`,
  JSONPath `]name`, the charset cache, `bookSourceType` 4, the `java.*` compat surface) is now only in this
  file's history. The deliberately-left-alone differences stay as **one** row pointing at the notes in
  `book-source.md` 3/4.2/6/11 and ADR-0029/0035, and every open row keeps one line: where it goes (5.3-5.8, b7)
  or what would reopen it.
- **The gate table folds G2b/G3/G4 into one achieved row** and the "which gate belongs to which phase" note is
  two lines instead of a paragraph. No acceptance criterion was dropped; PLAN.md is 511 -> 283 lines.

### File import for book sources, and the two gaps a real export exposed (2026-10-14)

- **A file can be picked directly.** The user asked for it, so ADR-0040 decision 9's file half moved
  forward from 5.8: `BookSourceFilePicker` lives in `core/platform/` (C-PLT-1) with a `file_selector`
  implementation - the Flutter team's federated plugin, BSD-3-Clause, official Android/iOS/Windows
  implementations - and a fallback for platforms without a dialog that answers "nothing picked"
  instead of throwing. `pubspec.yaml`, `tech-stack.md` section 6 and `NOTICE.md` section 5 were
  updated as one batch (C-DEP-6); the licence rescan is 165 packages, no risky items. The size cap is
  checked on the file's **size before it is read**, so an oversized file never enters memory.
- **A real 504-source export drove two fixes** (evidence in ADR-0040's revision note):
  - `bookSourceType` 4 is now modelled as **video** (upstream documents 0-4), which alone recovered
    8 entries; an *unknown* value still skips the entry, because silently presenting an audio source
    as text is worse than a visible failure (ADR-0022 section 5).
  - `header` became the **one degradable single-entry field**: a rule-based (`@js:` / `<js>`) or
    malformed header is dropped with a warning and the source still imports - losing a source over
    its user agent is the worse outcome. The lenient single-quote dialect upstream's GSON accepts is
    handled by the field itself (strict JSON first; the fallback applies only when the text carries
    no double quote at all).
  - Result on that file: **503 imported, 1 skipped** (its `ruleToc` is missing, which decision 6
    skips on purpose), 36 headers degraded with warnings - against 457/47 before.
- Gates: **788** cases, `core` 1032/1032, `domain` 1857/1857, `data` 64/64; device probes
  **Windows 93 s** and **Android 158 s** (three files each) - re-run because a native plugin changes
  both builds (ADR-0039). The import screen carries a third action next to paste and URL.

### P5-2 lands: the chapter body cache (2026-10-14)

- **`ContentCache`** (a `domain/` port) + `CacheDaoContentCache`: the finished chapter body - paging
  already joined and `replaceRegex` already applied - is stored in the existing `cache_entries` table
  under the DAO's stable key (`ruleField=content`, `page=1`, keyed by book source too), with
  `chapterCacheTtl` (half a day) as the one TTL definition. No column, no table, no schema change.
- **`FetchContent` consults it first**: a hit skips the whole engine and sends no request at all
  (not even entering the source's rate budget), and only a successful body is written, so a failure
  is never cached as content.
- **The absorption became one function:** `absorbCacheFailure` in `core/storage/` is now the app's
  single `on Exception` point, shared by the charset cache and the chapter cache; ADR-0033 gained a
  revision note moving its exemption anchor from `CacheDaoCharsetCache._absorb` to that function
  (one auditable clause, `Error` still uncaught, named clauses first).
- Gates: **773** cases, `core` 1017/1017, `domain` 1840/1840, `data` 64/64; the harness overrides the
  cache with an in-memory double, so the page tests keep running without a database.

### P5-1 lands: the book source entry (2026-10-14)

- **The feature's first `data/` consumer.** `book_sources` (`schemaVersion` 1 -> 2) stores every
  imported source under ADR-0040's identity - a synthetic `id` plus `UNIQUE (url, fingerprint)` -
  with the raw payload column that 5.8 exports from, and with `enabled` / `customOrder` as user
  state an import never overwrites. `BookSourceDao` owns the row shape and the row order
  (enabled -> `customOrder` -> `id`); `BookSourceRepositoryImpl` owns "what the same source is" via
  `bookSourceFingerprint`, which `tool/spot_check` now imports instead of keeping its own copy, so
  the census and the repository cannot drift apart.
- **Import** (`ImportBookSources`) takes pasted JSON or a URL. The 32 MiB cap is enforced in UTF-8
  bytes *before* parsing for text, and **while downloading** for a URL: the request layer streams
  the body and abandons it the moment the cap is passed (`BodyTooLargeException`, C-PERF-5) rather
  than buffering it, and the import rewrites that marker into `import.sizeLimit`. File-level
  rejections are `import.notJson` / `import.noEntries`; single entries are skipped, counted and
  logged with their index, failing field and URL - never their body (C-ERR-8).
- **The selection is real:** `SelectedBookSource` (`keepAlive`) resolves ADR-0040's default order
  and falls back to it when the selected row is deleted, while `currentBookSourceProvider` stays a
  synchronous projection so the four parsing pages keep reading a `BookSource?` unchanged.
- **UI:** the source list (current marker, enable switch, delete with confirmation, and a marker on
  rows that share a URL with another source) and the import screen (paste / URL, plus the
  "imported / skipped" summary), reachable from the search page's app bar and from its empty state -
  which no longer claims that imports arrive in a later version.
- Gates: **763** cases, `core` 1014/1014, `domain` 1837/1837, `data` 54/54; device probes
  **Windows 99 s** and **Android 169 s** (three files each, `js_bridge` 24/24), including a new
  `on_disk_database` case that writes a `book_sources` row and reads it back across connections.

### P5-0 is drafted: the Phase 5 specs, as four Proposed ADRs (2026-10-14)

- **What landed.** The Phase 5 prerequisite (`PLAN.md` section 3.6, 5.0) is written out: the import
  contract (**ADR-0040**), the feature boundaries (**ADR-0041**), the ADR-0021 **review note**
  (the exception stays; its triggers are rewritten) and the ADR-0034 **revision note** (rule
  variables are *not* persisted). Specs synced in the same change: `book-source.md` section 2
  (source identity and duplicate import), `architecture.md` sections 1/2/6 (feature list, the
  cross-feature port rule, the page/route table), and two bilingual ARB keys for the import
  screen (`bookSourceImportSucceeded` / `bookSourceImportPartiallySkipped`).
- **Both new ADRs are `Proposed`,** so nothing may be implemented from them until the architect
  accepts them (`docs/dev/adr/README.md`: Proposed does not take effect). 5.1 is what unblocks
  5.2-5.8, and it depends on ADR-0040.
- **The rulings, one line each:**
  - *Identity* - synthetic `id` primary key plus `UNIQUE (url, behaviour fingerprint)`, because the
    corpus is 3907 entries over 2596 URLs, 1217 of which repeat (1012 identically, 205 not).
    Importing the same pair twice is idempotent; the same URL with different rules coexists (a
    registered difference from upstream, which overwrites by URL); `enabled` / `customOrder` are
    user state that import never overwrites.
  - *Limits* - one import is capped at 32 MiB measured in UTF-8 bytes **before** parsing, and the
    download aborts past the cap instead of reading the body (C-SEC-5 / C-PERF-5). Oversized,
    non-JSON and empty inputs reuse `invalidBookSource` with the reason in `rulePath`
    (`import.sizeLimit` / `import.notJson` / `import.noEntries`) - no new `ParseFailureKind`,
    because the sealed 9-value contract is switched over in three layers while the user-visible
    consequence is the same.
  - *Entry form and dependencies* - 5.1 imports by pasting JSON text or by fetching a URL, so **no
    new dependency**; the file picker and sharing move to 5.8 together with export, where
    `pubspec.yaml` + `tech-stack.md` section 1 + `NOTICE.md` section 5 are updated as one batch
    (C-DEP-6). This changes the earlier scheduling note's "add `file_picker`" recommendation, and
    ADR-0040 decision 9 registers the difference.
  - *Boundaries* - `reader` / `bookshelf` / `settings` become features; cross-feature needs go
    through consumer-side ports bound once at the composition root (`appProviderOverrides`), so no
    feature imports another; reading progress belongs to `bookshelf`; `isVolume` / `formatJs` /
    `preUpdateJs` stay out of scope until a corpus census justifies them.

### P5-0's first evidence: the duplicate shape of the corpus (2026-10-14)

- `PLAN.md` section 3.6 5.0 has to rule on the book-source primary key and on what importing the
  same source twice does. `bookSourceUrl` alone cannot be trusted for that, so the harness
  (`--list`) now prints the shape (`_printBookSourceIdentityCensus`: two entries are "the same"
  only when name, `searchUrl`, `header` and all five rule objects are equal, compared key-order
  free).
- On the 2026-08-15 snapshot: **3907 entries, 2596 distinct URLs; 1217 URLs repeat (max 3), of which
  1012 repeat *identically* and 205 have at least one entry that differs.** Both shapes are real,
  and picking either "URL is the primary key" or "URL unique index + overwrite" loses one of them —
  which is why the ruling is the architect's, not the implementation's.
- Numbers and criterion: `tool/spot_check/README.md` section 3; the ruling itself is still open (no
  ADR yet, and P5-0's other rulings - ADR-0021 review, import size limits, new dependencies,
  feature boundaries, rule-variable persistence - are untouched).

### b7's evidence step: a JSON item as `result` in 85 real sources (2026-10-14)

- **What was measured.** `book-source.md` section 6 hands a script the item's **JSON text** on a
  JSON scope, while upstream binds the item **object** — so `result.comic_id` works upstream and is
  `undefined` here. b7 is "gather evidence first, then decide whether the contract changes", so the
  harness (`tool/spot_check`, `--list`) now prints that census instead of a throwaway script
  (`docs/dev/test-environment.md` section 6, trap 13).
- **The criterion** (in `_printJsonItemResultCensus`): the sibling fields of a **JSON** list rule
  (`bookList` / `chapterList`) plus `ruleBookInfo.*` when `init` is a JSON rule (b6's new scope),
  whose `@js:` tail or `{{…}}` body reads `result.<member>` / `result['<member>']`. `@js:` and
  `{{…}}` are both counted because both bind the current scope; `JSON.parse(result)` is counted
  separately because it reads the text correctly.
- **The number on the 2026-08-15 snapshot: 85 sources, 98 fields** (top fields
  `ruleSearch.coverUrl` 18, `ruleSearch.lastChapter` 16, `ruleToc.chapterName` 10,
  `ruleSearch.bookUrl` 10, `ruleToc.isVip` 9), with 7 further fields using `JSON.parse(result)`.
  The reviewer reproduced all three figures and the per-field distribution with an independent
  script over the same `build/ao.json`.
- **Step 2 is a decision, not a todo:** changing section 6's binding needs a new ADR first
  (`PLAN.md` section 3.5 b7). The census and its criterion are recorded in
  `tool/spot_check/README.md` section 3 and `PLAN.md` section 3.7.

### b6 lands: `ruleBookInfo.init` now scopes the detail fields (2026-10-14)

- **The bug:** `book-source.md` section 2 has always marked `BookInfoRule.init` as **M0**, but
  `FetchBookInfo` read every field straight off the page scope and nothing ever evaluated `init`
  (the Phase 4 exit caught it). On a real source that declares `init: "$.data.bookInfo"` the sibling
  rules are written **relative to that sub-object**, so every detail field came back empty - the
  "white read" the exit registered.
- **The fix:** upstream's semantics (`BookInfo.kt:58-64`) are now applied. A non-blank `init` is
  evaluated first and its result becomes the scope of every later field
  (`PageFetchService.selectScope` + `FetchBookInfo._initScope`); a blank or absent `init` keeps the
  page, so nothing else changed.
- **`init` is a scope switch, not a value field,** so it deliberately does not take ADR-0026's
  non-top-level degradation: losing the scope would empty every field at once. A rule that matches
  nothing fails as `parseFailed` with `rulePath=ruleBookInfo.init`; an unimplemented flag fails as
  `unsupportedRule` with section 7's syntax marker. Registered difference: a bare `@js:` `init`
  reports `unsupported:@js:list`, because list rules still have no "JS returns elements" contract.
- Spec: `book-source.md` section 2 gained the `init` semantics and the registered difference,
  section 3.2 the "field set gets a pre-step" line. Tests: five cases - blank init keeps the page,
  JSON sub-scope, DOM sub-scope, no match, rejected rule.
- Gates green: **697** cases, `core` 943/943, `domain` 1759/1759; device probes **Windows 80 s** and
  **Android 151 s** (three files each, `js_bridge` 24/24, exit code 0).
- **Real source:** the G4 RUN 2 derived source (`●QB女生<kd♛`, only `ruleSearch.bookUrl` changed)
  now reads `author` / `name` / `toc` / `kind` / `lastChapter` / `intro` / `wordCount` instead of
  empty values, and `lastChapter` goes from `• 1970-01-01` to
  `第1279章 也曾少年思无邪 • 2026-06-02` - that date is `$.lastUpdatetime`, which the field rules
  could not see before. Evidence in `tool/spot_check/README.md` section 4 (RUN 4).

### Phase 4 (M1) exits (2026-10-14)

- **G4 is green**: all five matrix M1 rows (#15-#19) are 已确认 with per-row evidence, and the
  reviewer re-verified the census figures, the gates and both device probes independently.
- **The exit probe (G7) ran on the frozen main (`473ff1e`):** host side 692 cases with `core` 943/943
  and `domain` 1740/1740; device level **Windows 92 s** and **Android 182 s** (including the
  emulator's cold boot), three files each, `js_bridge` 24/24, exit code 0.
- **Gate applicability is now written down** in `PLAN.md` section 4: G1-G4 belong to the engine
  phases, G5 depends on Phase 5's legal-notes page, G6 is the pre-release checklist, G7 applies to
  every phase exit - so the Phase 4 -> Phase 5 threshold is G1-G4 + G7. The old "all of them" reading
  would have demanded a page that does not exist yet, which is exactly the ambiguity this exit hit.
- **Two registrations do not block the exit** and are scheduled as their own work orders: b6
  (`ruleBookInfo.init` is marked M0 but never applied) and b7 (a bare `@js:` on a JSON item binds the
  item's JSON text where upstream binds the object).
- **The environment bit again:** five half-downloaded packages in the local pub cache made
  `m3e_design` fail to compile (`Color.harmonizeWith` missing, because `dynamic_color`'s cache entry
  was empty). Removing the five directories and re-running `pub get` restored the build;
  `test-environment.md` section 6 documents both the symptom and the suspected trigger (two
  worktrees sharing one cache).

### G4 closes: #15 confirmed on a derived HTML base (2026-10-14)

- **The reviewer approved the base correction.** The ruling asked for a derived live run; the
  delivery first tried the suggested base (漫客栈) and found it cannot work: `@@` is the
  default CSS/jsoup flag and all four of that site's stages are JSON, so the flag degrades to CSS
  through ADR-0032 and `_matchElements` fails it (RUN 3a, with the rejection and the degradation
  logged). The evidence therefore comes from the **HTML** source that G2b already verified
  (笔趣阁③, `https://www.biquge99.cc/`) with exactly one field changed - `ruleSearch.kind` gains
  an `@@` prefix - and the other three stages match the G2b baseline byte for byte
  (`toc` 1310, `content` 3031 / `sha256=6578ef3efc456856`), which is what the derivation discipline
  asks for. **G4 is met: all five M1 rows are 已确认, each with source + field + sample.**
- **Verified from this side**: gates re-run (692 cases, `core` 943/943, `domain` 1740/1740), both
  device probes re-run (Windows 74 s, Android 136 s, `js_bridge` 24/24 each), and the census figures
  reproduced with an independent replica.
- **How a source is cited in these records is now written down** (`tool/spot_check/README.md`
  section 4): the collection is an upstream snapshot that drifts, and it contains duplicate
  name+URL entries (five for `笔趣阁③`), so the identity is **name + `bookSourceUrl` + the derived
  file**, with "collection C entry N" only as an auxiliary locator. That also settles why the G2b
  record says "entry 42" and the G4 record "entry 63" for the same source.
- **Registered, not scheduled**: a default / `@@` rule on a JSON scope always fails here. That is
  per spec in this repository, but upstream picks its analyser by page type, so the check to run is
  whether upstream reads such a rule as JSONPath - plus a real "JSON page + `@@`" instance, which
  the source-level census (319/25) cannot identify.
- `test-environment.md` section 6's pub-cache row gains the suspected trigger for its second
  occurrence: two worktrees running `pub get` against the same cache at the same time.

### G4 closed: #15 `@@` confirmed on a derived HTML base (2026-10-14)

- **#15 `@@` is 已确认 now**, so the M1 matrix column is green end to end (the other four rows landed with
  PR #37). The ruling asked for a derived source on 漫客栈; the intent is kept but the **base had to
  change**: `@@` is the *default* (CSS / jsoup) mode flag, and 漫客栈's four pages are JSON — a default rule
  on a JSON scope degrades to CSS and `_matchElements` reports `parseFailed`. Measured first (RUN 3a):
  the derived field is rejected (`Rejected rule: field=searchRule.kind … parseFailed`) and degrades to empty.
- The evidence therefore comes from **笔趣阁③ (collection C #63 — the HTML source G2b already proved
  four-stage)** with **one** field changed: `ruleSearch.kind` goes from `class.cat@text##分类：` to
  `@@class.cat@text##分类：` (selector and replacement untouched). It yields `kind=武侠` in the search
  sample while the other three stages keep G2b's counts and hashes exactly (toc 1310,
  content 3031 chars / `sha256=6578ef3efc456856`) — the derivation disturbs nothing else.
- The live-source census (319 sources use `@@`, 25 selectable, none of them runnable) stays as background
  evidence in `tool/spot_check/README.md` §4.


### G4: four of the five M1 rows confirmed, plus two new work orders (2026-10-14)

- **Matrix #16 / #17 / #18 / #19 are 已确认**, each with a per-row record (source, field, sample) in
  `tool/spot_check/README.md` section 4: the untouched 漫客栈 source carries `@put:`/`@get:`, `{{...}}`
  and the `{$...}` template, and a one-field derivation of QB女生 carries the *variable* form of
  `java.put`/`java.get` (the synchronous-HTTP form stays refused by ADR-0037 decision 5, and the tool
  counts the two apart). **#15 `@@` stays 待验证** - 319 sources use it, 25 are selectable, and every
  live candidate fails (dead site, WAF, search stage) - which the delivery recorded honestly instead
  of writing it down as passed. The reviewer ruled that #15 closes with a **derived** live run
  (precedent: b1, b1b, b2 and b5 all used one), so the phase exit is one derivation away.
- **The census is now part of the committed tool** (M1 grammar census, literal-URL census, the
  `(?<!\{)\{\$` fix for #19) and `@@` became position-aware, so the selectable count moves
  384 -> 409. The reviewer reproduced every figure with an independent replica of the filter
  (409; #15 319/25, #16 438/61, #17 348/16, #18 980/128, #19 193/23; #17 forms 339/9; 12
  literal-URL sources with the same field distribution) and re-ran both device probes
  (Windows 74 s, Android 136 s, `js_bridge` 24/24 each).
- **Two findings became work orders.** **b6**: `ruleBookInfo.init` is marked M0 but nothing reads it
  - the specification only has the field's phase, not its semantics, so b6 first writes that line
  (upstream `AnalyzeRule.SourceRule.init` -> `setContent`) and then applies it. **b7**: a bare
  `@js:` on a JSON item binds the item's JSON *text*, where upstream binds the object, so
  `result.comic_id` is `undefined`; b7 starts with a census and any contract change needs an ADR,
  because section 6 documents the current binding.
- **The literal-URL finding is closed as parity, not a gap**: upstream also reads such a field as a
  rule and jsoup throws `SelectorParseException`, so the explicit `parseFailed` here only says the
  same thing in a locatable form.
- **Docs repaired in the same round**: the G4 status note was inserted in the middle of the matrix
  table in `book-source.md` (it split the table in two) and now trails the table with the other
  notes; a duplicate ledger row about the `--list` criterion - which still said "waiting for a
  ruling" while the row below it was closed - is gone; and `test-environment.md` section 6 gains the
  half-downloaded pub-cache trap (an empty `jni-1.1.0` directory once made the Windows build report
  `jNullReference`).

### G4: flip the M1 matrix rows #16-#19, block #15, census two findings (2026-10-14)

- **#16 `@put:` / `@get:`, #17 `java.put` / `java.get` (variable form), #18 `{{…}}` and #19 `{$…}` are
  已确认 now**, each with a real-source record in `tool/spot_check/README.md` §4: 漫客栈 (collection C
  #1229, not a character changed) covers #16 / #18 / #19 — `complete`, content 458 chars
  `sha256=30cc59e176f7ac3c`; ●QB女生<kd♛ with **only** `ruleSearch.bookUrl` rewritten (the original puts a
  rule head inside a URL, which §4 refuses) covers #17 — `java.put('time', …)` (variable form) is read back
  by `java.get('time')` in the printed `lastChapter`.
- **#15 `@@` stays 待验证**: 319 sources use it, 25 are selectable, and probing all 25 left none runnable
  (22 dead / WAF / search-stage failures, the last 3 fail in the search stage too). Reported as blocked
  rather than written as a pass.
- **The harness now produces the numbers.** `--list` gained the M1-grammar census (#15 319/25 · #16 438/61 ·
  #17 348/16 · #18 980/128 · #19 193/23, plus #17's 339 variable-form vs 9 HTTP-only split) and the
  literal-URL census (12 sources + field distribution). #19 counts with `(?<!\{)\{\$` instead of a
  substring, and the `@@` criterion is position-aware (a branch / template-start `@@` is the matrix #15
  flag, only a mid-rule one is refused), which lifts the selectable set from 384 to **409**.
- **Two findings registered in `PLAN.md` §3.7** (both surfaced while gathering #17's evidence, neither fixed
  here): `ruleBookInfo.init` is **never applied** although §2 lists it as M0 (fields are read against the page
  scope, so real sources with `init: "$.data.bookInfo"` read empty), and a bare `@js:` on a JSON item scope
  hands the script the JSON **text** as `result` where upstream hands the object (`result.x` is `undefined`).
- **The literal-URL question is answered**: 12 real sources write a rule field as a bare URL, and upstream
  reads those as rules too (`mode` stays Default → `temp.select(beforeRule)`, and jsoup 1.16.2 throws
  `SelectorParseException`) — so it is not an “upstream returns the literal” fidelity gap.


### Device probes back to per-slice, and three registrations (2026-10-13)

- **ADR-0039 supersedes ADR-0038: device probes are a slice-level requirement again.** The only
  reason for the phase-exit cadence was cost - Android cost 30+ minutes per run - and that premise
  is gone: the rewritten `run_android.ps1` (#34) brings a full three-file run to **163 seconds**
  including the emulator's cold boot (measured from this side; Windows is 108 s), so both platforms
  per slice costs about four minutes. Leaving a phase still needs the full both-platform run
  (`PLAN.md` section 4's G7), and an Android run blocked by the *environment* must be recorded as
  "blocked, not covered" and back-filled by the reviewer - never written down as passed.
  `testing.md` section 1 and `test-environment.md` section 1 now say both ends.
- **Registered: a rule field holding a fully literal URL** (`bookUrl: https://a.test/book/1`, no
  rule head and no `{{...}}`) is read as a rule, degrades to CSS through ADR-0032, and fails. The
  b5 regression hit it while deriving a source, so the row asks for evidence first: a census of
  real sources with a committed tool (section 6's trap 13) plus a check of what upstream does with
  such a field.
- **Withdrawn: the interim "dev book source switch".** The user ruled it out - the real fix is
  Phase 5's 5.1 book source entry, and a temporary second source of sources is not worth it.
- **`test-environment.md` section 6 gains the trap this round hit:** after an Android run the
  worktree holds Gradle paths under `build/integration_test/.transforms/...` that
  `git worktree remove` cannot delete (`Filename too long`); mirror an empty directory over it
  (`robocopy /MIR`) and `rmdir` the rest.

### b5: the two real-source gaps (`{{…}}` with `##`, JSONPath `]name`) (2026-10-13)

`RuleEngine` only; the M1 #15-#19 status column is flipped by the separate G4 change.

- **A `##` inside a `{{…}}` template no longer splits the rule.** `_replacementIndex` finds the
  first `##` **outside** any template (reusing `_templateEnd` for brace / quote counting), so
  `{{$.tag_views##\s+##,}}` keeps its `##` as the inner rule's replacement (matrix #9) while
  `{{…}}##/##-` still splits where it should. An unclosed `{{…` reports no split and stays with the
  parser, as before.
- **Legado's `]member` JSONPath shorthand is normalized to `].member`** before the RFC 9535 parser
  sees it, so `$.data.page[*]image` (漫客栈's real `contentRule.content`) and `$.a[0]b` read. Only an
  identifier start (letter / `_` / non-ASCII) is joined and quoted members are skipped, so `].`,
  `][`, a trailing `]`, `]` + whitespace and `$['a]']b` are untouched.
- 11 unit tests; **9 of them fail on the old engine** (the other two pin “leave it alone”
  boundaries). Exactly one new line needed a test for the coverage gate (the unclosed-`{{` branch),
  and it is covered.
- Real sources (`tool/spot_check/README.md` §4): the derived 漫客栈 source is **complete** for the
  first time (content 458 chars, `sha256=30cc59e176f7ac3c`) — `java.getStringList("$.data.page[*]image")`
  finally succeeds on a real source; the derived QB女生 source's search `kind` reads
  `仙侠,古典仙侠,草根崛起 已完结` where b1b had 18/18 `parseFailed`. The spot-check tool's search sample
  now prints `kind=` as well.
- Gates: 692 tests, `core` 943/943, `domain` 1740/1740, format / analyze / build_runner /
  generated-file diff clean. Windows device probe 108 s, `js_bridge` 24/24 (Android belongs to the
  Phase 4 exit, ADR-0038).


### Android probe harness: no snapshots, kill on failure, clean up (2026-10-13)

`tool/test/{common,run_android}.ps1` only — no `lib/` change. Documented in
`docs/dev/test-environment.md` §3 / §5 / §6 (PR #34).

- **Root cause of “Android takes half an hour”:** `adb emu kill` returns immediately while the
  emulator keeps writing its snapshot for ~15-20 s. Exiting inside that window tears
  `snapshots/<avd>/default_boot`, and the AVD's `fastboot.forceFastBoot=yes` makes every later run
  load it — “loaded successfully, guest wedged, adbd `offline` forever”, i.e. the full 300 s boot
  timeout, a left-behind emulator, and the same poisoning on the next run.
- **Never load a snapshot** (`-no-snapshot-load`). Writing it cannot be prevented on this emulator
  build (`-no-snapshot-save` and `quickbootChoice.ini`'s `saveOnExit = false` are both ignored —
  `ram.img` is written anyway), so the guarantee is “never read one”, plus a cleanup of this run's
  snapshot once the emulator process has really exited.
- **Kill the emulator in `finally` even when the boot failed.** The old condition required `$serial`,
  which is only assigned after a *successful* boot, so the timeout path was the one path that left
  an `offline` zombie holding the AVD lock and port 5554.
- `-TestFile <name>` (one build+install instead of three — Flutter builds per test file),
  `-WipeData` (genuinely fresh guest), emulator logs rotated to `.prev` instead of truncated
  (tolerating a still-locked file), and an explicit `exit` because `pwsh -File` printed the error and
  then stayed alive after a failed run.
- **Parameter surface is backwards compatible:** `run_all.ps1`, `-SkipDeviceTests` / `-SkipWindows` /
  `-SkipAndroid`, `-Headless`, `-KeepEmulator`, `-AvdName`, `-BootTimeoutSeconds` behave as before
  (`-Headless` no longer needs snapshot handling because snapshots are never read).
- Measured (2026-10-13, `Medium_Phone`): full three-file run **2 m 8 s** warm, 3 m 18 s on a fresh
  worktree (was 30+ min); a single file ~70 s; the Windows device probe 1 m 39 s.

### b1b review, merge and the device-probe cadence (2026-10-13)

- **Merged: the b1b rework.** The five must-fix items are in (`getElement` answers one value on both
  paths, an unmatched `getString` answers `''` on both, `java.post` is refused by name,
  `base64Encode` / `base64Decode` refuse the multi-argument overloads, and `book-source.md` §6 /
  `PLAN.md` really say what the CHANGELOG used to claim). Verified from this side: Windows device
  probe re-run (`app_boot` 1/1, `js_bridge` **24/24**, `on_disk_database` 1/1), gates green,
  `gen-l10n` and `build_runner` in sync.
- **Fixed by the reviewer: the third path-consistency defect.** On a **JSON** scope the literal fast
  path ran `_selectAllValues`, which stringified every match: `java.getStringList('$.data.page[*].image')`
  inlined `["a.jpg","7"]` where the asynchronous path (and `book-source.md` §6, "a JSON match its
  value") hands `7` as a number. `_selectAllValues` now returns the values untouched, and two tests
  pin the types (list and single-doc forms).
- **`tool/spot_check --list` census: the `{{...}}` half was fixed, the numbers recomputed to
  384/278/142.** The old "a rule starting with `{` is a form object" filter also caught `{{...}}`,
  contradicting both its own comment and `PLAN.md` §3.7. The reviewer reproduced both censuses from
  the same `build/ao.json` with an independent replica of the filter (353/253/122 before,
  384/278/142 after), so the change is accepted; the search-URL half stays conservative.
- **ADR-0038: device probes move to the phase exit.** A slice-level requirement to run
  `integration_test/` on **both** Windows and Android did not pay for itself — the Android side is
  30+ minutes per run and exercises the same Dart code and the same `flutter_qjs_next` engine, while
  the differences live in platform channels and native SQLite. Slices now need Windows; leaving a
  phase needs both, which is `PLAN.md` §4's new **G7**. `integration_test/` / `core/platform/` /
  native-project changes stay the exception and must run on the platform they touch.
- **New work order b5: two real-source gaps** that the b1b regression found and that are unrelated
  to `java.*` — a `##` **inside** a `{{...}}` template is still read as the replacement separator
  (`{{$.tag_views##\s+##,}}` fails the field), and the JSONPath dialect `]` followed directly by a
  member name (`$.data.page[*]image`) is refused by the RFC 9535 parser. Both reproduced by the
  reviewer; `PLAN.md` §3.5 has the work order, §3.7 the trigger conditions.

### b1b: the mainstream spelling on a real source, the `{{…}}` census fix, the last review nits (2026-10-13)

The review's leftover acceptance item and three small items, plus a tool bug the acceptance exposed.

- **The requested real-source regression is in, and it exposed the acceptance's blind spot:** every
  b1b fast-path test used an `@js:` segment; none used the corpus' actual spelling
  `{{java.timeFormat(java.getString('$.x')*1000)}}`, which is a **`{{…}}` template**. A unit test for
  that exact form is added (host inlines the literal inside the template; `java.timeFormat` stays a
  synchronous worker call).
- **The live record is a derived one, as `b1` and `b2`'s were.** Of the 58 sources whose
  `ruleToc.updateTime` uses the mainstream spelling, probing every site left none runnable (TLS
  handshake failures, a WAF 403, POST-form searches, `<js>` wrappers — table in
  `tool/spot_check/README.md` §4). The 漫客栈 source (collection C #1229, a real export) with **only**
  `ruleToc.updateTime` rewritten to the mainstream spelling produced
  `Chapter.updateTime = 2018/10/25 17:05` through the real chain (`$.change_time` is `"0"` on that
  site, so the same chapter object's real `start_time` is read instead — the derivation says why).
  That closes b1's remaining half.
- **Two real-source gaps surfaced; they are registered in `PLAN.md` §3.7, not fixed here** (both
  predate b1b and are orthogonal to `java.*`): a `##` inside a `{{…}}` template is taken for the
  rule's replacement split (`{{$.tag_views##\s+##,}}` → `parseFailed`), and `]` followed directly by a
  member name (`$.data.page[*]image`) is a Legado JSONPath form the RFC 9535 parser refuses. They are
  why the live 腾讯-search sources and this derived source's `content` stage stop early.
- **`tool/spot_check --list` was still excluding `{{…}}`.** The criterion had claimed to allow `{{}}`
  since the M1 grammar slice, but the old “a rule starting with `{` is a POST object” check also
  caught `{{`. It now rejects only a **single** brace, so the collection C census reads
  **384 / 278 / 142** (was 353 / 253 / 122); record and re-run command in `tool/spot_check/README.md`
  §3, ledger row corrected in `PLAN.md` §3.7.
- **The remaining review nits:** `book-source.md` §6's `java.*` status column really is flipped to
  ✅ 已落地 now (the previous entry claimed that prematurely); `Packages.*` — Rhino's other interop
  entry, `Packages.java.lang.…` — is a named rejection and the device probe asserts it; `__hostCall`'s
  body sits on its own line; and `_selectAllValues`' doc comment lost its stray blank line.
- **Gates:** `dart format` / `flutter analyze` clean; **674** tests; coverage exit 0 (`core` 944/944,
  `domain` 1708/1708, both 100%); `build_runner` 0 real changes; generated-file diff empty. Device
  probe: Windows `js_bridge` **24/24** (the 3 new `java.*` probes included). **Android was not re-run
  this round** — a full run takes over half an hour and the operator scoped this round to Windows — so
  `test-environment.md` §7 records it as **not covered**, with the re-run command, rather than as a
  pass. The numbers above are the branch's own (base `a319f52`, no b4a/b4b yet): the merge review is
  still the architect's.

### b1b review fixes: one shape per call on both paths, wider refusals, ledger and docs (2026-10-13)

The review found the two evaluation paths disagreeing, three refusals missing, and stale docs.

- **`getElement` is a single value on both paths now.** The literal fast path inlines the first
  match's `outerHtml` (or JSON value) and the asynchronous binding resolves to the first element of
  `parse.getElements` (`list.length ? list[0] : null`), so the same call no longer answers a value in
  one path and an array in the other.
- **`getString` with no match answers `''` on both paths.** The fast path used to inline `null`,
  while the asynchronous path (`parse.getString`) answers an empty string; the empty string wins
  because that is what the binding's documented shape is (`book-source.md` §6).
- **`java.post` is a named rejection again** (it had been missing, so it fell through to
  `undefined is not a function`), and `base64Encode` / `base64Decode` now refuse their multi-argument
  overloads instead of silently ignoring the extra argument (ADR-0037 §决策 2). `get` / `put` stay the
  **variable** functions of §6 — upstream's synchronous HTTP verbs of those spellings are covered by
  the `ajax` family — and that reading is now written into **ADR-0037 §决策 5** and `book-source.md`
  §11 instead of living in a code comment.
- **Docs:** the b1b real-source work got its own `PLAN.md` §3.7 row (this entry replaces the earlier
  claim that it was done); `book-source.md` §6's `java.*` status column is flipped in the follow-up
  entry, not in this one — it still read `M1-b1b` when this was written.
- **One flaky coverage test hardened** (`request_limiter`'s default-delay case): its 1 ms window
  could straddle a millisecond boundary and skip the real `Future.delayed`, which is how `core` lost
  a line. It now uses a 50 ms window and three calls, so the default delay is always exercised.

### Phase 4 b1b: the `java.*` compatibility surface (2026-10-13)

Implements ADR-0037: real sources use upstream's names (540 of 3907 sources use `java.*`;
`md5Encode` 1221 calls, `getString` 603).

- **Aliases (worker-side, synchronous, upstream semantics):** `java.md5Encode` (hex MD5),
  `java.base64Encode` / `base64Decode` (no-wrap base64; invalid input throws), `java.encodeURI` and
  `java.log`. `encodeURI` is Java's `URLEncoder.encode` — the new pure `javaEncodeUri`, **not** the JS
  builtin of the same name (space -> `+`, different reserved set), because mapping it onto the builtin
  would silently produce different signed URLs; multi-argument overloads are refused by name.
- **Rule-evaluation family (`getString` / `getStringList` / `getElement` / `getElements`), two forms,
  one implementation point.** The **synchronous fast path** runs on the host *before* the job is
  built: `RuleEngine` scans the script for calls whose first argument is a **string literal**,
  evaluates each rule against the current scope and inlines the result as JSON. That is what keeps the
  395 real calls sitting *inside expressions* working
  (`java.timeFormat(java.getString('$.x')*1000)`), where a Promise would be a type error. A literal
  whose inner rule itself needs the sandbox (`@js:`, `{{...}}`, `@put:`, `@get:`, `<js>`) is skipped
  for the **asynchronous** path, which answers through the same host evaluation as `parse.*` (so
  `js:parse-scope` and `js:parse-recursion` keep their meanings); a failed literal fails the whole
  rule rather than continuing with half a script.
- **`Array.prototype.toArray()` shim** (returns `this`) for upstream's Java `List` habit (38 calls),
  plus **named rejection stubs** for the M2 families (`ajax` / `webView*` / `toast` / key crypto /
  `base64DecodeToByteArray` / `setContent` / ...) and a throwing proxy for the Rhino interop names
  (`java.lang`, `java.security`, ...). `get` / `put` deliberately stay the **variable** functions of
  `book-source.md` §6 (ADR-0034), so upstream's synchronous HTTP verbs of those spellings are covered
  by the `ajax` family instead.
- Tests: the pure encoder (form semantics, `%` encoded again, UTF-8 bytes), the call envelope, the
  fast path (inlined in an expression, list form, non-literal left alone, sandbox-needing literal
  skipped, failed literal failing the rule in both forms), and three device probes (the alias
  surface, a rejected member failing readably, and the fast path plus `.toArray()` in a real engine).
  Coverage exit 0 (`core` 944/944, `domain` 1709/1709).
- Docs: `PLAN.md` §3.5 marks b1b done; `book-source.md` §6/§11 were already written by ADR-0037's own
  docs commit. **Still open:** the real-source record for the `getString`-based `updateTime`
  mainstream spelling.

### Phase 4 b4b: the discover page UI (2026-10-13)

- **`ExplorePage` + `ExploreNotifier`** (`presentation/`): a horizontally scrolling row of
  `ChoiceChip`s, then the books of the chosen category as `ListTile`s that open the existing book
  detail route. The state machine tells apart the five screens the layers below can produce —
  loading, "this source has no discover page" (empty), "`exploreUrl` is unreadable", "no category
  opened yet", and "this category failed" — because they are all *successful* answers from the
  engine. A failed category keeps the chip row visible so another one can be picked
  (`book-source.md` §9), and it offers a retry.
- **`BookSourceRoute.explore()`** carries the new page, and the search page's app bar gained a
  tooltip-labelled entry to it (disabled without a selected source, like the search action itself,
  C-UI-7). Five ARB keys were added in both locales: `bookSourceExploreTitle`,
  `bookSourceExploreAction`, `bookSourceExplorePrompt`, `bookSourceExploreEmpty` and
  `bookSourceExploreEmptyCategory`; `flutter gen-l10n` output is committed and matches the ARB
  files.
- Widget tests: no source; a source without categories (empty state); opening a category and
  listing its books through the offline corpus (`ruleExplore` absent → the whole `searchRule`
  fallback, ADR-0035 §决策 2); a category whose every hit lacks a usable book URL (its own empty
  state); and a failing category that keeps the row and shows the failure with a retry. Gates:
  `core` 919/919, `domain` 1660/1660, 666 cases.
- **Two review fixes before the merge.** A category with no usable books used to show the *search*
  empty state, which mentions a keyword this screen never has — it now has its own key and a test
  that asserts the search text is absent; and the unreachable `ExploreCategories()` arm of the
  `_below` switch (already handled above it) is gone.
- **The assigned `tool/spot_check` item was settled, not implemented: the “`{…}` in non-search
  URL fields” criterion stays as it is.** Its original premise — such URL rules could not be
  replayed before matrix #19 — was overtaken by #19 landing in 3.7, so tightening it now would
  filter out *runnable* sources and invalidate the 353/253/122 numbers ADR-0032 and
  `tool/spot_check/README.md` quote, while loosening the search-URL half would admit sources that
  still cannot be replayed. The criterion and the numbers therefore stand, the reasoning is written
  into `tool/spot_check/README.md` §3/§6, and `PLAN.md` §3.7 is closed.

### Stable coverage gate, a withdrawn finding and the b1b review (2026-10-13)

The coverage gate could fail on any PR for a reason unrelated to that PR, and one registered
finding turned out to be a measurement mistake. Both are settled before the next merge:

- **Fixed: the coverage gate flaked.** `lib/core/network/request_limiter.dart` had a private
  `_wait` (a one-line wrapper over `Future.delayed`) that only ran when the rate gate really
  waited, while the only test covering it used a **1 ms** window — so when ≥1 ms passed between the
  two `run` calls the second one had nothing to wait for, the line stayed unexecuted and `core`
  dropped to 943/944 (exit code 1). Three consecutive runs reproduced it (100% / 99.89% / 100%).
  The wrapper is gone: the limiter's default is now `Future.delayed`'s tear-off, so the file has no
  “only executed while waiting” line left; the test's window moved to 20 ms and its comment says
  why coverage no longer depends on it. Five consecutive runs are stable at `core` 919/919.
- **Withdrawn: the `.gitattributes` / CRLF finding from the 2026-10-13 evidence refresh.** The
  row claimed three files were committed with CRLF; the reproduction command returns the opposite
  (`git cat-file blob <ref>:PLAN.md | od -An -tx1` has no `0d` byte at four commits, and
  `git ls-files --eol` reports `i/lf w/lf` for every managed text file). The original check
  (`git show <ref>:<file> | grep -c $'\r'`) reports CR on **every** line on this host — it was the
  check that was wrong. The only CRLF that exists is in the four files the development group's
  editor created in a worktree, which `git add` normalises to LF anyway. `PLAN.md` §3.7 records
  the corrected state; the earlier entry above is left as history.
- **Registered: the b1b delivery was reviewed and returned for rework.** `PLAN.md` §3.5 marks the
  slice as returned and §3.7 carries the must-fix list with file:line — the fast path and the
  asynchronous path disagree for `getElement` and for an unmatched `getString`, `java.post` is not
  refused by name, `base64Encode` / `base64Decode` accept the multi-argument overloads the ADR
  refuses, the CHANGELOG claimed a `PLAN.md` update that was not in the commit, and the real-source
  regression plus the two device probes are still open. Nothing from that branch was merged.

### Troubleshooting row for the per-worktree native-asset cache (2026-10-13)

Docs only, one row in `test-environment.md` §6: every fresh `git worktree` has its own
`.dart_tool/hooks_runner/shared/sqlite3/`, so a new worktree has to download the precompiled
SQLite library again — and on a network blip `flutter test` / `flutter run` fail with
`By default, this package downloads a pre-compiled SQLite library` plus a `SocketException`.
The row records the worked-around fix (copy the cached directory from a worktree that already
ran) and that changing `pubspec.yaml` or adding a local sqlite3 is the wrong reaction. This is
the same download that blocked the Android device probe twice.

### Evidence refresh and two registrations after b3 + b4a (2026-10-13)

Docs only.

- `docs/dev/test-environment.md` §7 now records the latest run: **661 cases**, `core` 920/920 and
  `domain` 1660/1660 on the host, and `js_bridge` **21/21** on **both** Windows and Android — the
  Android run was the acceptance item b4a's delivery had left blocked by the network, now closed.
- `PLAN.md` §3.7 gained two rows found while reviewing b3/b4a: the `page` a **fetched page's field
  rules** see in JavaScript is `PageFetchService.fetch`'s default `1` (both the search and the
  explore callers omit it, while upstream does not bind `page` for field rules at all, so neither
  side is “the other one”), and `.gitattributes` claims `* text=auto eol=lf` while the committed
  blobs of `PLAN.md` / `CHANGELOG.md` / `docs/dev/book-source.md` carry CRLF — the integration kept
  the existing line endings so no whole-file rewrite appeared, and the two ways to settle it (or
  the rule to keep the current endings until then) are written down.

### Phase 4 b4a: the discover-page engine and `ExploreBooks` (2026-10-13)

- **`exploreUrl`'s two forms are in `domain/explore_categories.dart`** (pure) and
  `domain/usecases/fetch_explore_categories.dart` (the script form): a separated `标题::URL` string
  split on runs of `&&` or newlines, or **one whole-field script** (`@js:` / `<js>…</js>`,
  case-insensitive) whose result may be a JSON array or the very same separated string.
  `BookSource.exploreUrl` keeps the declaration as raw text; a source without one answers an
  **empty list** rather than a failure.
- **The whole-field script runs through the new `RuleEngine.evaluateJs`**, which returns the
  sandbox's **raw** value: the array form has to survive as a value, and going through
  `extractFirst` would split it into one value per element (matrix #8). The job carries the field's
  documented bindings (ADR-0035 §决策 4): `baseUrl` is the book source URL, `page` is 1, `result`
  is null, no `key` is bound and there is no `parse.*` page scope. Rejected entries (blank title,
  missing URL, no `::`, form categories) are logged with the field path and a reason and skipped,
  so the rest of the page still opens (C-SRC-4); a `<js>` without `</js>` fails the field with
  `exploreUrl:js-not-closed` and runs nothing (registered difference ①), and a script that fails or
  returns neither shape fails the field as `parseFailed` (registered difference ④).
- **`ExploreBooks` reads one category page** with the whole-rule fallback ADR-0035 §决策 2 asks
  for: `ruleExplore` when it declares a `bookList`, otherwise the **entire** `searchRule`, with the
  bookkeeping field prefix (`exploreRule.` / `searchRule.`) following the winner. The category URL
  goes through the shared URL rendering and is resolved against the book source URL (§4), so
  `/list/{{page}}.html` — the normal spelling — works, and a rule head inside it is refused by name
  (`unsupported:@@`). One call reads one page and never walks pages itself.
- **The nine list fields gained one reader** (`BookListFields` + `readBooks`): `SearchRule` and
  `ExploreRule` carry the same shape by upstream's `BookListRule` interface (`book-source.md` §2),
  so the search stage now uses the same reader instead of its own copy and the two cannot drift.
  A relative `searchUrl` is resolved the same way a category URL is — a latent gap the same §4 rule
  closes.
- Tests: the parsers' shapes (both separators, a single `&` inside a URL, every rejection reason,
  JSON array / JSON object / broken JSON, all four form category types), the categories use case
  (no declaration, string form, array result, string result, wrong-typed result, both JS wrappers
  with case-insensitivity, the unclosed wrapper, a failing script, the job's bindings, the logged
  rejection), and the books use case (explore rule, both fallback shapes, "only the winner is used",
  a `{{page}}` template, a rule head in the URL, an item without a URL, a rejected list rule, a
  failing category page). Coverage exit 0 (`core` 920/920, `domain` 1657/1657).
- Docs: `book-source.md` §4.2 implementation note, including the two specification gaps this slice
  had to decide (an absent `exploreUrl`, and resolving relative category URLs) — both registered in
  `PLAN.md` §3.7; `PLAN.md` §3.1/§3.5/§3.7; `tool/coverage_allowlist.txt` (the new freezed entity).
  The discover-page **real-source** record waits for b1b, as assigned.

- **Architect integration (2026-10-13):** this slice and b3 were both branched from `22371de` (b2),
  which predates the ADR-0037 documentation merge, so they were squashed onto the current `main`
  in review order (b3 first) and the two conflicts resolved by hand — `CHANGELOG.md` (both entries
  kept) and `PLAN.md` (§3.5's status row and step table). The generated `book_source.freezed.dart`
  was regenerated from the merged model instead of being hand-merged, which is what the
  generated-files gate then verified. Re-run on the integrated tree: 661 cases, `core` 920/920,
  `domain` 1660/1660, Windows `js_bridge` 21/21, all exit 0.

### Phase 4 b3: `canReName` and `variableComment` are modelled (2026-10-13)

- **`BookInfoRule.canReName` keeps the raw rule text**, because upstream never evaluates it:
  `BookInfo.kt:65` only asks whether the field is non-blank and then lets a caller switch decide
  whether a book's name and author may be overwritten (`WebBook.kt:235-238`, `book-source.md` §2).
  `FetchBookInfo` turns that into `BookInfo.canReName` through the pure
  `declaresCanReName(BookInfoRule?)`, so the consumer — the bookshelf that actually renames a
  book — can arrive with Phase 5 without the engine ever reading the rule.
- **`BookSource.variableComment` is modelled as display-only text**: nothing in the engine reads
  it (upstream only concatenates it into its validation output, `BookSource.kt:245-252`), and it
  now round-trips instead of landing in `extra`.
- Tests: the model round-trip for both fields (including `ruleBookInfo.canReName` staying in the
  modelled keys and `variableComment` no longer being an extra), a blank `canReName` still being
  kept verbatim as the author wrote it, the entity default, the pure predicate's four shapes, and
  one wiring case per outcome (declared → `true`, not declared → `false`). Coverage exit 0
  (`core` 920/920, `domain` 1506/1506).
- Docs: `book-source.md` §2 implementation notes; `PLAN.md` §3.5. The consumer of `canReName` was
  already registered as Phase 5 work in §3.7, so no ledger row moved here.

### ADR-0037: the `java.*` compatibility surface, and the b1b work order (2026-10-13)

Docs only. The real corpus showed that the b1 regression's remaining half was not blocked by the network but
by a missing binding family, so the architect measured the whole corpus and ruled on it before b1b starts.

- **The evidence (collection C, 3907 sources, `tool/spot_check/README.md` §3):** 540 sources use `java.*`
  (`md5Encode` 1221, `put` 1070, `get` 1048, `ajax` 866, **`getString` 603**, `base64DecodeToByteArray` 328,
  `timeFormat` 297, `log` 250, `encodeURI` 138, `getElements` 84, `base64Encode` 84, `base64Decode` 71,
  `setContent` 62, `getElement` 45, `getStringList` 36, plus keyed crypto, Rhino interop and UI members).
  Of the rule-evaluating calls — `getString` / `getStringList` / `getElement` / `getElements` — **395 are used
  inside an expression** (needing a synchronous value; 379 of them with a string-literal rule) and 372 stand
  alone (a Promise would do). Only **2** of the literal calls have an inner rule that needs the sandbox or the
  variables (`@js:` / `{{` / `@put:` / `@get:`), 38 are followed by a Java `List.toArray()`, none use a
  template literal, and none appear in a URL rule.
- **ADR-0037 (new, Accepted) turns `java` into a compatibility surface** (`book-source.md` §6 owns the shapes,
  §11 owns the refusals):
  - **Alias family** (worker-side, synchronous, no quota): `md5Encode` → `crypto.md5`, `base64Encode` /
    `base64Decode` → `crypto.*` (upstream's flags = 2 is `Base64.NO_WRAP`), `encodeURI` → a new pure helper
    matching **Java `URLEncoder.encode(…, "UTF-8")`** (space → `+`; deliberately *not* JS `encodeURI`), and
    `log` → `log.info`.
  - **Rule-evaluating family, two shapes over one implementation point:** a **literal fast path** — the engine
    evaluates `java.getString('rule')`-style calls *before* the script reaches the worker and inlines the
    JSON-encoded result, which keeps the nested idiom `java.timeFormat(java.getString('$.x')*1000)`
    synchronous (377 of 379 literal nested calls) — and an **async fallback** bound to the current scope
    (`parse.getString(rule, currentScope)`), which works when the script returns the promise and fails loudly
    inside an expression. The timing difference is unobservable because a script cannot mutate the scope
    (`setContent` is M2).
  - **List results are JS `Array`s**, with `Array.prototype.toArray()` installed in the sandbox so the 38
    upstream `List.toArray()` uses keep working; the shim adds no capability.
  - **Everything else is refused by name** with throwing stubs (and throwing Proxies for the Rhino interop
    namespace): sync-body HTTP (`ajax` / `get` / `post` / `connect` — a shape conflict with our promise
    `http.*`), the platform/UI members, `setContent`, the byte-array and keyed-crypto members, and the
    multi-argument overloads (`base64Encode(str, flags)`, `base64Decode(str, charset)`, the `unescape` form).
- **A second finding, registered rather than fixed:** upstream's value rules unescape HTML entities by default
  (`AnalyzeRule.kt:297-308`, `:362-366`, `StringEscapeUtils.unescapeHtml4`), which this repository never did.
  The practical gap is narrow — the HTML parser already decodes text and attribute values, so only `html` /
  `all`-style raw extractions differ — and it is registered in `book-source.md` §3 and `PLAN.md` §3.7 with its
  trigger condition.
- **Files:** new `docs/dev/adr/0037-java-binding-compat-surface.md`; `book-source.md` §3 (the entity note),
  §6 (the `java.*` compatibility table), §11 (the named refusals); `docs/README.md` §2.1 (ownership row); the
  ADR index; `PLAN.md` §3.5 (b1b's scope and acceptance) and §3.7 (the decision outcome plus the two new
  registrations).


### Phase 4 b2: `concurrentRate` as a second gate in the request budget (2026-10-13)

- **The model keeps the declaration as text** (`BookSource.concurrentRate`), and the request layer
  owns its syntax and its warning, because that is where the budget is spent (`book-source.md` §8,
  ADR-0036 §决策 5). `HttpClient.applySourceRate(sourceId, declaration)` is the one new method on the
  request contract; the four use cases call it through `PageFetchService.applySourceRate(source)`
  before their first request. Keying it by source URL is what makes a `@js:` rule's `http.*` calls
  share the same gate without carrying the declaration (they only ever see the source URL, §6).
- **Both gates live in `RequestLimiter`**, and the order is fixed: a rate permit is taken
  **before** a concurrency slot (ADR-0036 §决策 3), so a request waiting on the window never holds
  one of the three slots.
- **The rate window is sliding** — the last `n` permits must all be older than the interval —
  which is the strict reading of “at most `n` in any `m` milliseconds”. Upstream instead resets a
  fixed window once it expires (`ConcurrentRateLimiter.kt:88-108`), letting a burst of `n` sit at
  the end of one window and another `n` at the start of the next; the difference is registered in
  §8. A declared rate is parsed with surrounding whitespace ignored, which is the one place this
  reader is more forgiving than upstream's `toInt()` on the raw substring.
- **An illegal declaration is ignored and reported** (`n <= 0`, `m <= 0`, non-integers), with one
  warning naming the source, the field, the reason and a 32-character excerpt of the text
  (ADR-0036 §决策 2). Re-applying the same declaration is a no-op on purpose: every use case hands
  it over again, and resetting the window there would re-open the gate mid-batch. `null`, blank and
  `"0"` mean “no rate gate” and `HttpPolicy` gains no default rate field (ADR-0036 §决策 6).
- **The corpus census and the unit verdict came out of the committed tool**: `tool/spot_check --list`
  now prints the `concurrentRate` distribution too (classified with the production parser, so what
  the tool calls illegal is what the request layer refuses). On collection C (3907 sources):
  **3 sources declare one**, all bare integers (`3000` / `2000` / `1000`), all legal. Reading them
  as milliseconds gives “1 request per 1–3 seconds”, which is sane; reading them as seconds would
  mean one request every 17–50 minutes, which nobody would write — so the millisecond unit holds
  and ADR-0036 §决策 8's re-adjudication trigger is **not** met.
- **The live regression is an A/B on one real source** (record in `tool/spot_check/README.md`):
  🎨 漫客栈 (comic.mkzhan.com) from collection C, derived by changing **only** `concurrentRate` —
  `"1500"` took **4.6 s** for the four-stage run, `"0"` took **0.6 s** with the same site and the
  same rules. That is the rate gate visible in a real chain, and it is why the regression needed a
  derived source: only 3 of 3907 sources declare a rate, and none of the three can run its own
  chain (one site is unreachable, two use URL forms this repository does not implement) — registered
  in `PLAN.md` §3.7.
- Tests: the parser's shapes (`n/m`, bare `x`, `"0"`, blank, non-integers, non-positive, whitespace),
  the rate gate with an injected clock and delay (room in the window, a full window, several callers
  serialized through it, an exception still spending its permit, re-applying a declaration, removing
  it, both gates active at once, and the real-time default without an injected delay), the client's
  warning paths including the excerpt, and one wiring case per page-fetching use case. Coverage exit
  0 (`core` 920/920, `domain` 1503/1503).
- Device probes: **Windows `js_bridge` 21/21** after this change. The **Android** run could not be
  made on this machine: `assembleDebug` downloads `libsqlite3.arm.android.so` from
  `github.com/.../releases/download/`, and that host times out here while `raw.githubusercontent.com`
  works (curl exit 28). It is unrelated to this slice — no dependency was added — and it was registered
  in `PLAN.md` §3.7 with the command to re-run once the network allows it.
- **Architect review (2026-10-13), verified and merged:** the Android probe ran once the network came
  back (`Medium_Phone`, three files, `js_bridge` **21/21**, exit 0), the six gates were re-run on the
  same tree (621 cases, `core` 920/920, `domain` 1503/1503), the corpus census was reproduced exactly
  (3/3907 declarations, `3000`/`2000`/`1000`, none illegal), and the A/B was reproduced independently
  (`1500` → **4.6 s**, `0` → **0.5 s**). Two things were added rather than changed: `book-source.md` §8
  now states that handing the declaration over is a **single funnel** whose omission is silent (a
  missed `PageFetchService.applySourceRate` merely leaves the source unlimited, so a new read-source
  operation must add the line and its wiring test), and that `HttpClient.applySourceRate` stays the
  **only** entry to the rate gate (its argument is the raw declaration; syntax and warning belong to
  the request layer). `PLAN.md` §3.5/§3.7 and `test-environment.md` §7 carry the outcomes.

### Phase 4 b1: the four `updateTime` fields and the `java.timeFormat` binding (2026-10-13)

The first slice of the M1 build order in `PLAN.md` §3.5.

- **`updateTime` is modelled in all four places** upstream declares it (`SearchRule`, `BookInfoRule`,
  `TocRule`, `ExploreRule`) and carried on the entities the rules fill (`Book`, `BookInfo`,
  `Chapter`). The value is the rule result **as the source spelled it**: a display string, never
  parsed as a date (`book-source.md` §2). The three use cases read it through the same `field()`
  path every other optional field uses, so a rejected or missing `updateTime` rule degrades to
  `null` with a warning instead of costing the stage (ADR-0026).
- **`ExploreRule` is modelled here** (the nine list fields `SearchRule` carries, plus `updateTime`),
  with `ruleExplore` mapped on `BookSource` and its unrecognised keys kept in `extra`. Upstream
  fixes that shape in its `BookListRule` interface, so the two objects have to grow together
  (ADR-0035 §决策 1). The `exploreUrl` forms, the classification parser and the fallback to
  `searchRule` stay in b4a.
- **`java.timeFormat(timestamp)`** is bound in the sandbox: milliseconds in (a number or a string
  that reads as one), `yyyy/MM/dd HH:mm` out, the device's local zone — upstream's
  `JsExtensions.kt:678` plus `AppConst.kt:40`. It is answered inside the worker, so it stays
  synchronous and does not spend §6's per-rule call quota. An argument that cannot be read as a
  timestamp (or is outside Dart's `DateTime` range) fails **that call**: the JSON envelope says
  `ok:false` and the prelude raises a JS `Error`, which surfaces as `js:error` rather than a wrong
  date. A fractional number is truncated towards zero, the way a Java `(long)` conversion of a JS
  number behaves.
- Tests: model round-trips for the four fields plus `ExploreRule`'s own `extra`, the entity field,
  one wiring case per use case, the pure formatter (`formatTimestamp`), the millisecond / numeric
  string / fractional / unusable inputs, and the call envelope. Coverage exit 0 (`core` 858/858,
  `domain` 1497/1497). Device probes: **Windows `js_bridge` 21/21**, including the two new ones
  (`java.timeFormat` returning the local rendering of a millisecond timestamp, and an unusable
  argument failing as `js:error`).
- **Two acceptance items were left open by the build environment** (no outbound network at the time):
  the **Android** device probe (its Gradle build downloads `sqlite3`'s precompiled native asset from
  GitHub and timed out) and the **≥1 real-source regression record** for `updateTime` /
  `java.timeFormat`. Both were registered in `PLAN.md` §3.7 with what has to happen to close them.
- **Architect review (2026-10-13), fixed on the branch, and both items closed or narrowed with
  evidence:**
  - **The Android probe ran** once the network came back: three files, `js_bridge` **21/21**, exit 0 on
    `Medium_Phone`; `test-environment.md` §7 now records the host-side (599 cases, `core` 858/858,
    `domain` 1497/1497), Windows and Android rows for this slice.
  - **The real-source record is a derived one** (`tool/spot_check/README.md` §4): with the live
    漫客栈 source and only `ruleToc.updateTime` rewritten to `@js:java.timeFormat(1700000000000)`,
    the chain returned `updateTime=2023/11/15 06:13` on `Chapter.updateTime` — the binding's value does
    reach the entity through the real path. The corpus' own idiom stays unproven, and that is the
    finding: of the **184** sources using `java.timeFormat`, the dominant form is
    `{{java.timeFormat(java.getString('$.x')*1000)}}`, which needs `java.getString` — not implemented.
  - **The census was under-counting.** `tool/spot_check`'s `--list` criteria still excluded `@put:`,
    `@get:` and `{{…}}`, all implemented since the M1 grammar slice, so the same collection reads
    **353 / 253 / 122** instead of 266 / 192 / 69 (record and re-run command in
    `tool/spot_check/README.md` §3). The tool now also prints each stage's `updateTime`, and its
    documented command was corrected: the entry point needs `flutter run -d <device> -t …`, not
    `dart run` (which fails to compile on `dart:ui`).
  - **The `java.*` gap is now a registered, counted finding.** 540 of 3907 sources use `java.*`:
    `md5Encode` 1221, `put` 1070, `get` 1048, `ajax` 866, **`getString` 603**, `base64DecodeToByteArray`
    328, `timeFormat` 297, `log` 250, `encodeURI` 138, `getElements` 84, `base64Encode` 84,
    `base64Decode` 71, `setContent` 62, `getElement` 45, `getStringList` 36, crypto variants, Rhino
    interop (`java.lang` 234) and UI members. This repository's whitelist uses its own names
    (`http.*` / `parse.*` / `log.*` / `crypto.*`), so the next slice (**b1b**, `PLAN.md` §3.5) needs
    **ADR-0037** to rule the family: alias the pure-computation members, implement the
    `java.getString` family as nested evaluation of the **current scope**, keep `ajax` / `get` / `post`
    un-aliased (shape conflict) and leave Rhino interop, UI members and keyed crypto to M2.
  - Smaller fixes: `applyJsJavaCall` narrows the key inside its switch instead of falling back to
    `''` (a broken decoder invariant must fail the call, not write to an empty key); the `ExploreRule`
    doc comment pointed at ADR-0035 §决策 3 instead of §决策 2; and `book-source.md` §6 now records the
    two input boundaries the implementation makes visible (fractions truncate towards zero, and
    `|ms| > 8.64e15` fails the call before `DateTime` would raise an un-catchable `RangeError`).

### M1 spec front-loading: the explore page and `concurrentRate` (2026-10-13)

Docs only. The remaining half of M1 needed three specs that did not exist yet (`exploreUrl`'s format and
fallback, `concurrentRate`'s syntax and how it composes with the concurrency budget, `java.timeFormat`'s
input and timezone), so the architect front-loaded them instead of letting the dev team guess
(`AGENTS.md` §2). No Dart changed; the six gates were re-run on an unchanged tree.

- **ADR-0035 (new, Accepted): the explore page.** `exploreUrl` recognises two mutually exclusive forms — a
  kind list (`&&` / newline separated, `title::url`) and a whole-field JS (`@js:` or `<js>…</js>`) — and
  `ruleExplore` falls back to the **whole** `ruleSearch` when it is missing or its `bookList` is blank
  (upstream `BookList.kt:83-87`; not a per-field fallback, and the accounting fields come from the winner
  wholesale). Four differences are registered: the `</js>` suffix requirement, a URL-less kind being
  rejected instead of upstream's "pass the whole field down as the URL" side effect, `page = 1` plus no
  `key` in the kinds script, and a failing script being a `parseFailed` instead of upstream's visible
  `ERROR:` kind. Form-type kinds (`type != url`), `infoMap`, `args`/temporary variables and the ranking
  modules are out of M1 and registered in `PLAN.md` §3.7.
- **ADR-0036 (new, Accepted): `concurrentRate`.** The upstream syntax is kept verbatim — `n/m` is n accesses
  per m **milliseconds** (upstream's own comment, `ConcurrentRateLimiter.kt:86`), a bare integer is one per
  x milliseconds, `"0"`/empty is unlimited — with one deliberate difference: a malformed declaration is
  ignored **with a warning** instead of being silently swallowed. The rate gate and the existing per-source
  concurrency gate both apply, in the fixed order **rate permit, then concurrency slot** (the reverse lets
  waiting requests hold all three slots); over-limit **queues**, and the single implementation point stays
  `RequestLimiter` inside `DioHttpClient`, so a rule's `http.*` inherits the same limit.
- **`book-source.md`**: §2 (the `ruleExplore` row, `updateTime` in four rule objects, the list-rule "same
  shape" constraint, `canReName`'s not-evaluated semantics, `variableComment`, and the upstream fields this
  repo does not model yet), new **§4.2** (the explore page, its single source of truth), §6
  (`java.timeFormat`'s input, format and timezone), §8 (`concurrentRate` syntax and composition), §9 (a
  failing explore page only costs that kind), §11 (the `<js>` exception boundary and the M2 rows the explore
  page needs).
- **Ownership and ledgers**: `docs/README.md` §2.1 gained the two new fact rows (explore page → §4.2 /
  ADR-0035; `concurrentRate` → §8 / ADR-0036); the ADR index gained 0035/0036; `constraints.md` C-SRC-4,
  C-SRC-5 and C-SRC-9 now carry the ADR backlinks, and **C-SRC-5's wording was corrected** — since the M1
  grammar slice the URL entry point is the engine's asynchronous `renderUrl`, with `renderUrlTemplate` as
  its synchronous part, which the old wording ("must go through `renderUrlTemplate`") no longer described.
- **`PLAN.md`**: §3.5 replaced the "what is left" prose with the **b0–b4 step table** (b0 done here; b1
  `updateTime` + `java.timeFormat`, b2 `concurrentRate`, b3 `canReName` / `variableComment`, b4a explore
  engine + use case, b4b explore UI) including each step's acceptance, its parallelism, and the note that
  b4a depends on b1; §3.7 gained eight registration rows (unmodelled upstream fields, `infoMap` / form kinds
  / ranking modules, the URL-less kind difference, `java.timeFormatUTC`, `canReName`'s consumer,
  `updateTime`'s UI, and the `spot_check` URL check that b4b must tighten).

### Phase 4 grammar first: the M1 rule syntaxes #15–#19 (2026-10-12)

The first half of `PLAN.md` Phase 4: the five M1 syntaxes, implemented the way upstream reads them
— substitute into the rule **text** first, then parse the result (`AnalyzeRule.SourceRule.init` /
`makeUpRule`, `AnalyzeRule.kt:666-760`). Matrix states stay 待验证: no real source exercises them yet
(`PLAN.md` §3.7).

- **#15 `@@`** is stripped from the front of a rule body, so `{{@@class.a@text}}` means “run a default
  rule here” — inside `{{…}}` the default is JavaScript, so a default rule has to say so. A `@@`
  in the middle still reports `unsupported:@@`, as upstream only accepts it at the front.
- **#16 `@put:{key:rule}` / `@get:{key}`** runs each value as a rule and writes it to the rules'
  variable store before the flag is removed; `@get:` is substituted, and a rule that carried a
  substitution is read the way upstream's `Mode.Regex` reads it: **the substituted text is the
  value** (that is what makes `地址/{{@get:{x}}}` work). Malformed `@put` bodies are ignored, like
  upstream's empty put map.
- **#17 `java.put` / `java.get`** are the same variables, seen from the sandbox. Per **ADR-0034**
  (the re-adjudication ADR-0030 §决策 5(a) asked for) the store lives on the **host**, keyed by book
  source URL; each job carries a **snapshot**, `java.*` answers synchronously out of it inside the
  worker, and the job reports its table back so the bridge can merge it. `java.put(key, null)` clears
  a variable, a missing one reads as `''`, and `java.*` does not spend §6's per-rule call quota.
- **#18 `{{…}}`** is JavaScript by default and a **rule** when the inner text starts with a rule head
  (`@`, `$.`, `$[`, `//`) — upstream's `isRule` split. In the search URL the same `{{…}}` goes to the
  sandbox through the new **asynchronous URL rendering** (`RuleEngine.renderUrl`), while `{{key}}` /
  `{{page}}` / `{{baseUrl}}` keep the M0 template semantics (the keyword is still form-encoded
  exactly once, and a URL made only of template variables never touches the sandbox). A rule head in
  a URL is refused by name, and a `key` binding — upstream's `AnalyzeUrl.evalJS` has one and the rule
  field context does not — is handed to URL scripts only.
- **#19 `{$jsonpath}`** is expanded inside a JSON rule: every balanced template is replaced by its
  path's value and the whole text is returned as **one** value, which is exactly the legacy
  `{$.data.name}` form when the rule is nothing but one template.
- Two registered boundaries: expansion stops at **8 levels** with a locatable `parseFailed` (a
  per-source variable can hold rule text, so a self-reference could otherwise expand forever), and an
  unclosed `{{` stays literal inside a rule body (upstream's `{{[\w\W]*?}}` does not match it either)
  but is a `parseFailed` in a **URL**, where a literal `{{…}}` must never reach the request layer.
- Tests: the engine gained 47 cases for the five syntaxes and their boundaries, the variable store a
  suite of its own, the bridge the merge of a reported table, `decodeJsJavaRequest`, and a new
  `page_fetch_service_test.dart` for paging rendering — **75 new cases in all** (504 → 579), plus the
  review's 4. Coverage exit 0 (`core` 829/829, `domain` 1478/1478, 583 cases in all).
  `integration_test/js_bridge_test.dart` gained **three** device probes (per-source variable isolation,
  the Java ↔ `@get:` round trip in both directions, and the `key` binding being present in a URL job but
  not in a field job), while its whitelist probe now also asserts the `java.*` entries — 16 → 19 cases.
- **Architect review (2026-10-13), fixed on the branch:** `book-source.md` §3's case-insensitivity rule
  was violated by the two new flags — the expansion step's pre-check compared case-sensitively, so
  `@PUT:` failed with `unsupported:@PUT:` and `@GET:` with `unsupported:nested-rule` instead of
  reading / writing the variable (upstream's `putPattern` / `getPattern` carry CASE_INSENSITIVE). Both
  checks are case-insensitive now, with tests for the plain and the `{{…}}`-nested form. The
  device-level probes were then run for real, on **Windows and Android** (`js_bridge` 19/19 on each,
  exit 0), which caught the second defect: `jsBridge_whenAScriptWritesAJavaVariable_keepsItPerSource` built its
  cross-job job by hand without the source **snapshot**, so its second `java.get` could only ever read
  an empty table; the probe now carries `JsVariableStore.snapshot` in the job the way the engine does
  and asserts the store merge as well. Also: the two copies of the reported-variable reader collapsed
  into one `decodeJsVariables`, a `Map<String, String>` literal that would have thrown on
  `java.put(key, null)` widened to `Map<String, String?>`, and two doc comments that had lost their
  line break repaired.
- Docs: `book-source.md` §3 (#15–#19 notes and their registered differences), §4 (URL template
  boundaries), §6 (the `java.*` / `key` rows, the store, the quota note), §7 (`parseFailed` triggers);
  `PLAN.md` §3.1/§3.5/§3.7; `docs/README.md` §2.1; `architecture.md` §1; **ADR-0034**.

### Phase 3 closure review: ADR corrections and one narrow ADR added (2026-10-12)

Architect review of 3.7 (`844944b`) and 3.9 (`c64f827` + the F1 fix `27d33ab`), gates re-run in a
detached worktree (503 tests, `core` 777/777, `domain` 1163/1163) with the device probes re-run
(`js_bridge` 16/16, `app_boot`). The matrix was checked row by row: all **19 M0 rows** are now
已确认, and G3's three conditions hold.

- **ADR-0033 (new, Accepted): the cache's failure absorption gets exactly one exemption.** 3.9's F1
  fix moved the catch into `CacheDaoCharsetCache` with four named types, but drift 2.35.2 does not
  export `ConnectionClosedException` (`communication.dart:47` completes in-flight requests with it
  when the isolate connection is cancelled — reachable here, and the symptom is already documented
  in `test-environment.md` §5), so it cannot be named in a `catch`. The ruling: that one method may
  add `on Exception` after the named catches, the port stays total, `Error` stays uncatchable, every
  absorbed failure is logged at debug, and the exemption carries a sunset clause (drop it once drift
  exports the type). C-ERR-2 links the ADR; `docs/README.md` §2.1 owns the row.
- **ADR-0028 §决策 5 corrected:** it still said arrays are returned as JSON text. The 3.7 regression
  and upstream (`AnalyzeByJSonPath.kt:83-87`, `:137`) show lists expand element-wise for value rules
  and become the item list for list rules, while maps keep the JSON-text form as a registered
  difference. The behaviour spec stays in `book-source.md` §3's #13 note.
- **ADR-0032's snapshot numbers qualified:** 197 / 137 came from the `--list` filter that still
  excluded `@js:`; the current snapshot is 266 M0-compatible / 192 degrading / 69 using value-rule
  `@js:`, whose single source is `tool/spot_check/README.md` §3.
- **The `@js:` fixture's restore command was wrong:**
  `sed 's/example-novel\.test/www.missevan.com/g'` turns `static.example-novel.test` into
  `static.www.missevan.com`; it now replaces the longer host first, so a re-run reaches the static
  host the `content` script names.

### 3.9 review fix: the charset cache absorbs its own failures (2026-10-12)

The review found one rule violation: `core/network/http_client.dart` used `on Exception` for the
charset cache's read and write, and C-ERR-2 (with ADR-0002's revision note) allows that clause in the
`presentation/` Notifiers alone — a boundary that must not be widened in place.

- **The catch moved down to `CacheDaoCharsetCache`**, the only class that knows the cache's failure
  surface, and names the exceptions: sqlite's `SqliteException` plus drift's `DriftRemoteException`,
  `DriftWrappedException` and `InvalidDataException`. `Error` stays uncaught (ADR-0022), and each
  absorbed failure is recorded at `debug` level with the URL digest and the error digest (C-ERR-3,
  C-SEC-4). `CharsetCache`'s contract is now documented as **total** — `read` answers `null`, `write`
  does nothing, neither throws — so the request path carries no exception boundary and never has to
  hear about drift. The adapter therefore takes the `AppLogger` the client used to log with.
- **The one exception that cannot be named is covered by a ruling, not by a workaround.** drift
  2.35.2 does not export `ConnectionClosedException` (`remote.dart` / `isolate.dart` export only
  `DriftRemoteException`), and letting it escape the adapter would turn a lost cache entry into a
  throwing page request (C-ERR-1). Under **ADR-0033** `_absorb` therefore carries a fifth clause,
  `on Exception`, pinned to that one method: `Error` stays uncaught, the failure is still logged, the
  port stays total — and the clause must be deleted as soon as drift exports the type. The test that
  exercises it uses a plain `Exception`, for the same reason the type cannot be named there.
- Tests: the adapter now has four cases (one per absorbed type) proving a failed read is a miss, a
  failed write completes, and both leave a `debug` line; the client keeps hit/miss and
  “no source id” cases, and one new case pins **where** the boundary is — a cache that breaks the
  total contract propagates instead of being swallowed by the client. 504 host cases, coverage exit 0
  (`core` 779/779, `domain` 1163/1163).
- Docs: `book-source.md` §5 (what the adapter absorbs and why the port is total), `PLAN.md` §3.7.


### Phase 3.9: the charset detection result is cached per source and URL (2026-10-12)

Phase 3 is closed: the sniffing step now runs once per `(书源, URL)` instead of once per response,
which is also `CacheDao`'s first production consumer.

- **`CharsetCache` is a port in `core/network/`** (`charset_cache.dart`) with a `CacheDao`-backed
  adapter: the key reuses the DAO's stable key (`cacheKeyFor`, `ruleField` fixed to `charset` and
  a fixed `page`, so the two stages that read one book page share an entry) and its expiry column —
  **no new column, no new table**. The TTL lives once, as `defaultCharsetCacheTtl` (a week: the label
  for a URL almost never changes, and the expiry exists so a site that fixes a wrong declaration can
  take effect).
- **Only the sniffed lane is cached, and a declaration always wins.** `decodeBody` gained
  `sniffedCharset` and `DecodedBody.isDetected`: a declared label is re-read from the response every
  time (a header plus a 2 KB meta scan cost nothing next to the detector), so a cached label can never
  move a page from one ADR-0031 lane to the other. The client *reads* the cache on every response and
  *writes* only when the label came from detection.
- **The cache is a bypass.** A read failure, a write failure or a page without a book source (the key
  starts with the source id) all mean "sniff again": the page still decodes, and the failure is a
  `debug` line, because C-ERR-1 does not allow a cache to fail a request.
- Tests: the decoder's `sniffedCharset` / `isDetected` contract (including "the cached label is used
  instead of sniffing" and "a declaration beats it"), the DAO-backed adapter (hit, miss, per-source
  and per-URL separation, expiry, overwrite), and the client's five cache paths. `httpClient` now
  needs a database, so the two provider tests that read that graph override the device-only executor
  with `NativeDatabase.memory()`. 499 host cases, coverage exit 0 (`core` 763/763, `domain` 1163/1163).
- Docs: `book-source.md` §5 (what is cached, where the key and the TTL live), `PLAN.md` §3.1/§3.4/§3.7,
  `architecture.md` §1.

### Phase 3.7: the real-source regression, the matrix M0 rows confirmed, and the two JSON gaps it found (2026-10-12)

G3 is met: the matrix's 19 M0 rows all read **已确认**, two sources replay offline end to end, and the
nine `ParseFailureKind`s all have trigger tests. The evidence is four live runs, recorded row by row in
`tool/spot_check/README.md` §4b.

- **A real `@js:` source is in the corpus at last.** `test/fixtures/book_sources/legado_js_rules_source.json`
  (猫耳FM, sanitized) plus two derived response pages (`test/fixtures/json/maoer_search.json` /
  `maoer_toc.json`, real captures with every readable string and host replaced, array lengths kept).
  On the live site the chain gives search 30 / bookInfo 1 / toc 34, and both per-item scripts
  (`$.id@js:'…'+result`, `$.sound_id@js:'…'+result`) produce the URLs — so matrix #14 has a real
  source behind it now, not just unit tests. The content stage fails there for a site-side reason:
  the sound endpoint answers an Aliyun WAF challenge page instead of JSON.
- **The regression found two matrix #13 fidelity gaps, both fixed against upstream.** A JSONPath that
  matches a **list** was treated as one item: upstream reads such a path as the element list in a list
  rule (`AnalyzeByJSonPath.kt:137`, `read<ArrayList<Any>>`) and expands it element by element in a value
  rule (`:83-87`, `for (o in obj) result.add(o.toString())`). Before the fix the live run returned one
  result with a null name; after it, 30. Maps still travel as JSON text — upstream's Java `toString`
  (`{a=1}`) is not reproducible, and the difference stays registered.
- **A second derived source covers the syntaxes the baseline never used.**
  `legado_g2b_syntax_rules_source.json` rewrites nine rules of the G2b source into equivalent spellings
  that exercise #3, #4, #6, #7, #10, #25, #26, #27 and #28, and reproduces the baseline's counts **and**
  content hash `6578ef3efc456856` on the same pages — the same technique the `@css:` derivation used
  for #12/#29. The per-row mapping is tabulated in `test/fixtures/book_sources/README.md`.
- **The spot-check harness runs again.** Since 3.4 wired the real `@js:` engine into the chain the tool
  had been uncompilable under `dart run` (it needs Flutter's `dart:ui`); it now documents and uses a
  device host (`SPOT_CHECK_ARGS=… flutter run -d windows -t tool/spot_check/spot_check.dart`, because
  `flutter run` does not forward argv). Its `--list` filter no longer treats `@js:` as a deferred flag:
  only **list rules** and **URL templates** exclude it. The recomputed snapshot is 266/3907
  M0-compatible, 192 of them relying on the unknown-type degradation, 69 using a value-rule `@js:` —
  the ADR-0032 figure (137/197) was that older snapshot, and the README says why it moved.
- **One evidence debt closed, three registered.** The element-scope `@js:` `result` shape was checked
  against the fork: upstream hands the script the jsoup `Node` (so `outerHtml()` / `text()` work),
  while this repository can only offer an HTML string — a rule that needs DOM methods now fails
  loudly with `js:error` instead of quietly getting something else, and no real source in 1096 with
  `@js:` writes that form. Registered instead: the multi-element form of `-` has no corpus sample
  (direction is pinned by unit tests), the list-rule `@js:` contract still has no sample to freeze it,
  and `--list` does not yet scan `{…}` inside non-search URL fields.
- Tests: 3 new engine cases for the JSON list/scalar shapes and one chain replay of the `@js:` corpus
  source (search 30 / toc 34, plus the per-item script arguments). 486 host cases, coverage exit 0
  (`core` 744/744, `domain` 1163/1163).
- Docs: `book-source.md` §3 (status column + the 3.7 evidence note, #13 and #14 notes), §3.7 of
  `PLAN.md`, the gate table (G3), `tool/spot_check/README.md` §2/§3/§4b/§5/§6,
  `test/fixtures/book_sources/README.md` and `test/fixtures/json/README.md`.

### Phase 3.4 part 3: the `http.*` / `parse.*` Promise bindings, the call quota and the scope boundaries (2026-10-12)

3.4 is complete: every binding of `book-source.md` §6 exists now, including the two a rule has to
`await`, and the per-rule quota ADR-0030 §决策 3 fixes.

- **`http.get(url, options)` / `http.post(url, options)` are Promises** (ADR-0029 §决策 3). Both go
  through `core/network/HttpClient` — C-NET-1 keeps one door to the network — so timeouts, retries,
  decoding and the plaintext policy are the page layer's; `HttpClient` therefore gained `post`, and
  `DioHttpClient` answers both verbs from one shared `_request` (policy, per-source budget, retry
  loop) so a later change cannot land on one verb only. The source's own `header` field is applied
  under the rule's own headers (C-NET-4), and the source URL keys the same §8 budget the page fetch
  spends. `options` only honours `headers` and (POST) `body`; anything else — `charset`, `timeout`,
  `retry`, `webView` — makes that call fail loudly instead of answering a different question.
- **`parse.getString(rule, doc)` / `parse.getElements(rule, doc)` are Promises**, and the engine
  evaluates them **on the host** (ADR-0029 §决策 5's page-level scope): the nested rule runs where the
  engine already is, so the worker never rebuilds a scope. `getString` answers the first value or
  `''`; `getElements` answers each DOM match as its `outerHtml` and each JSON match as its value
  (a sandbox without DOM handles cannot do better — registered, with the upstream idiom it closes).
  The two boundaries §6 registers are explicit and locatable: `js:parse-scope` (a `doc` that is not
  this job's page body, or a scope that is not a page) and `js:parse-recursion` (a value-shaped
  nested rule that needs `@js:` itself — the one worker is running the job that asked, so a nested
  evaluation could only wait on its own queue). An element-shaped nested `@js:` lands on the list
  rule's own boundary, `unsupported:@js:list`, exactly as a top-level `bookList` would.
- **The quota is real, and it counts `log.*`.** `QuickJsWorkerBridge` counts every binding call that
  crosses out of the worker (`log.*`, `http.*`, `parse.*`; `crypto.*` is answered inside it) against
  §6's 20-per-rule bound and fails the job with `js:quota`; later calls of that script are refused
  without spending anything.
- **Fatal versus catchable is a decision, not an accident.** An `http.*` transport failure only
  rejects that Promise (a rule may `catch` it and try a mirror; uncaught it still fails the job as
  `js:error`, which is `book-source.md` §7's own classification). The `parse.*` boundaries and the
  quota decide the whole job, and the decision is **recorded and delivered when the script stops**,
  not mid-script: the worker must not be handed to the next job while a script is still running (two
  evaluations on one runtime would share `globalThis` and the engine's job queue), and killing a
  worker that is actively executing native JS is what turned the first device run of the quota probe
  into a hang. The hard budget still kills a script that never stops.
- **The worker's message loop no longer awaits an evaluation.** A script parked on `await
  http.get(...)` has to let `hostResult` envelopes through, so `evaluate` runs unawaited and the two
  host bindings travel as a `JsHostCall` / `JsHostReply` round trip (both decoded by the same tested
  type in `core/js`); `__runRule` returns a **Promise** for an `await`-ing rule and settles it inside
  JavaScript, so a rejected promise can never escape as an unhandled rejection.
- **A bare `@js:` now sees the item it belongs to.** On an element scope (a per-item field such as
  `searchRule.name`) `result` is the element's `outerHtml` instead of an empty string, and a bare
  `@js:` in a multi-valued field gets the page body (a String) rather than a one-element list — both
  are what upstream's `getString` / `getStringList` hand over.
- Tests: 16 new host cases at the bridge (routing, header merge, budget key, malformed calls, the
  quota, the fatal/rejected split, stale replies), 13 in `js_bindings_test.dart` for the envelope and
  argument decoding, 13 engine cases for the `parse.*` evaluator and the `result` shapes, and 6 new
  device cases. 483 host cases, coverage exit 0 (`core` 744/744, `domain` 1157/1157); the Windows
  device suite is 16/16 for `js_bridge_test.dart` (plus the other two files, all green).
- Docs: `book-source.md` §6 (binding behaviour, quota counting point, every marker and boundary),
  §3's #14 note, §8 (what landed, and what the nesting taboo was about), `PLAN.md` §3.1/§3.4/§3.7,
  `architecture.md` §1, `test-environment.md` §7.

### Review follow-up: a `@js:` purification rule now sees the page it ran on (2026-10-12)

The 3.4 part 1–2 review found one silent wrong value, not a code defect in the API: `replaceRegex`'s
`@js:` path built its sandbox context as `JsPageContext(baseUrl: '')`, so a purification rule reading
`baseUrl` got an empty string — upstream evaluates it through `analyzeString(replaceRegex,
contentStr)`, which has a base URL.

- `applyReplaceRule` takes an optional `JsPageContext`, and `PageFetchService.replaceContent` now
  requires one; `FetchContent` builds it from the first fetched page and the source view, so the
  chapter URL and `source.name/url/group` reach the sandbox.
- The source view became one mapping instead of four hand-rolled ones: `BookSourceJsView.jsSourceInfo`
  (`name` / `url` / `group` only, `book-source.md` §6), used by all four use cases to fill the page
  context of the pages they fetch.
- A unit test pins the context that reaches the sandbox, so the silent empty-string case cannot come
  back.
- Gates: format clean, analyze clean, 438 tests, coverage exit 0 (core 567/567, domain 1120/1120).

### 3.4 part 2: `@js:` runs in the engine, with the sandbox bound to the page (2026-10-12)

The sandbox is now reachable from a rule. `RuleEngine` takes a `JsBridge` (the only door to
JavaScript, so `domain/` never imports the engine library), and a **terminal `@js:`** is evaluated
with upstream's semantics:

- **`@js:` swallows the rest of its rule**, like upstream's greedy `AppPattern.JS_PATTERN`
  (`@js:([\w\W]*)`), so a `&&` or `||` inside the script stays part of the script instead of being
  read as a connector — which is what real rule text needs.
- **`result` has the shape upstream gives it:** a String when the field is single-valued
  (`getString`) and the whole List when it is multi-valued (`getStringList`, e.g. `nextTocUrl`); a
  List returned by the script also stays a List, which is what §4.1's URL array needs. `##`
  replacements run **after** the script, matching upstream's per-`SourceRule` order.
- **The sandbox gets the page**: `RuleScope` now carries a `JsPageContext` (`baseUrl`, `page`,
  `source`), built by `PageFetchService.fetch` and inherited by every element scope the engine
  derives, so a `@js:` on a per-item field (`searchRule.name`) still sees the page it came from.
- **`replaceRegex` follows the same path**: a `@js:` purification rule runs on the joined chapter
  text, exactly as upstream's `analyzeString(replaceRegex, contentStr)` does.
- **Boundaries are explicit, not silent** (C-SRC-4): `@js:` on a **list** rule is
  `unsupportedRule` with `rulePath: unsupported:@js:list` — upstream's list path would need the
  "JS returns a list of elements" contract (`AnalyzeRule.kt:439`), which is not modelled yet — and
  `<js>…</js>` stays matrix #31's M2 rejection. Both are registered in `book-source.md` §6.
- Tests: 13 new cases (437 total) driven through `test/support/fake_js_bridge.dart`
  (`testing.md` §4 — no native engine in unit tests), plus a real-engine case in
  `integration_test/js_bridge_test.dart` that runs a `@js:` rule through `RuleEngine` and asserts
  the `result` / `baseUrl` / `page` / `source` bindings (10 device cases green on Windows).
- Docs: `book-source.md` §6 (what landed, what is still open) and §4.1 (`@js:` purification),
  `test-environment.md` §7.
- Gates: format clean, analyze clean, 437 tests, coverage exit 0 (core 567/567, domain 1111/1111).

### 3.4 part 1: the rule evaluation API is asynchronous (ADR-0029 §决策 1) (2026-10-12)

The first half of 3.4, kept as its own step so the mechanical change is reviewable without the JS
plumbing mixed in: `@js:` can appear on **any** field, and a JS rule has to cross into the worker
isolate, so the engine cannot stay synchronous.

- `RuleEngine.selectAll` / `extractAll` / `extractFirst` / `applyReplaceRule` now return
  `Future<ParseResult<…>>`; `PageFetchService.field` / `list` / `content` / `nextPageUrls` /
  `replaceContent` and the four use cases await them. **One evaluation path only** — the alternative
  (a second, async entry point for `@js:`) would duplicate §7's failure semantics, the connector
  handling, the scope rules and the ADR-0026 degradation (`PLAN.md` §6 trap #5).
- `applyReplaceRule` is included because upstream evaluates `replaceRegex` through the same rule
  call (`BookContent.kt:190-193`), so a `@js:` replacement belongs on one path too; part 2 wires it.
- **Breaking change for callers**, recorded here as ADR-0029 §后果 requires. No behaviour change:
  same values, same failures, same `rulePath`s. What lands in part 2 is the sandbox call itself.
- `rule_engine_test.dart` absorbed it in the helpers: the six unwrapping helpers take the
  **unawaited** engine call and await it themselves, so ~200 call sites only gained `await` and
  `async` rather than being restructured.
- Gates: format clean, analyze clean, 424 tests, coverage exit 0 (core 567/567, domain 1049/1049).

### 3.3 review fixes: the sandbox closes its holes, `log.*` gets a ceiling, cancellation stops lying (2026-10-12)

The architect independently re-ran the six host gates and the real-engine device probe (all green) and
passed 3.3 **conditionally**, with one rule violation and two smaller items. All three are fixed:

- **F1 (rule violation): the engine's own Web APIs were reachable from a rule.** §6 forbids timers,
  `console` and native bindings, but `getJavascriptRuntime` installs a `JsWebApis.core` set by
  default, so a probe on the Windows build found `setTimeout` / `setInterval` /
  `clearTimeout` / `clearInterval` / `queueMicrotask` / `console` / `atob` / `btoa` /
  `structuredClone` / `performance` all present — with three consequences: a timer left by one source
  fires during another source's job (active cross-source interference, worse than ADR-0030 §决策 4's
  registered passive `globalThis` sharing), a rule can rebind `globalThis.crypto` / `globalThis.log`
  and the tampering reaches the next job (`Object.freeze` freezes the object, not the property name),
  and `console.*` bypasses the `core/logging` facade (C-ERR-5, C-SEC-4).
  **Two-part fix:** the worker builds the runtime with `JsWebApis.none()` — the library's "installs
  nothing at all: no `console`, no timers, plain ECMAScript" — and every job now re-applies the
  sandbox prelude before its script, which deletes the forbidden names (belt and braces, and it also
  clears whatever a rule defined itself) and re-installs `log` / `crypto`. Re-parsing ~1.5 KB next to
  a 5 s budget is noise. The integration probe gained three cases: every forbidden name must be
  `undefined`, a job that does `delete globalThis.crypto; globalThis.log = null` must not affect the
  next one, and the hardened sandbox must still let the engine drain its own promise job queue
  (which 3.4's Promise bindings depend on).
- **F2: `log.*` now has a host-side ceiling.** The facade redacts patterns, not size, so
  `log.debug(result)` on a 200 KB page wrote 200 KB per chapter into the sink. §6 gained
  "one `log.*` message: 2000 characters", the bridge truncates with a visible marker, and a unit test
  pins the cut. Counting `log.*` calls towards the per-rule quota lands with the quota itself in 3.4
  (§6 and `PLAN.md` §3.7 say so).
- **F3: a cancellation no longer claims to be a script error.** Jobs dropped because the bridge was
  disposed carried `rulePath: '<field>:js:error'`, which §6 defines as "the script threw". They now
  carry the bare field path; §6's note spells it out, and §7's `cancelled` row (its owner is §7) gets
  the "bridge or scope released" trigger from the review.
- Gates after the fixes: `dart format` clean, `flutter analyze` clean, `flutter test --coverage` 424
  passed, `check_coverage.dart` exit 0 with `core` 567/567 and `domain` 1048/1048; Windows device
  suite 3/3 files green (now 9 JS cases, including a check that the hardened sandbox still drains
the engine's promise job queue — which 3.4's Promise bindings depend on).

### Phase 3.3: the `@js:` sandbox — bridge contract, resident worker, sync bindings (2026-10-12)

The freeze preconditions are met (G2b, 3.5, 3.8), so the `JsBridge` contract is now in place: one
asynchronous evaluation method with **no capacity parameters** (ADR-0030 §决策 2), a resident worker
with one reused runtime, and the two sync bindings ADR-0029 §决策 3 assigns to this phase.

- **New `core/js/`** (`architecture.md` §1): `JsBridge`, `JsJob` and `JsSourceInfo`. The job carries
  exactly §6's variables (`baseUrl`, `result`, `page`, `source.name/url/group`) plus the field path
  that failures and `log.*` need (C-SRC-8).
- **`QuickJsWorkerBridge` owns the policy ADR-0030 §决策 1/3 fixes.** One worker, created lazily on
  the first `@js:` rule and released with the provider scope; one reused runtime; **FIFO** queueing,
  so a caller over capacity waits instead of failing (C-SRC-9 forbids “busy”); the budget is counted
  from dispatch, not from queueing; and `Isolate.kill` is the fallback when the engine's own
  interrupt did not fire — the next job then rebuilds the worker.
- **`quickjs_worker.dart` is the native edge alone** (isolate, `getJavascriptRuntime(timeout:,
  memoryLimit:)`, the JS prelude), which is why it is on the coverage allowlist under ADR-0019's
  second category. The queue, the budgets and the rebuild policy live in
  `quickjs_worker_bridge.dart` and are unit-tested against a fake worker transport, so the gate
  keeps measuring them.
- **The sync bindings are real:** `crypto.md5` / `sha1` / `base64Encode` / `base64Decode` (pure Dart
  in `js_bindings.dart`, unit-tested with RFC vectors) and `log.debug/info/warn/error` (forwarded to
  `core/logging` with the field attached, as §6 asks). Every `sendMessage` payload is a JSON object,
  per `tool/spike/README.md` §4.
- **JS failures mark the field**: `<field>:js:timeout` / `<field>:js:error`, now spelled out in §6.
  A JS exception and an interrupted script both arrive as `isError` (probe 07), so the worker reports
  its elapsed time and the bridge classifies: only a run that used up the budget is a timeout.
- **The integration probe ADR-0029 §后果 requires exists**: `integration_test/js_bridge_test.dart`
  covers 6 cases on a real engine and a real worker — sandbox variables, an array result (the
  `nextTocUrl` shape), sync `crypto.*`, `log.*` forwarding, runaway → `js:timeout` **with the worker
  still usable**, and a JS throw → `js:error`. Windows device run: all 3 device-level files pass,
  exit 0.
- 18 new cases (423 total). **Not in this phase, and registered instead of dropped:** the Promise
  bindings `http.*` / `parse.*`, the `parse.*` page-scope boundary (`js:parse-scope`) and the ≤20
  calls-per-rule quota — §6's note lists them and `PLAN.md` §3.7 carries the handoff to 3.4.
- Docs: `architecture.md` §1, `book-source.md` §6 (what landed, the `rulePath` spelling, the `log.*`
  C-SEC-4 note that a rule must not log page text), `tech-stack.md` §2 and `pubspec.yaml` (`crypto`
  now also serves the sandbox), `test-environment.md` §4/§7, `PLAN.md` §3.1/§3.4/§3.7.
- Gates: `dart format` clean, `flutter analyze` clean, `flutter test --coverage` 423 passed,
  `check_coverage.dart` exit 0 with `core` 563/563 and `domain` 1048/1048; Windows device suite
  3/3 files green.

### R1 closed: `isVip` now matches upstream's `isTrue()` predicate, with the lines (2026-10-12)

The review left one debt: the **positive** side of `isVip` (`true` / `1` / `是` → VIP) had no upstream
`file:line` behind it, so it was either evidence or a registered difference. The fork's source settles
it — upstream reads the rule result through `String?.isTrue()` (`BookChapterList.kt:261-264` calls
`if (isVip.isTrue()) bookChapter.isVip = true`; the predicate is `StringExtensions.kt:75-80`):

```kotlin
fun String?.isTrue(nullIsTrue: Boolean = false): Boolean {
    if (this.isNullOrBlank() || this == "null") return nullIsTrue
    return !this.trim().matches("(?i)^(?:false|no|not|0|0.0)$".toRegex())
}
```

- **The implementation was narrower than upstream, so it is now upstream's predicate.** The previous
  compare only rejected `false` and `0`, which made `null`, `no`, `not` and `0.0` VIP — four wrong
  answers against a real source. `fetch_toc.dart` now ports the predicate literally.
- **Two upstream quirks are copied on purpose**, because "fixing" them would silently become a
  difference: the `'null'` compare happens **before** trimming (`' null '` is VIP upstream), and the
  pattern's `.` is unescaped (`0x0` matches too). Both are spelled out in `book-source.md` §4.1
  (still the single owner of the semantics) and in the doc comment.
- The `isVip` case table grew from 6 to 12 chapters so the negation list is pinned: `true` / `1` /
  `是` / `yes` are VIP; `false` / `FALSE` / `no` / `not` / `0` / `0.0` / the literal `null` / an empty
  value are not. `PLAN.md` §3.7's R1 row is closed.
- Gates: `dart format` unchanged, `flutter analyze` clean, `flutter test --coverage` 405 passed,
  `check_coverage.dart` exit 0 with `core` 385/385 and `domain` 1048/1048.

### Review of the 3.8 slice: three boundaries registered, no code findings (2026-10-12)

Architect review of `15339cf`, gates re-run in a detached worktree: format clean, `flutter analyze`
no issues, **405** tests, coverage exit 0 with `core` 385/385 and `domain` 1047/1047. The limiter
and its wiring passed review (the slot hand-over leaves the count unchanged, so the gap between
releasing and re-taking cannot admit an extra request; an action that throws still releases; the
retry loop spends a second slot only after the first came back). Three boundaries are registered
here instead of being rediscovered late:

- **The JS bridge will share the per-source budget (3.4).** A JS `http.*` call spends the same
  source budget as the page fetch, so the implementation must not start a same-source request from
  inside a call that already holds a slot — with a budget of 3 that would exhaust itself and queue
  forever. `book-source.md` §8 now states it.
- **One host can carry two budgets**: calls with a source context bucket by `sourceId`, calls
  without one bucket by URL host, and the two do not interact. §8 now says so.
- **Two Phase 5 items landed in `PLAN.md` §3.7**: the budget must be validated `> 0` once it becomes
  a user setting (the constructors only `assert`, which release builds strip, and a zero budget
  queues every request forever), and the autoDispose `httpClientProvider` makes the budget effective
  within one operation — the batch download must keep one budget for the whole batch.

No code change was needed for 3.8 itself. The integration also brought the 3.5-era review fixes
(B2/B3 and the R1 registry row) back on top of this branch, and refreshed
`docs/dev/test-environment.md` §7 to the 405 / 385 / 1047 run.

### Phase 3.8: one concurrency budget per book source, spent in the request layer (2026-10-12)

`book-source.md` §8's per-source concurrency cap is now enforced instead of being a value
nothing read. ADR-0030 §决策 2 puts the budget in the **request layer** and keeps it out of the
`JsBridge` contract, so it is spent at the one place every request passes through.

- **New `core/network/request_limiter.dart`**: a FIFO gate. `run(key, action)` takes one of the
  key's slots or waits until the oldest caller hands one over. A caller over the budget **waits**
  instead of failing — C-SRC-9 requires concurrent calls to be safe, so "busy" is not an
  acceptable answer — and the slot is released even when the action throws, so one broken request
  cannot shrink the budget for the rest of the session. The hand-over leaves the count unchanged,
  so the gap between releasing and re-taking cannot let an extra request through.
- **`DioHttpClient` spends it per wire attempt**, keyed by `sourceId` (the book source URL) and by
  the URL host when a call has no source context. The future batch chapter download (Phase 5) is
  therefore bounded as soon as it goes through `HttpClient` (C-NET-1), with no caller having to
  know about the budget; `FetchContent`'s own paging was already serial. A retry spends a second
  slot only after the first came back, which keeps the budget about requests on the wire.
- **`HttpPolicy.maxConcurrentRequestsPerSource`** is the knob: it defaults to
  `defaultMaxConcurrentRequestsPerSource` (3, owned by §8) and is overridable through the
  `httpPolicyProvider` seam the settings phase already uses. `concurrentRate` (M1) will read a
  source's own declaration into the same value.
- 10 new cases (405 total): the limiter's concurrency, queueing, FIFO order, per-key independence
  and release-on-throw; the client's per-source queueing plus the host fallback key, driven by a
  new `FakeHttpAdapter.onFetch` hook that holds requests open without any wall-clock wait; and the
  policy default, a custom value and the non-positive assert.
- Gates: `dart format` unchanged, `flutter analyze` clean, `flutter test --coverage` 405 passed,
  `check_coverage.dart` exit 0 with `core` 385/385 and `domain` 1047/1047.

### Review B1: the paging URL templates are rendered before they are requested (2026-10-12)

Review found that `nextTocUrl` / `nextContentUrl` only went through `resolveAbsoluteUrl`, never
through `renderUrlTemplate`. `book-source.md` §4 gives `{{page}}` to both fields at M0 and forbids
letting a literal `{{...}}` reach a request (C-SRC-5), so a template paging rule could not work.
Beyond that, the values the engine extracts are the **result** of a rule: `toc_{{page}}.html` is not
a selector at all, so the engine had nothing to read and paging stopped on the first page.

`PageFetchService.nextPageUrls` now owns it, in one place:

- a paging rule whose whole text is a URL template (at least one `{{...}}`, only the M0 variables
  `page` / `baseUrl`, no `@` segment) is rendered as the next address directly;
- any other rule is still evaluated by the engine, and **every extracted value** is rendered as a
  template before it is resolved — so a site whose `href` carries `{{baseUrl}}` works too;
- a value that renders to nothing is dropped, so §4's "never leave `{{...}}` in a request" holds;
- `{{page}}` is the 1-based number the URL becomes (`pages.length + 1` while reading the page's own
  next rule, i.e. the page after `{{baseUrl}}`), `{{baseUrl}}` is the page the rule was read on.
  `book-source.md` §4.1 owns both definitions;
- matrix #18's `{{...}}` inner rules stay M1: `{{result}}` names no M0 URL variable, so it is *not*
  treated as a template and the engine still rejects it as unsupported.
- 3 new cases (395 total): the `{{page}}` template chain, the `{{baseUrl}}` template inside an
  extracted `href`, and the `{{result}}` boundary. Each asserts that no requested URL contains `{{`.
- Gates after the fix: `dart format` unchanged, `flutter analyze` clean, `flutter test --coverage`
  395 passed, `check_coverage.dart` exit 0 with `core` 357/357 and `domain` 1047/1047. The
  latest-run evidence table `docs/dev/test-environment.md` §7 was still carrying 3.5's numbers
  (370 / 925), so it is updated here too — that table is the owner of the counts.

### Phase 3.5: late-bound toc paging, content paging, `isVip` and `replaceRegex` (2026-10-12)

The M0 fields `PLAN.md` §3.4 step 4 names are modelled and consumed. The field model gained
`TocRule.isVip` / `TocRule.nextTocUrl` / `ContentRule.nextContentUrl` / `ContentRule.replaceRegex`,
and `Chapter` gained `isVip`; the three rule objects therefore no longer carry those keys in
`extra`, and `book_source_test.dart`'s per-object expectations were updated with the model.

- **Paging is a list-driven walk, once, in `PageFetchService.walk`.** `nextTocUrl` and
  `nextContentUrl` are read with the engine's `extractAll` (upstream `getStringList`,
  `BookChapterList.kt:210-218`), because a rule may name one page or a group of them. Each value
  resolves against the page it was read on (C-SRC-5), the current page and repeats are dropped
  (upstream filters `redirectUrl`), a page is never read twice, and the walk stops at the §9 bound
  of 50 pages with a warning. `nextPageUrls` and `replaceContent` keep ADR-0026 §决策 2 where it
already lives: a rejected or malformed paging / replacement rule degrades to "no next page" /
  "no replacement" plus a warning whose `field=` is the source field, not the engine's
  `unsupported:<syntax>`.
- **A later page does not mean the same thing to both stages.** A missing table-of-contents page
  keeps the chapters already read and logs a warning (§9), while a chapter body that cannot be
  fully fetched fails the chapter: returning a truncated body as a success would dress a failure
  up as success. `book-source.md` §9 gained that row, and §4.1 gained the field-level semantics
  the old "returns empty, stop" wording left open.
- **`isVip`** is true-ish: `null`, `""`, case-insensitive `false` and `0` stay non-VIP, while
  `true`, `1` and any other non-empty value mark the chapter.
- **`replaceRegex`** is applied to the joined chapter text (pages joined with `\n`, upstream
  `appendContent`), through the new `RuleEngine.applyReplaceRule`: the standalone `##regex##replacement`
  form (upstream "used on its own it equals `all##…`") and matrix #25's `##regex##replacement###`.
  A body naming a selector is `parseFailed` at the field, a body carrying a flag such as `@js:` is
  `unsupportedRule` — neither is silently dropped. Upstream's surrounding per-line trim and
  full-width re-indent (`BookContent.kt:191-194`) is reader-side formatting and is deliberately
  not applied here; §4.1 records that difference.
- 22 new test cases (392 total, from 370): the field mapping, the replacement-rule engine group,
  toc paging (chain, array, self-reference, 50-page bound, later-page fetch failure, later page
  without a chapter list, rejected paging rule), `isVip` truthiness, content paging (join, strict
  later-page failure) and the replacement rule plus its degradation.
- Gates: `dart format` unchanged, `flutter analyze` clean, `flutter test --coverage` 392 passed,
  `check_coverage.dart` exit 0 with `core` 357/357 and `domain` 1030/1030.

### No HANDOVER.md: its content was folded into the owners it belonged to (2026-10-12)

A `HANDOVER.md` (session handover: snapshot, reading order, how to run, traps) was proposed on a
side branch. It is **not merged**, because by its own opening rule ("restating is a defect") it
restated four facts that already have owners, and it had already gone stale before it was reviewed:
its snapshot said the G2b slice was *not* in `main` while `main` had just received it. The decision
follows ADR-0013/ADR-0027 rather than adding an eighth root-level entry document.

- **The traps moved to their owner, `PLAN.md` §6** ("常见返工陷阱，本项目已实际踩过"): rows 11–17
  record the measured ones — ADR numbering collisions between parallel writers, running the
  sanitized fixtures against the live site without restoring the host, deriving a statistic with a
  throwaway script, treating a live page's hash as a regression baseline, writing a
  `throwsFormatException` case for the sniffing lane (its reachable labels are tolerant codecs or
  `Error`-raising families), leaving temporary Dart files where `dart format .` / `flutter analyze`
  see them, and writing temp files to `/tmp` on Windows. Row 7 already covered "new source file
  without a test", so it was not duplicated.
- **The gate counts went to their owner, `docs/dev/test-environment.md` §7** (370 cases, `core`
  357/357, `domain` 925/925) — the single place the latest-run evidence is stated.
- **Nothing else needed a new home**: the reading order is `AGENTS.md` §2 plus `docs/README.md`
  §2.1, the commands are `tool/spot_check/README.md` §2/§3 and `docs/dev/test-environment.md` §3,
  and the phase snapshot is `PLAN.md` §3.1 with the process record in this file.
- **One stale comment fixed in `tool/spot_check/spot_check.dart`**: it still called the void
  "157 of 270" figure reproducible; it now points at ADR-0032 for the number instead of restating it.

### The upstream evidence debt (review R1) is closed with file:line (2026-10-12)

- **ADR-0032's `else -> doc.select(rule)` claim now cites lines**, which review R1 had to leave open
  because the reviewer's machine routes DNS through a fake-IP range that its SSRF guard blocks. The
  dev team fetched the fork's raw source directly (`HapeLee/legado-with-MD3@master`, checked
  2026-10-12) and found the branch in
  `app/src/main/java/io/legado/app/model/analyzeRule/AnalyzeByJSoup.kt:313-320`: a `when (rules[0])`
  dispatching `children` / `class` / `tag` / `id` / `text` whose **`else` (line 320) is
  `temp.select(beforeRule)`** — the whole segment goes to jsoup's CSS engine, exactly what the ADR
  rules. The same block corroborates this repository's matrix #2 (`class` →
  `getElementsByClass(rules[1])`, line 316) and #3 (`text` →
  `getElementsContainingOwnText(rules[1])`, line 319).
- **Matrix #31's `<js>` evidence is now traceable too**: `…/constant/AppPattern.kt:5-6` defines one
  `JS_PATTERN = Regex("<js>([\\w\\W]*?)</js>|@js:([\\w\\W]*)", IGNORE_CASE)` covering both
  wrappers, and `…/analyzeRule/AnalyzeUrl.kt:157`, `:168`, `:171` show `analyzeJs()` using it on
  URL rules — so the "any position / usable as a separator" claim is backed by code, not only by
  the fork's prose documentation.

### Review follow-up: the spot-check evidence is committed and the statistic re-derived (2026-10-12)

- **R4 closed: the two G2b sources are in the repository.** `test/fixtures/book_sources/` gained
  `legado_g2b_default_rules_source.json` (the baseline source, real rules verbatim) and
  `legado_g2b_css_rules_source.json` (the same source with 16 rules re-spelled as `@css:`), both
  sanitized per ADR-0023 §决策 2 — neutral name, hosts → `example-novel.test` — with the original
  host, the full derivation table and a two-command re-run recipe recorded in that directory's
  README. With the host restored, the committed fixtures reproduced the recorded evidence
  verbatim: identical stage counts and `sha256=6578ef3efc456856` for both spellings.
- **The corpus statistic behind ADR-0032 was re-derived, and the numbers recorded there were
  wrong.** The harness's own `--list` — the auditable implementation, which also rejects
  `sourceRegex` and inspects every `@`-segment — reports **197 of 3907** sources as M0-compatible,
  of which **137 (69.5%)** need the unknown-type degradation. The earlier 157/270 (58.1%) came from
  a throwaway script with a looser filter, and “9 of the 13 live candidates failed in the search
  stage” is in fact 10. ADR-0032 §背景/§后果/§备选方案, `book-source.md` §3 and
  `tool/spot_check/README.md` are corrected, and `--list` now marks each source `degraded` so the
  figure is one command plus the public collection instead of a number to trust.
- **O3**: the sniffed-lane case became a table of four malformed inputs asserting the **exact**
  detected label and zero replacements, replacing the `isNotEmpty` assertion. A
  `throwsFormatException` case for that lane is not constructible, and the measurement is recorded
  in the test: the detector's candidate table has no `utf-8`, its CJK labels are lenient codecs,
  and `shift-jis` / `euc-jp` raise a `RangeError` (an `Error`, registered in `PLAN.md` §3.7)
  rather than a `FormatException`.
- **O4**: `search_books_test.dart` now asserts that a search request carries the source's `header`
  map and the source id while still carrying the keyword.
- The `us-ascii` exclusion comment now points at `book-source.md` §5.1, which owns that policy,
  instead of at a decision item of ADR-0031.
- Gates after the follow-up: `dart format` unchanged, `flutter analyze` clean, `flutter test
  --coverage` 370 passed, `check_coverage.dart` exit 0 with `core` 357/357 and `domain` 925/925.

### Review of the G2b/ADR-0031/ADR-0032 commit: docs fixed, code items handed over (2026-10-12)

Architect review of the dev team's `4304a19`, run in a detached worktree with the gates re-run
green: format clean, `flutter analyze` no issues, 369 tests passed, coverage exit 0 with `core`
357/357 and `domain` 925/925. The code passed; the findings below were fixed here (documentation)
or handed back to the dev team (code and evidence).

- **Fixed here — `PLAN.md` carried a duplicated Phase 3 item 3** (the commit re-inserted the
  pre-edit copy of the spot-check paragraph, so §3.4 had two `3.` entries). A duplicated definition
  is what `docs/README.md` §6.1 forbids, and it was a rebase artefact.
- **Fixed here — `CHANGELOG.md` had a heading glued to the previous paragraph** (no blank line
  before the new `###` section), which broke the rendered markdown.
- **Fixed here — ADR-0032's status line claimed an "架构师裁决" that never happened** (the dev team
  wrote the ADR and marked it accepted). The ruling is now recorded honestly: the document is the
  dev team's draft, accepted by the architect on 2026-10-12 after review, and the ADR index says
  the same.
- **Fixed here — the `<js>` ledger gap (R1).** The commit rejected `<js>` by name while the matrix
  had no row for it: exactly the "the engine rejects it correctly, the ledger never recorded it"
  gap that §3's own #25–#27 note exists to prevent. `book-source.md` §3 gains **row #31**
  (`<js>…</js>`, M2 / not implemented, `unsupported:<js>`) appended at the tail per the ID rule, §11
  lists it, and the evidence is cited: the fork's syntax doc lists `<js></js>` as usable **anywhere**
  and as a rule separator (`tag.li<js></js>//a`), while upstream `AnalyzeUrl.kt`'s `analyzeJs()`
  ("执行 `@js`，`<js></js>`") matches both wrappers with one `JS_PATTERN`, so it applies to URL rules
  too. The `else -> doc.select(rule)` citation in ADR-0032 still lacks a `file:line`; that evidence
  debt is registered in the ADR.
- **Fixed here — ADR-0032 now records the two measured semantic losses (R2)** that previously lived
  only in test comments: a **misspelled implemented type** (`clas.odd`) degrades from a warned
  degradation into a **trace-free non-match** (loud only for top-level rules), and an extraction
  segment written into a list rule (`class.x&&class.x@href`) loses its `unsupportedRule` failure and
  becomes a silent empty contribution.
- **Fixed here — my own ADR-0031 background was wrong (R3).** It claimed every decodable family
  "has a tolerant entry"; that is true of the codecs but not of this repository's reachability. The
  measurement: `shift-jis` / `euc-jp` raise `RangeError` (an `Error`, which ADR-0022 forbids
  catching) before the tolerant path is reachable, `euc-kr` never fails, and `us-ascii` / `utf-16` /
  `utf-32` are deliberately excluded because a wrong declaration is not a stray byte. ADR-0031 now
  carries a correction note and points at `book-source.md` §5.1, which owns the split between
  "unreachable" and "deliberately excluded".
- **Handed to the dev team:** (1) commit the two spot-check sources (baseline and the derived
  `@css:` equivalent) so README §4's equal counts / equal `sha256` and the corpus statistic become
  reproducible — registered in `PLAN.md` §3.7; (2) add a direct test for the **sniffing lane failing
  strictly** (the current case only proves the tolerant path was not taken, and asserts with
  `isNotEmpty`); (3) assert `headers` / `sourceId` arrival for a second use case (search, which also
  carries `keyword`); (4) fix the test comment that cites the `us-ascii` exclusion to "ADR-0031
  §决策 4", which is about not degenerating into UTF-8 tolerance — that policy now lives in
  `book-source.md` §5.1.

### ADR-0031: tolerant decoding only on the declared-charset lane (2026-10-11)

- **A real site in the G2b spot-check declares UTF-8 but carries a few illegal bytes, and the old
  rule let one byte kill a whole detail page** (`book-source.md` §5: "decoding failure is
  `encodingFailed`"; C-NET-3's ban on `allowMalformed`). ADR-0031 splits the two situations that
  rule had merged: on the **declared** lane (HTTP `Content-Type` / `<meta charset>`) the encoding is
  authoritative, so decoding is now tolerant per the declared family (illegal bytes → U+FFFD) and
  succeeds **with one warning** carrying the source id, URL summary and field path (never the body,
  C-ERR-8 / C-SEC-4). On the **sniffed** lane and the unknown-label UTF-8 fallback the encoding is a
  guess, so a decoding failure stays `encodingFailed` — guessing plus tolerance would turn a wrong
  guess into mojibake reported as success (C-SRC-4).
- **Tolerant decoding must not degenerate into "UTF-8 with `allowMalformed`"**: it stays on the
  declared family, and the per-family entry points were verified to exist (`GbkCodec`,
  `EucJPCodec`, `EucKRCodec`, `ShiftJISCodec`, `CodePage.decode(..., allowInvalid: true)`,
  `utf8.decode(..., allowMalformed: true)`). A family without one keeps failing loudly and must be
  registered in §5.1 rather than pretended away. `book-source.md` §5.1's gaps (Big5) are unchanged,
  no `ParseFailureKind` is added (§7 still owns the nine), and the detection order is untouched.
- Written back to the single owners: `book-source.md` §5 (the lane rules, the U+FFFD/no-byte-loss
  requirement, one warning per page), `constraints.md` C-NET-3 (now links §5 instead of restating
  it), `docs/README.md` §2.1 (ownership row), `PLAN.md` §3.4 (the spot-check records the fact that a
  page carried illegal bytes). The ADR also hands over the C-DOC-1 item: `charset_decoder.dart`'s
  `///` says "must not hide it behind `allowMalformed`" and must be rewritten when the tolerant path
  lands.

### The G2b live-site spot-check, ADR-0032 and the ADR-0031 implementation (2026-10-12)

- **G2b is met**: a real published source (`笔趣阁③`, `https://www.biquge99.cc`, taken from the
  3907-entry public collection) ran the whole chain against the live site — search (2 hits),
  detail (「剑来」/ 烽火戏诸侯), table of contents (1310 chapters) and body (3031 characters,
  `sha256=6578ef3efc456856`) — driven by the **production** pipeline (use case →
  `renderUrlTemplate` → `HttpClient` → `RuleEngine`), with the source's own `header` field
  applied to every request. `tool/spot_check/` holds the harness and the record; it is a `tool/`
  entry point, never discovered by `flutter test` and never run in CI (`testing.md` §1 keeps the
  network out of tests).
- **Matrix #12 (`@css:`) now has evidence on real HTML**, not only on constructed fixtures: the
  same source with its default rules rewritten one-for-one into equivalent `@css:` selectors
  (including `:eq(0)`, matrix #29) produced the **same stage counts and the same body hash**.
  The derivation is recorded rather than presented as a published source, because of the two
  corpus sources that do use `@css:` one site is parked and the other is behind Cloudflare.
- **A defect in an M0 field was found and fixed**: `BookSource.headers` (the `header` field of
  `book-source.md` §2) never reached a request — `PageFetchService.fetch` did not pass it — so a
  source that declares a browser `User-Agent` or a `Referer` was fetched with the project agent
  and got blocked (`zwdu.com` answers 200 to a browser agent and drops the project one). The use
  cases now pass `source.headers`, `FakeHttpClient` records the request headers, and
  `fetch_content_test.dart` asserts that they arrive.
- **ADR-0032 (architect ruling on the spot-check evidence): an unknown default-rule type degrades
  to a raw CSS selector.** `.searchresult`, `li`, `dd`, `tr!0`, `#txt`, `div.item` were rejected
  before (as `parseFailed` / `unsupportedRule`), while upstream hands the segment to jsoup's
  `doc.select`. The measurement that decided it: **137 of the 197** M0-compatible sources in the
  collection (69.5%) use at least one such rule, and 10 of the 13 live candidates with real result
  links died in the search stage. `RuleEngine` now hands such a segment to cascadia, keeping the
  `!` / `[...]` position suffix out of the CSS (`tr!0` is not valid CSS), and `unsupportedRule` is
  reserved for the flags that really are unimplemented (`@xpath:` / bare `//` / `<js>` / `:regex`).
  The old expectations were rewritten, not deleted, and a new test group pins the degradation.
- **ADR-0031 is implemented** as the ruling specifies: a live book page declared `utf-8` and carried
  a single invalid byte at offset 130 893 of 131 368 — browsers and upstream render the other
  131 KB, this repository failed the whole `ruleBookInfo` stage. `decodeBody` now returns
  `DecodedBody` (`text`, `charset`, `malformedByteCount`); the declared lane retries tolerantly and
  `DioHttpClient` logs the one warning the ruling asks for — **declared charset, replacement count
  and book source id** (which is why `HttpClient.get` gained `sourceId`, closing an existing C-ERR-8
  gap, and why the four use cases pass `source.url`). The **sniffing / fallback lanes stay strict**,
  because there “the encoding was guessed wrong” and “the bytes are broken” cannot be told apart.
  Two of the supported families actually meet `book-source.md` §5's “U+FFFD, no dropped or shifted
  bytes” requirement — `utf-8` and `gbk` (both measured) — so only those are tolerant:
  `shift-jis` / `euc-jp` raise a `RangeError` (an `Error`, which ADR-0022 forbids catching) on the
  strict decode and `euc-kr` drops illegal bytes instead of failing. Both facts are registered in
  `book-source.md` §5.1 and `PLAN.md` §3.7.
- Documentation follows the single-source rule: `book-source.md` §3 gained the #1/#2 type note
  (ADR-0032) and §5.1 the per-family tolerance registration, §10 points at the spot-check entry
  point, `constraints.md` C-SRC-4 / C-NET-3 back-link the two rulings, `docs/README.md` §4 lists
  `tool/spot_check/`, the ADR index carries 0032, and `PLAN.md` §3.1 / §3.4 / §3.7 / §4 record
  G2b as met with the next step being 3.5. Gates: `dart format` unchanged, `flutter analyze` no
  issues, `flutter test --coverage` 369 passed, `check_coverage.dart` exit 0 with `core` and
  `domain` at 100%.

### 3.3's freeze precondition is pinned, and PLAN.md no longer contradicts itself (2026-10-11)

- **A real contradiction inside `PLAN.md` is fixed.** Its §3.1 status row said the next step was
  "spot-check → 3.3", while §3.4 — the single owner of the Phase 3 execution order — puts 3.5 and
  3.8 before 3.3/3.4. §3.1 now points at §3.4 instead of restating an order (ADR-0013 §3).
- **The reason is recorded where the gate lives:** `PLAN.md` §3.3 now states its freeze
  precondition explicitly — G2b spot-check and 3.5 / 3.8 come first, because 3.5's `nextTocUrl` /
  `nextContentUrl` may have JS return a **URL array** (`book-source.md` §4.1), so the "single value
  vs list" dimension of the bridge's return contract has to be exercised by a real field before the
  contract is frozen (user ruling, 2026-10-11).
- **ADR-0030 carries the matching note:** closing the *capacity* precondition does not mean the
  contract may be frozen now, and it does not change `PLAN.md` §3.4's order.

### ADR-0029 accepted, and ADR-0030 rules the JS engine capacity (2026-10-11)

- **ADR-0029 is accepted** (user-confirmed). Its consequences are written back where they belong:
  `docs/dev/book-source.md` §6 now owns the operative per-binding shape — synchronous `java.*` /
  `log.*` / `crypto.*` versus Promise-returning `http.*` / `parse.*` — plus the page-scope boundary
  of `parse.*` (`rulePath` `js:parse-scope`), and `docs/README.md` §2.1 gained the ownership rows.
  `PLAN.md` §3.3/§3.4 carry the resulting acceptance criteria; nothing else was restated.
- **ADR-0030 settles the capacity question ADR-0029 §后果 had left open: one resident worker, one
  reused runtime, FIFO queue — and the capacity is deliberately *not* part of the `JsBridge`
  contract.** The concurrency budget stays a request-layer policy (`PLAN.md` 3.8), so 3.8 cannot
  force a contract change. Evidence: the interrupt budget restarts per evaluation (spike probe 07:
  the same runtime answered `1 + 1` right after being interrupted), a pool's memory budget is
  `maxSize × memoryLimit` while the pool enforces no aggregate RSS budget, and the official
  `soft`-reset recipe (the multi-tenant-safe mode; `hard` costs ~19% throughput with no lower RSS)
  requires re-registering bridges on every lease.
- **A deviation from upstream is registered rather than glossed over:** in 3.3 every book source
  shares one `globalThis` (upstream runs one engine per source). Mitigation: the M1 `java.put` /
  `java.get` variables live in Dart keyed by `sourceId` inside the same isolate, never in
  `globalThis`; the reopen triggers (M1 variables, 3.7 corpus evidence of global-defining rules, or
  a measured queue bottleneck at 3.8) and the escalation path (source-keyed pool with `soft`
  reset — an implementation change, not a contract change; a per-source worker needs its own ADR)
  are recorded in ADR-0030 §决策 4/5.

### ADR-0029 (proposed): the `@js:` bridge shape and the async engine API (2026-10-11)

- **A ruling for 3.3's `@js:` architecture is drafted** as
  `docs/dev/adr/0029-js-bridge-shape-and-async-engine-api.md`, status **Proposed** (not in force
  until accepted). The dev team's option 1 is adopted — `RuleEngine.selectAll` / `extractAll` /
  `extractFirst` become `Future<ParseResult<…>>` — because C-SRC-2 forces at least one isolate
  hop for JS and `@js:` can appear in any field, so two parallel evaluation paths would give
  `book-source.md` §7 a second, drifting implementation. Option 2 (engine + runtime in one
  resident worker, engine stays synchronous) is rejected.
- **Two premises of the question were factually wrong, and that is why the ADR exists.**
  `flutter_qjs_next 1.5.2`'s channel bridge returns the Dart handler's value to JS
  synchronously (`quickjs_runtime2.dart`, `initChannelFunctions`), and the package's
  async-bridge recipe shows a `Future`-returning handler becoming a JS Promise. So sync/async is
  **per binding**, not engine-wide: `log.*` / `crypto.*` stay synchronous in option 1, and
  `http.*` / `parse.*` are Promises. `http.*` is a Promise in **both** options (Dart has no
  synchronous network API), so it cannot justify option 2's structural refactor.
- **The in-repo corpus carries no `@js:` evidence at all** (`test/fixtures/book_sources/*.json`
  contains 0 occurrences), so no API-frequency argument can be settled from it. The missing
  sample is registered in `PLAN.md` §3.7 and blocks matrix #14's "已确认" status.
- `docs/dev/book-source.md` §6 now warns that its "形态" column must not be read as a decided
  sync/async contract until ADR-0029 is accepted; `PLAN.md` §3.3/§3.4 gained the
  per-binding-shape and fake-`JsBridge` acceptance criteria, and §3.7 gained the
  "3.8 before the bridge contract is frozen" coupling.

### Documentation single-source fixes: coverage counts, gate thresholds, G2a wording (2026-10-11)

- **The run counts and per-layer coverage live in one place again.** The latest-run evidence
  (`353` cases, `core` 336/336, `domain` 881/881) is stated once in `docs/dev/test-environment.md` §7;
  its §1 row and `PLAN.md` §3.4 no longer restate a second, stale copy of the same count
  (ADR-0013 §3: restating one fact in two places is how the two copies drift apart).
- **`PLAN.md` stops restating the coverage thresholds.** The three places that spelled out
  `100%` (§3.1, §3.2 step 1.1, gate G1) now link to the single owner of the thresholds and of
  the "unmeasured source file" rule, `docs/dev/testing.md` §2 (C-TEST-1).
- **The two-source replay row is labelled with its actual gate.** `docs/dev/book-source.md` §10
  "链路测试" now says **G2a offline replay**, and records that the JSON source has 2 rewritten URL
  rules, so it cannot be mistaken for the real-site regression that owns the matrix "已确认"
  status column (ADR-0024, `PLAN.md` §3.4 step 3.7).

### Rule connectors, field degradation and JSON rules for the 3.2 slice (2026-10-11)

- **The three rule connectors are implemented** (matrix #10 `||`, #11 `&&`, #27 `%%`). `||`
  splits into candidates, of which the first that produces a value wins; `&&` merges the
  branches of one candidate as a **union in rule order** and `%%` interleaves them
  ("交叉取数"), both from the same scope. The splitter is quote-, bracket- and paren-aware, so
  a separator inside `[...]`, `(...)` or a quoted string does not split. Merging branches of
  **different** kinds is rejected instead of guessed: a JSON branch merged with a default or
  `@css:` branch is `parseFailed` at the field (`book-source.md` §3, the `&&` note), which is
  also what the previous slice's value-branch-in-a-list-rule case relies on.
- **A rejected or malformed optional field degrades to "no value" plus a warning**
  (ADR-0026 §决策 2/4, `PageFetchService.field`). Both `unsupportedRule` and `parseFailed`
  degrade, with `rulePath`, the failure kind and the book source id in the message; the
  top-level `list()` / `content()` rules still fail the stage (`book-source.md` §7). Degrading
  the malformed case matters because the callers read `dataOrNull`: escalating it would have
  produced a `null` with no record at all.
- **Matrix #13 (`@json:`, including the bare `$.` / `$[` form) is implemented** on a new
  `RuleScope` (ADR-0028). A branch reads either the DOM or JSON and **the rule decides**,
  which works because a whole page is a DOM scope that carries the raw body it was parsed
  from — one fetched page can serve a `bookList` of `$.data…` and a `content` of
  `class.content@text` at once. List rules return matches as scopes, so a JSON list
  (`bookList: "$.data.list[*]"`) hands each object to the field rules the same way an element
  does. A scope that cannot answer a branch is `parseFailed` with the field path — the syntax
  is supported, this page just cannot answer it — instead of a silent empty result
  (C-SRC-4).
- **`@json:` is recognised before the `@`-split, and the path is parsed while the rule is
  read.** A JSONPath filter carries an `@` of its own (`$[?(@.a==1 && @.b==2)]`), so splitting
  first would tear the path apart; parsing the path while reading the rule turns a malformed
  one into a locatable `parseFailed` with the field path rather than an unlocatable throw
  from the matcher (C-SRC-8), exactly as `@css:` already does for its selector.
- **JSON values → values:** a string is its own value, a number or boolean is written the way
  JSON writes it, `null` and an empty string produce **no value** (matrix #8's convention),
  and an object or array is returned as JSON text. Upstream's Java `toString` of a map
  (`{a=1}`) is not reproducible and no rule can rely on it, so the lossless form is used
  **until the real-corpus regression of `book-source.md` §10 says otherwise**.
- **3.6 (the nine `ParseFailureKind` values and where each is triggered) is accounted for:**
  `networkTimeout` and `cancelled` in `HttpClient`'s error mapping; `networkFailed` for a
  transport failure and for the statuses no closer bucket covers; `networkForbidden` (403) and
  `notFound` (404) by status; `encodingFailed` when charset detection or decoding fails;
  `parseFailed` for a top-level rule that matched nothing and for a rule that is structurally
  broken or cannot be answered by the scope; `unsupportedRule` for a syntax a later phase
  owns; `invalidBookSource` for an import that misses a required field and for a source whose
  `searchUrl` is absent. The retryable column of `book-source.md` §7 is implemented by
  `ParseFailureKind.isRetryable`, which `test/core/error/parse_result_test.dart` asserts for
  the transient and the permanent kinds, so the table and the code cannot drift.
- **A JSON-API replay corpus closes the second link of G3's two-source requirement.**
  `test/fixtures/json/` (three constructed response pages) plus the sanitized real export
  `test/fixtures/book_sources/legado_json_source.json` are driven end to end by
  `chain_givenJsonSourceAndCorpusPages_replaysEveryStage`, which exercises a nested path
  (`$.coverInfo.desc`), the first-non-empty `||` candidate, a relative cover URL, a JSON
  string's `\n`, and the four request URLs against the real query string. To find a source
  that could be replayed verbatim, 211 public sources were scanned: only **2** use `@json:`,
  and **0** of them replay under M0, because both build their book URLs with M1's
  `{$.x}` / `{{$.x}}` / `@put:` / `@get:` templates. The corpus therefore has exactly one
  registered deviation — `ruleSearch.bookUrl` and `ruleToc.chapterUrl` are rewritten to the
  equivalent pure JSONPath, with the originals kept in `test/fixtures/json/README.md`. The
  scan is also the evidence that **#16–#19 should be re-prioritised after 3.3**.
- **ADR-0028's decision records were corrected after review.** Decision 2 had justified
  moving the scope choice into branch evaluation with `$.a||class.b`; that reason is false
  and was removed — a measured `extractAll('$.a||class.b@text', DomScope(html))` returns
  `parseFailed`, because `||` stops at the first failing candidate (it never falls back to
  the DOM branch). The mixed-scope boundary is now pinned by
  `extractAll_givenMixedScopeOr_returnsParseFailed`, and decision 3 was narrowed to the real
  asymmetry: a JSON rule on a body-less DOM scope, or on a non-JSON body, is `parseFailed`,
  while a DOM rule on a JSON page is an **empty success** (`extractAll_givenADomRuleOnAJsonPage_returnsAnEmptySuccess`)
  rather than a failure. The suite is now **353** tests, `core` 336/336 and `domain` 881/881,
  with the six gate commands green.

### CSS selection for the 3.2 slice: the `@css:` flag and the jsoup index pseudos (2026-10-11)

- **Matrix #12 (`@css:`) is implemented.** The rest of the segment goes to cascadia
  unchanged (C-SRC-6), so standard CSS works — combinators, attribute selectors and the
  pseudo-classes cascadia has (`:contains`, `:containsOwn`, `:matches`, `:has`, `:not`,
  `:nth-child`, `:first-child`) — and a `@css:` segment mixes with default segments in either
  direction (`@css:ul > li@tag.a@href`, `class.result-list@css:li`). The flag is
  case-insensitive like every other flag. The selector is parsed while the rule is read,
  which is the only layer that can turn a bad selector into the right `ParseResult`: malformed
  CSS is `parseFailed` with the field path instead of an unlocatable throw from the matcher
  (C-SRC-8).
- **Matrix #29 (new row) implements jsoup's index pseudo-classes** `:eq` / `:gt` / `:lt`,
  which cascadia does not have. Their meaning is jsoup's **sibling index**: `:eq(0)` is the
  first child of *each* parent, not the first element of the result set (jsoup's own
  `SelectorTest.testPseudoEquals`, `div p:eq(0)` → two elements, is the reference). They are
  therefore rewritten onto cascadia's `:nth-child` — `:eq(1)` → `:nth-child(2)`, `:gt(1)` →
  `:nth-child(n+3)`, `:lt(3)` → `:nth-child(-n+3)` — rather than sliced after matching, so
  every match still happens inside cascadia (C-SRC-6). Negative arguments are refused by name
  (`unsupported::eq(-1)`): jsoup's public documentation defines these pseudo-classes as 0-based
  and says nothing about negatives, so the behaviour is not guessed. The row has in-repo
  evidence — the sanitized real export uses `:eq(1)` and `:eq(3)`.
- **Matrix #30 (new row, M2 / not implemented) names the nested rule in the extraction
  segment** (`class.a@css:.b`). It stays rejected, but under its own `rulePath`
  (`unsupported:nested-rule`), so it is no longer confusable with a middle-segment `@css:`,
  which this slice turned from rejected into usable. Registering it keeps the ledger honest
  instead of leaving a real upstream form unaccounted for.
- **The `&&` wording was a spec defect and is corrected.** Matrix row #11 and the
  `book-source.md` §3.2 order block said `&&` "chains levels"; the upstream rule
  documentation, in several independent mirrors, and a third-party implementation of the
  dialect all say `&&` **merges both sides** (union), `||` takes the first non-empty side and
  `%%` interleaves — and that the three connectors only join rules of the same kind, never
  `@js:` or regex rules. The upstream example
  `class.odd.0@tag.a.0@text&&tag.dd.0@tag.h1@text` is empty under the chaining reading, so the
  old wording could not have been right. The dated note next to the matrix carries the
  evidence; `||` / `&&` / `%%` are still to be implemented in this slice, and `PLAN.md` 3.2 now
  requires the grouping and the cross-kind rejection to have tests.
- Registered while implementing: state pseudo-classes (`:hover`, `:visited`, `:focus`) parse
  and then never match a static DOM — the correct answer for a snapshot, so it stays a success
  with an empty result rather than an `unsupportedRule` — plus two cascadia-vs-jsoup
  differences (`:containsOwn(a b)` needs quotes in cascadia; `:matches(x)` must be written
  `:matches(/x/)`). Both differences are loud failures (`parseFailed`), not silent ones.
- The "unsupported syntax" fixtures of the use case and page tests moved from `@css:` to
  `@js:`, which still belongs to a later phase. The suite is now **324** tests (was 310) and
  `dart run tool/check_coverage.dart` exits 0 with `core` 342/342 and `domain` 683/683, every
  file measured (ADR-0019). No new dependency: `cascadia` was already declared. The matrix
  status column stays 待验证 — only a real book source regression may change it
  (`book-source.md` §10), which is 3.7's job.

### Default rule syntaxes for the 3.1 slice (2026-10-11)

- The rule engine (`lib/features/book_source/domain/rule_engine/rule_engine.dart`) now implements
  the rest of the default-rule matrix this slice owns — #3, #4, #6, #7, #26 and #28 — so those
  syntaxes have left the rejection surface:
  - **#3 `text`** matches an element's *own* text, case-insensitively, so a node whose text lives in
    a child is not a hit (upstream's `getElementsContainingOwnText`, `AnalyzeByJSoup.kt:319`); it
    shares one normalisation with the #8 `ownText` extraction.
  - **#4 `children`** takes the direct children, ignores the second and third segment, and chains
    into the next selector like any other segment.
  - **#6 `!`** drops `:`-separated indices, negatives included.
  - **#7** a leading `-` reverses the result list; it is stripped before the flag head is
    recognised, so `-@css:.a` still reports `unsupported:@css:` instead of a malformed rule.
  - **#26 `[]`** index lists: a single index, several indices in authored order, ranges, ranges with
    a step, descending ranges, exclusions, and out-of-range / over-the-end clamping.
  - **#28** — an index as the first rule of a segment (`.1` / `[1]` / `children[1]`) — is a **new
    matrix row**: it existed only upstream (`AnalyzeByJSoup.kt:311` and `:460`) and this engine had
    been rejecting it, which review judged an M0 gap. ADR-0014 carries the second-round note and
    the ruling, `book-source.md` §3 the row itself, and a test asserts the three spellings agree.
- Validation and evaluation are now **one parse**: a rule string goes through a single pass that
  yields either the selector steps or the rejection, so the two can no longer disagree about the
  same rule. Structurally broken rules (an empty name, an unclosed or non-numeric index, a zero
  step, `!` in the position segment, two position spellings at once, `-` with no selector) stay
  `parseFailed` with the field path, and everything outside the slice still returns
  `unsupportedRule` with `rulePath` naming the syntax (C-SRC-4, C-SRC-8). The phase 2.2 entry below
  keeps the rejection surface *as it was then* and is now scoped that way.
- One deliberate difference from upstream is **registered rather than fixed**: `tag.div[-1].0` (an
  index list and the position segment at once) is a `parseFailed` here, while upstream folds
  `[-1]` into the name and silently matches nothing; C-SRC-4 forbids the silent form.
  `book-source.md` §3 records it as a registered difference so it is not mistaken for a defect.
- 30 new unit tests (that file 42 → 72). The host-side suite is now **310** tests and the gate is
  green end to end: `dart format` unchanged, `flutter analyze` no issues, `flutter test --coverage`
  310 passed, `dart run tool/check_coverage.dart` exit 0 with `core` 342/342 and `domain` 643/643
  (both files measured, as ADR-0019 requires). `docs/dev/test-environment.md` §1 carries the same
  count so the doc does not drift behind the slice. No new dependency: `cascadia` and `html` were
  already declared, and every CSS match still goes through cascadia (C-SRC-6). The matrix status
  column stays 待验证 — only a real book source regression may change it (`book-source.md` §10),
  which is 3.7's job.

### Catch-clause boundary recorded for C-ERR-2 (2026-10-11)

- ADR-0002 gained a sixth decision as a dated revision: a `presentation/` Notifier may catch
  `on Exception` without naming a narrower type, provided it immediately turns the failure into
  state and logs it; the `domain/` engine and use cases stay on specific types, and `Error` is never
  caught anywhere (ADR-0022). The ADR also states the extension rule — a `data/` fallback would need
  its own ADR rather than a local loosening.
- The loosening describes behaviour phase 2.5 already shipped instead of changing it:
  `search_results_notifier.dart:66` degrades a collaborator's `Exception` to
  `ParseFailureKind.parseFailed` and logs the book source, so the page no longer stays on
  `Searching`. Until now that code sat against the literal wording of C-ERR-2 with no recorded
  ruling; `constraints.md` C-ERR-2 now back-links ADR-0002, `adr/README.md` marks ADR-0002 as
  revised, and `tech-stack.md` §12 maps the boundary to its review check
  (`grep -rn 'on Exception' lib/` may only hit a `presentation/` notifier).

### Phase 3 registrations and baseline consistency (2026-10-11)

- `PLAN.md` §3 now owns the phase 3 **execution order** the architect fixed — 3.2 and 3.6 in one
  pass, a live-site spot-check after 3.2 and before the JS bridge, 3.5 after 3.6, 3.8 after 3.5,
  and the `JsBridge` / `@js:` work last — plus the 3.1 closure row and a phase 3 handover register,
  so the two items that had dropped out of the phase 1 register (the charset cache and the
  per-source cache purge) are visible again instead of silently lost.
- The charset detection cache is registered as **3.9**. This is a registration, not a scope change:
  the M0 enumeration of `book-source.md` §3.1 never included it, and §5 now says so too, which is
  what stopped §5 and §3.1 from disagreeing. `PLAN.md` Phase 5 gains a 5.5 row for the cache purge
  with both cost tiers spelled out — a full `DELETE` needs no schema change, while a per-source
  purge needs a `sourceId` column and therefore a schema dump plus a migration test. ADR-0011's
  broken cross-reference (`§决策 4` → `§后果`) was corrected, and `tool/coverage_allowlist.txt`'s
  header no longer claims the project has no exemptions.
- The locked-package count is no longer restated: `docs/dev/tech-stack.md` §1 and the `README.md`
  status table both still wrote `150`, while `NOTICE.md` §5 had been rebaselined to `156` when
  `integration_test` landed. The count now has one home — `NOTICE.md` §5, produced by
  `tool/scan_licenses.dart` — and the other two sites point at it, because restating a number is
  how this drifted (ADR-0013 §3). The dated `150` in ADR-0007 and ADR-0010 stays: those record
  what was scanned on 2026-10-10, not today's baseline, and ADR-0007's closure row now says so in
  place.

### Local test environment for Windows and Android (2026-10-11)

- Added `integration_test/` (a device-level smoke test plus a real on-disk Drift
  write/read round trip) and the `integration_test` SDK dev dependency, so
  `lib/core/di/database_executor_provider.dart` — allowlisted for coverage under ADR-0019
  category 2 — now has an automated verification path on Windows and Android instead of a
  manual `flutter run`.
- Added `tool/test/`: `run_all` / `run_unit` / `run_windows` / `run_android` PowerShell
  scripts plus shared `common.ps1`. The Android script starts the `Medium_Phone` AVD
  (detached from the caller's process tree, otherwise the emulator dies during the Gradle
  build), waits for `sys.boot_completed`, runs every `integration_test` file separately,
  and shuts the emulator down again.
- `docs/dev/test-environment.md` records the environment, its prerequisites, the four
  platform quirks found while building it (multi-file desktop runs, autoDispose providers
  in tests, detached emulator launch, blocking crash-report dialog) and a troubleshooting
  table. iOS is explicitly out of scope on this machine (no macOS/Xcode).
- Registered the new layer where the rules live, so `main` never carries "the code has
  `integration_test/`, the spec says tests live under `test/`": ADR-0017 gains a dated
  revision (§决策 5, with the rejected "put device-level cases in `test/`, mocked" option),
  C-TEST-4 gains the exception, `testing.md` §1 gains the fifth layer row and §3 / `naming.md`
  §2 now separate unit-widget-replay tests from device-level ones. Device-level suites stay
  out of CI; wiring them in still needs its own PR/ADR.
- `NOTICE.md` §5 and `docs/dev/tech-stack.md` §9 resynced with the new dependency graph
  (156 locked packages). `tool/scan_licenses.dart` now detects SDK packages from the lock
  file's `source: sdk` instead of a hard-coded name list, which had mis-reported the two
  newly pulled SDK packages (`flutter_driver`, `fuchsia_remote_debug_protocol`) as missing
  a licence file.

### Review follow-up: routing, F6 ruling and hardening (2026-10-11)

- ADR-0011 §决策 1 now carries a dated revision: routing is split three ways (mechanism in
  `core/router/`, page table in the composition root, typed arguments in the feature's
  `presentation/`), because `core/` must not import `features/`; C-ARCH-2 is **not** relaxed.
- ADR-0026 records the F6 ruling: a rejected **top-level** rule (`bookList` / `chapterList` /
  `content`) still fails the whole stage, while a rejected **non-top-level field** is cleared
  with a warning. The code lands together with the `@css:` work in 3.2, and both
  `book-source.md` §7 and `constraints.md` C-SRC-4 state that transition explicitly, so no
  reader mistakes the ruling for shipped behaviour.
- The search no longer hangs when a collaborator throws an `Exception` instead of answering
  with a `ParseResult`: the state degrades to the generic failure message and logs the book
  source, never the keyword. An `Error` is still not caught (C-ERR-2).
- C-UI-7 is decidable now: an interactive widget needs an accessible name, which Material
  derives from `tooltip` / visible text, and the rule is registered in `tech-stack.md` §12.
  `testing.md` §4 states that `test/support/` holds doubles *and* shared harnesses, and
  `architecture.md` §1 notes that a feature's derived providers sit next to its notifiers.

### Minimal book source UI (2026-10-11)

- Added the Phase 2.5 vertical slice: search form → hit list → book detail with its
  chapter list → plain-text reader, in `lib/features/book_source/presentation/`. Every
  string comes from the ARB files (en/zh in this same change) and every colour, spacing
  and text style from the `m3e_design` tokens. Each page has a smoke test, and one test
  walks the whole chain (search → detail → chapters → text) through the real pipeline on
  the sanitized offline corpus, so the UI evidence is not a page rendering a stub.
- The app now routes through `AppRouter` in `lib/core/router/`: typed `freezed` route
  arguments, one push entry point, and the page table in the composition root because
  `core/` must not import `features/`. `PLAN.md` 2.5 is closed; the manual live-site run
  stays G2b (ADR-0024).
- The selected book source is still a seam: `currentBookSourceProvider` answers `null`
  until importing book sources lands in Phase 5, so the pages show an empty state
  instead of requesting pages with an empty rule set.

### Documentation and architecture audit (2026-10-11)

- `isVip` is M0 (`book-source.md` §2/§4.1, `PLAN.md` 3.5) and `updateTime` is M1 because
  it needs the M1 `java.timeFormat`: the M1 rows of `book-source.md` §3.1 and ADR-0014
  carried a copy-paste error, now corrected with a dated revision note, and `PLAN.md`
  Phase 4 names `updateTime`.
- ADR-0025 registers the domain-service deviation (review F1), and `architecture.md` §3
  gained the matching allowlist entry with its criteria; ADR-0019 §2 gained the
  "no measurable lines" sub-case for pure freezed entities, with `testing.md` §2 and the
  allowlist comment following.
- ADR-0023 §4 records that the offline pages are constructed when the site is gone
  (ADR-0024 §2, `book-source.md` §10); the original wording stays for traceability.
- `architecture.md` §6 states where each part of routing lives (mechanism, page table,
  typed arguments), which is what the code does without breaking C-ARCH-2.
- Stale references corrected: `PLAN.md` no longer points at the deleted
  `offline_replay_test.dart` and its unit-test count is the measured 42; the two closed
  handover rows carry a closure marker and the open optional-field ruling is registered;
  `AGENTS.md` §5 points at `constraints.md` §14; `l10n.yaml` at `naming.md` §8;
  `README.md` no longer restates the phase status it delegates to `PLAN.md`;
  `pubspec.yaml` cites ADR-0015 instead of the superseded ADR-0008; the shared
  log-printer test double is `fake_log_printer.dart`; `naming.md` §4 carries the real
  `renderUrlTemplate` signature; `constraints.md` §15 gained the doc-versus-behaviour
  self-check item.

### Rule engine (2026-10-11)

- Added the Phase 2.2 minimal `RuleEngine`
  (`lib/features/book_source/domain/rule_engine/rule_engine.dart`) covering matrix #1/#2/#5/#8/#9:
  the `class` / `id` / `tag` selector segments, the position segment with positive and negative
  indexes, the extraction `text` / `textNodes` / `ownText` / `html` / `all` or an attribute name,
  and the `##regex##replacement` tail. Its shape follows upstream's three entry points:
  `selectAll` (list rules — every segment is a selector), `extractAll` (value rules — the last
  segment is the extraction) and `extractFirst`.
- The upstream semantics were pinned against a maintained fork
  (`hapelee/legado-with-MD3`'s `AnalyzeRule.kt` / `AnalyzeByJSoup.kt`) because `gedoor/legado`
  itself has been emptied; that fact is now recorded in `book-source.md` and ADR-0014. Three
  behaviours that `package:html` + `cascadia` do not give for free were implemented to match it:
  matching includes the scope element (jsoup does, `cascadia.queryAll` deliberately does not),
  `text` / `ownText` collapse whitespace the way jsoup normalises it (the Dart DOM only
  concatenates text nodes), and `textNodes` / `ownText` are the *direct* text nodes.
- `html` drops `script` / `style` like upstream, but on a **clone**, so the engine never mutates
  the caller's document (C-SRC-9); attribute extraction skips blanks and duplicate values, and an
  out-of-range index yields no match instead of an error — all upstream behaviour.
- `##` replacement expands `$1` / `${name}` group references: Dart's `replaceAll` writes `$1`
  literally (verified: `'abc'.replaceAll(RegExp(r'a(b)'), r'[$1]')` → `[$1]c`) while upstream
  substitutes the capture group, and real book sources rely on it (`##.*共(.*字).*##$1`). An
  unparsable pattern degrades to a literal replacement, which is what upstream does when its regex
  cache cannot compile the pattern.
- Everything outside this phase's matrix is **rejected** as `ParseFailureKind.unsupportedRule`
  instead of being silently mis-parsed (C-SRC-4), with `rulePath` naming the syntax
  (`unsupported:<syntax>`). The full set **as of this phase**, so the rejection surface stays
  auditable — phase 3.1 later moved #3, #4, #6, #7, #26 and #28 out of it and raised this file's
  test count to 72 (see the phase 3.1 entry above), so the table below records what 2.2 shipped
  rather than today's surface:

  | Syntax | `rulePath` | Owner |
  |---|---|---|
  | `@css:` `@json:` `@js:` `@xpath:` `@put:` `@get:` `@webJs` `@@` `{{` `//` `$.` `$[` `{` `:` (leading) | the flag as written | matrix #12–#20 |
  | `\|\|` `&&` `%%` | `unsupported:\|\|` etc. | #10 / #11 / #27 |
  | leading `-` (reverse) | `unsupported:-` | #7 |
  | `!` (exclude) | `unsupported:!` | #6 |
  | `:` inside a position segment | `unsupported::` | #6 (its index-list form) |
  | `[]` index lists | `unsupported:[]` | #26 |
  | `children` / `text` segment types | `unsupported:children` / `unsupported:text` | #3 / #4 |
  | any other segment type | `unsupported:<type>` | #12 (upstream degrades it to raw CSS) |

  Mid-rule flags (`class.a@css:.b`) and flag-like extraction segments are rejected too, because
  upstream treats them as nested rules; an `@@` anywhere in the body is rejected **before** the
  `@`-split, because the split would otherwise leave an empty segment that would be misreported as
  a malformed rule (matrix #15 is M1, not a broken rule). Structurally broken rules (a missing
  name, a non-numeric position, an empty extraction) are `parseFailed` with the field path, so a
  failure still points at the book source field (C-SRC-8). A blank rule and a rule without a match
  are **successes with no values**, because real exports use `""` for absent fields and only the
  caller knows whether a top-level rule had to match (`book-source.md` §7).
- The `##` family also covers upstream's four-part form `##match##replace###` (matrix #25, newly
  recorded in the matrix). Its upstream semantics are **not** "replace the first occurrence":
  upstream takes the first **match** and applies the replacement *inside it*, returns an empty
  string when nothing matches, and returns the replacement as-is when the pattern cannot be
  compiled (`AnalyzeRule.kt:497`). Implemented exactly, because a real source using `###` has to
  produce upstream's output.
- 42 unit tests in `test/features/book_source/domain/rule_engine/rule_engine_test.dart`; domain
  coverage stays at 100% and both new files are measured, as ADR-0019 requires. No new dependency:
  `cascadia` and `html` were already declared (C-SRC-6 keeps every CSS match inside cascadia).

### Legal stance after the upstream shutdown (2026-10-11)

- ADR-0023 records the architect's three rulings after the upstream repository was emptied by a
  criminal judgment (the operators were convicted of copyright infringement, with the court
  finding that "book source" files plus deep linking served nearly 4000 unauthorised works and
  earned over 1 million yuan). The rulings: keep the Legado dialect and its field names as the
  interoperability contract; keep only **sanitised, minimal** real corpus in the repository
  (neutral name, `.test` hosts, rule strings verbatim, provenance in
  `test/fixtures/**/README.md`); and strengthen the disclaimers.
- `NOTICE.md` §2 now records the upstream status and the judgment; §3 gained an explicit
  **prohibited-use** clause (no scraping, aggregating or redistributing unauthorised content
  through book sources, and no profiting from it) plus the matching risk notice. The same stance
  reaches the C-UI-9 legal-notices screen through the new `legalNoticesProhibitedUse` ARB key (the
  page itself still lands in Phase 5). The ADR states plainly that it is not legal advice.
- The matrix gained the three rows it was missing (`%%`, `###`, `[]` index lists) — they existed
  only in upstream code, so the engine was rejecting them correctly while the ledger stayed silent.
  They are appended as #25–#27 rather than inserted, because `PLAN.md` and ADR-0014 reference
  `#1–#14` / `#15–#19` / `#20–#24` and inserting would renumber them. ADR-0014 carries the
  matching factual addendum.

### URL templates, use cases and the failure factory (2026-10-11)

- **2.3** `renderUrlTemplate` (`lib/features/book_source/domain/url_template.dart`) renders `{{key}}` /
  `{{page}}` / `{{baseUrl}}` with the "encode once, never twice" rule pinned against upstream
  (`AnalyzeUrl.appendEncoded` + `NetworkUtils.encodedForm`, whose accepted set is `[A-Za-z0-9*._-]`
  plus valid `%XX`): the keyword is form-encoded the way Java's `URLEncoder` does (space → `+`,
  upper-case `%XX`, `!` / `'` / `~` escaped) while an already-encoded keyword passes through. An
  undefined variable renders as an empty string and is reported through the logger — naming only the
  variables, never the template, because a template may already carry the search keyword (C-ERR-8,
  C-SEC-4). Nested `{{}}` rules (matrix #18) are M1 and are treated as undefined variables for now;
  the boundary is registered in `PLAN.md`.
- The same module gained `resolveAbsoluteUrl` / `resolveAbsoluteUrlOrNull` (§4's "a relative URL must
  be resolved against the page it was found on"), which return the input unchanged when it cannot be
  parsed instead of throwing (C-ERR-1).
- **2.4** the four use cases (`domain/usecases/`): `SearchBooks`, `FetchBookInfo`, `FetchToc` and
  `FetchContent`, each with the fixed `execute()` shape of C-ARCH-4, built on one shared
  `PageFetchService` that owns §7's failure rules — a top-level `bookList` / `chapterList` / `content`
  that matched nothing is `parseFailed`, an empty optional field is a success, and a rejected rule
  keeps travelling as `unsupportedRule` (C-SRC-4). The new entities `Book` / `BookInfo` / `Chapter`
  carry **no** JSON annotations (ADR-0021 §决策 3), and `features/book_source/di.dart` provides the
  engine, the service and the four use cases through `@riverpod` (C-STATE-2). A hit or chapter without
  a URL is skipped with a warning instead of failing the page (§9).
- **2.7** `failureAt<T>` (`lib/core/error/parse_result.dart`) is now the single construction point for
  failures: it asserts a non-empty `rulePath` (C-SRC-8), and every failure path of the rule engine and
  of the use cases goes through it.
- The offline replay now drives the **production chain** — use case → `renderUrlTemplate` →
  `HttpClient` → `RuleEngine`, with a hand-written `FakeHttpClient` — and lives in
  `test/features/book_source/domain/usecases/search_books_test.dart`, so it satisfies ADR-0017's
  file-level mirror rule and asserts the exact URLs and `rulePath`s requested per stage. The previous
  test-only chain, which never touched the template or the HTTP layer, was deleted: a Gate must not
  accept a chain that production code never runs (`PLAN.md` §6 trap #1).
- Docs and process: ADR-0024 splits `PLAN.md`'s G2 into **G2a** (offline replay through the production
  chain — achieved) and **G2b** (live link, after `@css:` lands in 3.2) with the 242 → 20 → 4 → 0
  measurements as evidence; ADR-0023's status line now records that the ruling happened at review time
  rather than in the round it was written, and its corpus rule carries a re-review trigger;
  `book-source.md` §10 now says pages are **preferably captured** and may be constructed with
  provenance when the site is gone; `%%` is explicitly **M0 → Phase 3.2** instead of falling into M2
  through the fallback rule; and `CONTRIBUTING.md` gained the one-writer-per-worktree rule that B1's
  root cause called for.

### Offline corpus for the default-rule slice (2026-10-11)

- Added the corpus pair the vertical slice needs: `test/fixtures/book_sources/legado_default_rules_source.json`
  (a real export whose four rule objects use **only** the default syntax, trimmed to one entry and
  sanitised per ADR-0023) plus `test/fixtures/html/{search_result,book_page,chapter_page}.html`, and
  a replay that drives the **production chain** (see the next section). The first half of `PLAN.md`
  G2 — now G2a — is therefore reachable.
- **The pages are constructed to satisfy the real source's selectors, not captured** — a documented
  deviation from the ruling, which asked for captured HTML. Measured evidence: of 242 sampled
  sources only 20 (8%) use the default syntax throughout; only 4 of those sites are still up; and
  **none** of the four still resolves its search path (404, redirect to the home page, or zero
  selector matches — the 2021 rules no longer fit today's sites); the 12k-entry collection's release
  asset is gone. `test/fixtures/html/README.md` records the measurements and states that no real
  work's text is included, which also keeps ADR-0023's stance. Swapping in captured pages later needs
  no test change.
- The other half of G2 — "run the real link manually once" — cannot be satisfied in Phase 2 either:
  every live source needs `@css:`, which is Phase 3.2. It is registered in `PLAN.md` for a ruling
  instead of being dropped silently.

### Book source models (2026-10-11)

- Added the Phase 2.1 book source models: `lib/features/book_source/domain/entities/book_source.dart`
  with `BookSourceType`, `BookSource`, `SearchRule`, `BookInfoRule`, `TocRule` and
  `ContentRule`, all `freezed` + `json_serializable` as C-SRC-7 requires. The field set is
  deliberately limited to what the Phase 2 vertical slice consumes; the paging rules
  (`nextTocUrl` / `nextContentUrl`), `replaceRegex`, `isVip` / `updateTime` and the
  display-only counters stay unmodelled for now, with their phase ownership now written into
  `PLAN.md` (`replaceRegex` joins 3.5, the counters join Phase 5).
- ADR-0021 records the one exception this needs: the models live in `domain/` **and** carry
  JSON annotations, which `architecture.md` §3 forbids for that layer. The exception is scoped
  to the book source models — Legado JSON *is* the domain rule language, and a parallel `data/`
  DTO would have duplicated every model for a consumer that does not exist yet.
  `architecture.md` §3, `constraints.md` C-SRC-7 and `book-source.md` §2 back-link it.
- `book-source.md` §2's "unknown fields must be kept, not dropped" is implemented per object:
  each model carries an `extra` map filled by a named `fromLegadoJson` factory that diffs the
  raw JSON against the generated `toJson`, so importing a real Legado export keeps
  `bookSourceComment`, `exploreUrl`, `customOrder` and every other unmodelled key — including
  the keys nested inside `ruleToc` / `ruleContent` — while the generated `fromJson` stays the
  single implementation of the field mapping (C-SRC-7 forbids hand-written `fromJson`).
  The retained keys live **in memory only**: `toJson` does not write them back, so merging them
  into an exported file still has to be built together with the import/export feature
  (ADR-0021 §后果). No claim of lossless export is made before that exists.
- The Legado `header` field is a JSON *string*; a field-level `JsonConverter` turns it (or an
  already-parsed object) into `Map<String, String>?`, keeps "absent" and "empty" distinct, and
  raises `FormatException` instead of silently dropping a malformed header. `bookSourceType`
  maps through `BookSourceType` with `@JsonValue`; the original keys
  (`bookSourceName`, `ruleSearch`, ...) are restored on `toJson`, so an import round-trips.
  Writing back normalises `header` to Legado's string form even when the input was an object,
  so the round trip is value-preserving rather than byte-exact.
- Added the offline corpus `test/fixtures/book_sources/legado_export_sanitized.json`: a **real**
  Legado export (taken from a public book source collection, trimmed to one source, host and name
  sanitised to the reserved `.test` TLD, every rule string kept verbatim). Its 27 top-level keys
  include 16 that the model does not know yet, which is what makes it the acceptance corpus for
  `PLAN.md` 2.1; provenance and sanitising are recorded in
  `test/fixtures/book_sources/README.md`. 19 unit tests in
  `test/features/book_source/domain/entities/book_source_test.dart` cover the mapping, the
  defaults, the header forms and the per-level retention — including one test that asserts every
  key of the real export is accounted for either as a modelled field or in `extra`. No test
  touches the network (C-NET-8); domain coverage stays at 100% and the new file is measured, as
  ADR-0019 requires.
- **Malformed input is now catchable** (ADR-0022, decided by the architect in review): the root
  `build.yaml` turns on `json_serializable`'s `checked: true`, so a missing required key, a wrong
  type, an invalid `header` and an unknown `bookSourceType` all surface as
  `CheckedFromJsonException implements Exception` — carrying `key` (the `rulePath` source C-SRC-8
  needs) and `innerError` (the cause). Unchecked mode raised `TypeError` / `ArgumentError`, i.e.
  `Error`s, which `avoid_catching_errors` (C-ERR-2) forbids catching, so
  `ParseFailureKind.invalidBookSource` used to be unreachable. An unknown `bookSourceType`
  rejects the whole source instead of falling back to `text`. The three `throwsFormatException`
  assertions and the two `throwsA(anything)` ones were tightened to assert that exception, its
  `key` and its `innerError`; `book_source.g.dart` was regenerated in the same change (C-DEP-5).

### Documentation consistency (2026-10-11)

- Fixed six documentation defects found while establishing the code-review baseline. **None of
  them changes a decision** — each aligns a document with an already Accepted ADR, so no new
  ADR is needed (ADR-0012 §6):
  - `NOTICE.md` §1 no longer carries the GPL appendix clause "or (at your option) any later
    version"; ADR-0007 rules **version 3 only**, and the section now says so explicitly and
    warns against re-adding the clause from the upstream template.
  - `tool/coverage_allowlist.txt` now lists all **three** exemption categories of ADR-0019 §2
    (it said two, omitting the code-generator-input category that its own two entries use).
  - `README.md`'s status table no longer claims the application code is unimplemented or that
    dependency licences are still unverified; phase progress now points at `PLAN.md` §3.
  - ADR-0010 §9 and `tech-stack.md` §13 stopped restating the lint-rule count and the Dart
    baseline, which now live only in `tech-stack.md` §1 (ADR-0013 §2); the superseded numbers
    are kept in the ADR as a dated revision note.
  - `docs/README.md` §4 now indexes `tool/check_coverage.dart`, `tool/scan_licenses.dart`,
    `tool/spike/` and `.github/workflows/ci.yml` (ADR-0012 §1 requires new paths in the index).

### Storage layer (2026-10-11)

- Added the Phase 1.5 storage layer: `lib/core/storage/` with `ReaderDatabase` (schema
  version 1), the `CacheEntries` table, `cache_key.dart` (SHA-256 over book source ID +
  rule field + URL + page, so neither the URL nor a search keyword is stored in cleartext)
  and `CacheDao` (expiry written on every put, expired reads count as misses,
  `deleteExpired()` bounds the table — C-NET-6), plus `lib/core/utils/clock.dart` and the
  providers in `lib/core/di/` (`clock`, `databaseFilePath`, `databaseExecutor`,
  `readerDatabase`, `cacheDao`).
- Time comes from the injected `Clock` and never from `DateTime.now()`, so the TTL tests
  move a fake clock instead of sleeping (`testing.md` §3/§4); the database path is built
  with `Uri.resolve` instead of string concatenation, so no platform separator is ever
  hard-coded (C-PLT-3).
- Schema changes are guarded: `drift_schemas/drift_schema_v1.json` and
  `test/core/storage/generated_migrations/` are committed, and `migration_test.dart` uses
  `drift_dev`'s `SchemaVerifier` to compare the created schema against the dumped v1, so
  changing a table without re-dumping fails the suite. The dump/generate commands live in
  `tech-stack.md` §8.
- ADR-0019 gained a third allowlist category for **code-generator input files**, with two
  entries: `database_executor_provider.dart` (drift_flutter's background isolate cannot be
  reached from `flutter test` — `Channel was closed`) and `cache_entries.dart` (drift's
  column getters and `primaryKey` are shadowed by the generated table class and never run
  at runtime, so they are unreachable by design; the schema comparison above guarantees
  them). Both carry `// coverage:ignore-file`, and `testing.md` §2 documents the rule.
- Fixed the three P1.4 follow-ups: malformed or scheme-less URLs are rejected before dio is
  called (dio's internal `Uri.parse` could otherwise surface a `FormatException` that was
  reported as `encodingFailed`), the `FormatException` clause now covers decoding only, and
  `HttpPolicy.timeout`'s positivity requirement is documented for the settings phase that
  will own it.
- `book-source.md` §5.1 was consolidated into a single section (the label table plus the
  Big5 gap and the sniffing caveat), because the P1.4 and P1.5 rounds had each added a
  section with that number.

### Network layer (2026-10-11)

- Added the Phase 1.4 network layer: `HttpClient` (interface) with `DioHttpClient`,
  `CookieManager` with `InMemoryCookieManager`, `HttpPolicy` (timeout, retry bound,
  `User-Agent`, plaintext-HTTP switch), `HttpResponse` and `charset_decoder.dart`, plus the
  injectable wiring in `lib/core/di/http_client_provider.dart`.
- Failures never throw: timeouts, connection errors, 403/404/5xx and undecodable bodies are
  mapped onto `ParseFailureKind` and returned as `ParseResult` (C-ERR-1). Retries reuse
  `ParseFailureKind.isRetryable`, so only the two transient kinds are retried, and the bound
  is explicit (`maxRetries`, C-NET-2).
- Plaintext `http://` is rejected unless `HttpPolicy.allowPlainHttp` is set (C-SEC-2),
  `Cookie` headers are produced only by the interceptor that asks the `CookieManager`
  (C-NET-5), and every failure log goes through `redactUrl` + `describeError`, with the
  search keyword kept out of the log entirely (C-SEC-4, ADR-0006 §5).
- Encoding follows `book-source.md` §5: the `Content-Type` and `<meta>` declarations win,
  byte sniffing through `betto_charset_detector` is the fallback, and an invalid body raises
  `FormatException`, which becomes `encodingFailed` instead of being swallowed
  (`allowMalformed` is never used, C-NET-3). `charset` was promoted from a transitive to a
  direct dependency (no new package in the lock) to turn the detected label into a decoder;
  `NOTICE.md` §5 and `docs/dev/tech-stack.md` §5 were updated, and
  `book-source.md` §5.1 now records the labels that can and cannot be decoded.
- `dio` is imported by `lib/core/network/http_client.dart` only (C-NET-1); tests attach a
  hand-written `HttpClientAdapter` double in `test/support/` instead of mocking dio
  internals or touching the network (`docs/dev/testing.md` §4).

### Licence scan (2026-10-11)

- Corrected the classification rule in `NOTICE.md` §6 and the inventory in §5: the BSD
  third clause must be matched as `Neither the name`, **not** `3. Neither the name`. Dart's
  own packages write it as a bullet (`* Neither the name`), so the numbered pattern matched
  only `cascadia` and the other 93 BSD-3-Clause packages were reported as BSD-2-Clause.
  The corrected counts are BSD-3-Clause 93, MIT 37, Apache-2.0 9, BSD-2-Clause 6
  (+ 5 Flutter SDK packages = 150), still with zero GPL / MPL / unknown entries, so
  C-DEP-7's conclusion is unchanged; only the inventory was wrong. Six rows of the direct
  dependency table moved from BSD-2-Clause to BSD-3-Clause (`shared_preferences`,
  `path_provider`, `json_annotation`, `flutter_lints`, `build_runner`,
  `json_serializable`) — `docs/dev/tech-stack.md` already had them right.
- Added `tool/scan_licenses.dart`, so §6 is executable instead of manual. It reads only the
  local pub cache (path discovered from `PUB_CACHE` / `%LOCALAPPDATA%` / `~/.pub-cache`),
  classifies a multi-licence file by its **first** section (e.g. `sqlcipher_flutter_libs`
  is MIT, not the OpenSSL Apache-2.0 text that follows it) and exits non-zero when a
  package has no licence file or lands in a forbidden family.

### Platform abstraction (2026-10-11)

- Added the Phase 1.3 platform layer: `lib/core/platform/platform_info.dart`
  (`PlatformInfo` / `SystemPlatformInfo`), `dynamic_color_provider.dart`
  (`DynamicColorProvider`, `SystemDynamicColorProvider`,
  `resolveDynamicColorProvider`) and the injectable wiring in
  `lib/core/di/platform_provider.dart`, plus the shared fake
  `test/support/fake_platform_info.dart`.
- `lib/app.dart` is now a `ConsumerWidget` and no longer imports `dynamic_color`, so the
  UI never asks which platform it runs on (C-PLT-1, C-PLT-2). `Platform.is*` and
  `package:dynamic_color` appear only inside `lib/core/platform/`.
- ADR-0020 records that the dynamic color interface wraps `DynamicColorBuilder`
  instead of returning a `ColorScheme?` (which would need a `FutureBuilder` and make the
  first frame fall back to the seed color), that it is injected at the root, and that
  `PlatformInfo` is injectable but consumed only by `core/platform/` resolvers and tests.
  `docs/dev/platform.md` §2/§3 and `docs/dev/constraints.md` C-PLT-2 were updated to match.
- `docs/dev/testing.md` §4 now documents `test/support/` as the home of shared fakes.

### Spec, gates & consistency audit (2026-10-11)

- Added ADR-0016 (sealed variant form: the compiler/generator shape wins over the literal
  `final class` wording), ADR-0017 (tests live under `test/`, mirroring the `lib/` path),
  ADR-0018 (Android baseline stays at `minSdk 26`, with a rebuilt, self-contained rationale),
  ADR-0019 (the coverage gate must fail on source files missing from the report) and a
  revision of ADR-0013 (single source for the gate-command list and the generation command).
- Added the Phase 1.1 error contract under `lib/core/error/`: `parse_result.dart`
  (`ParseResult` / `ParseFailureKind` per ADR-0002) and `parse_failure_arb_key.dart`
  (`resolveFailureArbKey`, the single implementation of the `failure<PascalCaseKind>`
  ARB key rule from `docs/dev/naming.md` §8).
- Added the Phase 1.2 logging layer under `lib/core/logging/` (`AppLogger` facade,
  `LogLevel`, `redaction.dart`) with its provider in `lib/core/di/logger_provider.dart`.
  Every message and every error is sanitised inside the facade: `Bearer` credentials,
  `<name>=<value>` pairs, URL userinfo, sensitive path segments and all query values are
  masked, and a non-string error is reduced to `describeError` so an exception whose
  `toString()` embeds a URL cannot leak it (C-SEC-4). The facade uses
  `ProductionFilter`, because `package:logger`'s default `DevelopmentFilter` is wrapped in
  `assert(() { ... }())` and would drop every record in release builds.
  `crypto` (already present transitively) was promoted to a direct dependency for the
  SHA-256 digests used by `describeKeyword` / `describePayload` / `describeError`; its
  licence was verified and `NOTICE.md` §5 and `docs/dev/tech-stack.md` §7 updated.
- The coverage gate now reports exit code `3` when a `lib/` source file never appears in the
  lcov report, with `tool/coverage_allowlist.txt` for platform-only or integration-only
  entries. Previously an untested new `lib/core/**` file silently produced `100% 4/4 OK`.
- The gate command list now has one owner (`AGENTS.md` §4); `docs/dev/testing.md` §7 keeps
  only CI ordering. Removed stale `custom_lint` and `--coverage`-less variants from the PR
  template, README, CONTRIBUTING and the AI prompt template.
- `--delete-conflicting-outputs` removed from C-DEP-4 and all call sites: `build_runner
  2.16.2` drops it and prints `These options have been removed and were ignored`.
- Cleared the remaining `flutter_js_plus` residue from `tech-stack.md` §5, `testing.md` §6,
  `platform.md` §1 and `android/app/build.gradle.kts`; one of those passages still asserted
  the callback bridge was unusable in a background isolate, which ADR-0015 refuted.
- Fixed duplicated/ drifted facts: `drift_dev` version in ADR-0003, package count 151 -> 150
  in ADR-0007/ADR-0010/`tech-stack.md`, `custom_lint` in ADR-0001, stale platform baselines in
  ADR-0013, the duplicated `8.` item in ADR-0010, and the superseded ADR-0008 banner.

### Documentation (2026-10-10)

- Added `PLAN.md`: implementation order, per-phase acceptance criteria, gate checkpoints,
  a rework-pitfall list distilled from this session, and a routing index for "I want to
  build X, where do I read first". It owns *sequencing* only — scope stays in ADR-0014 and
  rules stay in `docs/dev/*`.
- Registered it in `docs/README.md` §1 and the `AGENTS.md` §2 map so it is not an orphan
  document.

### Engine selection (2026-10-10)

- Replaced `flutter_js_plus` with `flutter_qjs_next ^1.5.2` (MIT) and superseded ADR-0008 with
  ADR-0015. The same nine probes now pass end to end, and the two quotas that were previously
  impossible are real: a 2s engine timeout aborts a runaway script in 2012ms with the runtime
  still usable, and an 8MB cap raises a JS error in 99ms.
- Removed the `kotlin.jvm.target.validation.mode=warning` Gradle workaround, which existed only
  for that plugin. `kotlin.incremental=false` stays: it is a Kotlin 2.4 / Windows cache-locking
  issue unrelated to any plugin. Both `flutter build apk --debug` and
  `flutter build windows --debug` succeed.
- `@js:` returns to M0 in the book-source matrix; no dependency source patching is needed any
  more, so the spike now runs against the normal build output via `FLUTTER_QJS_NEXT_LIBRARY`.

### Spike 1 — JS engine in a background Isolate (2026-10-10, superseded by *Engine selection*)

> This entry records the intermediate state reached during the spike. Its conclusions about
> the engine choice and about `@js:` are superseded by the *Engine selection* entry below;
> the measured numbers describe `flutter_js_plus`, not the engine finally adopted.

- Added `tool/spike/js_isolate_spike_test.dart` (9 probes) and
  `tool/spike/README.md` (evidence + engine option matrix).
- **Confirmed:** QuickJS runs in a background Isolate, the JS -> Dart callback bridge works
  there too, a runaway script is containable by `Isolate.kill` without poisoning the native
  library, and a reused runtime evaluates in ~0.11 ms (`flutter_js_plus`; measured 0.18 ms on
  `flutter_qjs_next`).
- **Refuted:** `flutter_js_plus 0.0.4` fails to compile on Dart 3.13 (4 nullable `Pointer`
  returns in `Pointer.fromFunction`), its Windows CMake target name mismatches the package
  name, its `timeout` parameter has no effect, and the shipped DLL lacks `jsSetMemoryLimit`.
- ADR-0008 marked **部分失效（待裁决）** at the time; it is now `Superseded by ADR-0015`.
  Preferred candidate at that moment: `flutter_qjs_next`.

### Toolchain (2026-10-10)

- Installed Flutter 3.47.7 / Dart 3.13.5; scaffolded `android/`, `ios/`, `windows/`.
- Added the app bootstrap (`lib/main.dart`, `lib/app.dart`, `lib/core/theme/app_theme.dart`)
  plus a widget smoke test, replacing the Flutter template files.
- Dependency set fixed to the pub-solver-determined coherent solution (see `Changed` below).
- Android: `minSdk` pinned to 26. The original rationale (a requirement of the then-engine)
  was void once ADR-0015 replaced that engine and has been rebuilt from first principles in
  ADR-0018; see `docs/dev/platform.md` §1 and §8.
- Verified end to end: `flutter analyze` reports no issues, `flutter test --coverage` passes,
  the coverage gate exits 0, and `flutter build apk --debug` succeeds.
- `LICENSE` verified byte-identical to the canonical GPL-3.0 text; all locked packages
  license-scanned with zero findings (`NOTICE.md` §5; 151 at the time, 150 after the engine
  switch).

### Added

- `LICENSE` (GNU GPL-3.0) and `NOTICE.md`: copyright, upstream relationship, disclaimer,
  GPL compliance obligations and a third-party license inventory.
- `docs/README.md` as the single authoritative index for every documentation path.
- `docs/dev/architecture.md`: directory tree, layer boundaries, Riverpod DI, routing, and the
  `ParseResult` / `ParseFailureKind` contract.
- `docs/dev/book-source.md`: Legado rule dialect spec, support matrix, JS whitelist and quotas,
  and failure semantics.
- `docs/dev/testing.md`: test layering, coverage gate, golden strategy, and the CI pipeline.
- `docs/dev/platform.md`: platform baselines, dynamic color matrix, predictive back setup.
- `docs/dev/adr/`: 13 architecture decision records covering the 2026-10-10 audit findings.
- `pubspec.yaml`, `analysis_options.yaml`, `l10n.yaml` and `lib/l10n/app_{en,zh}.arb`
  as real, tool-readable files instead of documentation code blocks.
- `tool/check_coverage.dart`: executable coverage gate (core 100%, domain 100%, data 80%).
- `.github/workflows/ci.yml`, issue templates and pull request template.
- `README.md`, `CONTRIBUTING.md` (moved to the repository root).

### Changed

- `AGENTS.md` rewritten to 120 lines: workflow, gates and documentation map only, no rule text.
- All documentation now uses stable constraint IDs (`C-<group>-<index>`) so rules can be
  referenced instead of copied.
- Theme tokens are read via `Theme.of(context).m3e`; the previous example referencing
  `M3ETheme.colorScheme` / `M3ETheme.textTheme` was not compilable and has been corrected.
- Dynamic color source is `dynamic_color`; `material_you_dynamic_theme` is no longer allowed.
- State management is Riverpod with mandatory `@riverpod` code generation; the `XxxViewModel`
  naming and `presentation/viewmodels/` path are deprecated.
- Logging goes through a `core/logging` facade backed by `logger`.
- Dependency versions pinned to the pub-solver-determined coherent set:
  `dynamic_color` 1.9.0, `riverpod_annotation` 4.0.7, `riverpod_generator` 4.0.9,
  `freezed` 4.0.2, `json_annotation` 4.12.0, `drift_dev` 2.35.1.
  See `docs/dev/tech-stack.md` §1.1 for the hard constraints that force this combination.
- `analysis_options.yaml`: analyzer plugin moved to the **top-level** `plugins:` key;
  `analyzer: plugins:` is deprecated and emitted `analysis_options_deprecated_plugins`.
- CI `flutter-version` pinned to `3.47.7` to match the local toolchain.

### Fixed

- `betto_charset_detector` constraint corrected to `^0.1.0` (the previously documented
  `^1.0.0` does not exist).
- Replaced the EOL `sqlite3_flutter_libs` with `drift_flutter` (drift's current
  recommendation; the former fails to bundle native SQLite on newer Android toolchains).
- Theme API corrected against the official `m3e_design` 0.2.1 surface: text styles are read
  via `m3e.typography.base.titleLarge`; spacing is `m3e.spacing.{xs,sm,md,lg,xl,xxl}`.
- `riverpod_lint` 3.1.9 switched from `custom_lint` to `analysis_server_plugin`, so
  `custom_lint` was removed and the gate is now plain `flutter analyze`.
- Analyzer plugin config moved to the top-level `plugins:` key (the `analyzer: plugins:`
  form is deprecated in Dart 3.13).
- Android build blockers resolved and documented: `kotlin.incremental=false` (Kotlin cache
  locking on Windows) and `kotlin.jvm.target.validation.mode=warning` (`flutter_js_plus`
  still targets Kotlin 1.8 while AGP 9 defaults Java to 11).
- Flutter template `TODO`s in `android/app/build.gradle.kts` replaced with documented
  pre-release items (`applicationId`, release signing).

### Removed

- `golden_toolkit` (discontinued upstream); golden tests use the built-in `matchesGoldenFile`.
- The invalid lint `avoid_non_null_assertion` and the formatter-conflicting
  `require_trailing_commas`, plus seven duplicate YAML keys in the analyzer configuration.
- Superseded documents: `docs/dev/NAMING_CONVENTION.md`, `docs/dev/AGENT_CONSTRAINTS.md`,
  `docs/dev/TECH_STACK.md` and `docs/github/CONTRIBUTING.md`.

### Pending decisions

- Third-party license scanning is complete for **source** dependencies. A binary-level
  scan of the release artifacts (APK/EXE: Flutter engine, native libs, AOT output) is still
  required at release time; see `NOTICE.md` §4.
- Grammar rows in `docs/dev/book-source.md` §3 are still marked 待验证 and require
  regression against real book sources before the first importable release.
- `applicationId` is still the Flutter default `com.example.flutter_reader` and the release
  build reuses the debug signing config; both must be replaced before release
  (`docs/dev/platform.md` §8.2).
