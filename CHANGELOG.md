# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
