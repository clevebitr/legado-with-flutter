# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
