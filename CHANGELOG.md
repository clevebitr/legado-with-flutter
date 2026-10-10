# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
- Dependency versions pinned to the current pub.dev releases; see `docs/dev/tech-stack.md` §1.

### Fixed

- `betto_charset_detector` constraint corrected to `^0.1.0` (the previously documented
  `^1.0.0` does not exist).
- Replaced the EOL `sqlite3_flutter_libs` with `drift_flutter` (drift's current
  recommendation; the former fails to bundle native SQLite on newer Android toolchains).
- Theme API corrected against the official `m3e_design` 0.2.1 surface: text styles are read
  via `m3e.typography.base.titleLarge`; spacing is `m3e.spacing.{xs,sm,md,lg,xl,xxl}`.
- `riverpod_lint` 3.1.9 switched from `custom_lint` to `analysis_server_plugin`, so
  `custom_lint` was removed and the gate is now plain `flutter analyze`.

### Removed

- `golden_toolkit` (discontinued upstream); golden tests use the built-in `matchesGoldenFile`.
- The invalid lint `avoid_non_null_assertion` and the formatter-conflicting
  `require_trailing_commas`, plus seven duplicate YAML keys in the analyzer configuration.
- Superseded documents: `docs/dev/NAMING_CONVENTION.md`, `docs/dev/AGENT_CONSTRAINTS.md`,
  `docs/dev/TECH_STACK.md` and `docs/github/CONTRIBUTING.md`.

### Pending decisions

- Version constraints in `pubspec.yaml` are not yet verified with `flutter pub get`;
  see `docs/dev/adr/0010-lint-baseline-and-gates.md`.
- Third-party license verification is incomplete; see `NOTICE.md` §5.
- The bundled GPL-3.0 text should be diffed against the canonical copy once network
  access is available; see `docs/dev/adr/0007-license.md`.
- Grammar rows in `docs/dev/book-source.md` §3 are still marked 待验证 and require
  regression against real book sources before the first importable release.
