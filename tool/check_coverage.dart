/// Checks per-layer line-coverage thresholds and unmeasured source files
/// against an lcov report.
///
/// Run after `flutter test --coverage`:
///
///     dart run tool/check_coverage.dart
///     dart run tool/check_coverage.dart --file=coverage/lcov.info --data=85
///     dart run tool/check_coverage.dart --allowlist=     # ignore the allowlist
///
/// Thresholds default to `docs/dev/testing.md`: core 95%, domain 95%, data 80%
/// (ADR-0077 lowered core/domain from 100% so tests can carry behaviour instead
/// of every reachable line).
/// They may be raised per invocation but never lowered without an ADR.
///
/// Thresholds alone are not enough: lcov only measures libraries that a test
/// actually loaded, so a brand-new untested `lib/core/**` file would be invisible
/// (neither numerator nor denominator) and the gate would report a cheerful
/// `100% lines 4/4 OK`. This tool therefore also enumerates every source file in
/// the gated layer paths and fails when one of them is missing from the report
/// (ADR-0019). Files that genuinely cannot be measured are listed in
/// `tool/coverage_allowlist.txt`; an allowlist entry that is measured anyway (or
/// no longer exists) is itself a failure, so the list cannot silently rot.
///
/// Exit codes: 0 = passed, 1 = a threshold is not met, 2 = the report or the
/// `lib/` directory is missing, 3 = a source file is missing from the report or
/// the allowlist is stale. Code 3 takes precedence over code 1 so that "no test
/// at all" is never reported as a mere percentage miss.
library;

import 'dart:io';

/// Report path written by `flutter test --coverage`.
const String _defaultReportPath = 'coverage/lcov.info';

/// Root of the production sources covered by the gate.
const String _defaultLibPath = 'lib';

/// Allowlist of files that are intentionally not measurable.
const String _defaultAllowlistPath = 'tool/coverage_allowlist.txt';

/// Minimum line-coverage percentage required per architectural layer.
const Map<String, double> _defaultThresholds = <String, double>{
  'core': 95,
  'domain': 95,
  'data': 80,
};

final RegExp _domainPattern = RegExp(r'^lib/features/[^/]+/domain/');
final RegExp _dataPattern = RegExp(r'^lib/features/[^/]+/data/');
final RegExp _generatedPattern = RegExp(r'\.(g|freezed|gr)\.dart$');

/// Accumulated coverage numbers of one architectural layer.
final class _LayerTotals {
  int found = 0;
  int hit = 0;

  /// Line coverage percentage; treated as 100 when nothing was measured.
  double get percent => found == 0 ? 100 : hit / found * 100;
}

/// Coverage numbers of a single source file.
final class _FileCoverage {
  _FileCoverage(this.path);

  final String path;
  int found = 0;
  int hit = 0;

  /// Line coverage percentage; treated as 100 when nothing was measured.
  double get percent => found == 0 ? 100 : hit / found * 100;
}

/// Entry point; see the library documentation for usage and exit codes.
void main(List<String> arguments) {
  final String reportPath =
      _readOption(arguments, '--file') ?? _defaultReportPath;
  final String libPath = _readOption(arguments, '--lib') ?? _defaultLibPath;
  final String? allowlistPath = _resolveAllowlistPath(arguments);
  final Map<String, double> thresholds = <String, double>{
    for (final MapEntry<String, double> entry in _defaultThresholds.entries)
      entry.key: _readNumber(arguments, '--${entry.key}') ?? entry.value,
  };

  final File report = File(reportPath);
  if (!report.existsSync()) {
    stderr.writeln('Coverage report not found: $reportPath');
    stderr.writeln('Run: flutter test --coverage');
    exitCode = 2;
    return;
  }
  if (!Directory(libPath).existsSync()) {
    stderr.writeln('Source directory not found: $libPath');
    exitCode = 2;
    return;
  }

  final Map<String, _FileCoverage> files = _parseLcov(report.readAsLinesSync());
  final Set<String> measured = <String>{
    for (final String path in files.keys)
      if (_toLibRelativePath(path) case final String relative) relative,
  };
  final Set<String> allowlisted = _readAllowlist(allowlistPath);

  final Map<String, _LayerTotals> totals = <String, _LayerTotals>{
    for (final String layer in _defaultThresholds.keys) layer: _LayerTotals(),
  };

  for (final _FileCoverage file in files.values) {
    final String? layer = _layerOf(file.path);
    if (layer == null) {
      continue;
    }
    final _LayerTotals? totalsOrNull = totals[layer];
    if (totalsOrNull == null) {
      continue;
    }
    totalsOrNull.found += file.found;
    totalsOrNull.hit += file.hit;
  }

  bool thresholdsMet = true;
  stdout.writeln('Layer coverage:');
  for (final MapEntry<String, double> entry in thresholds.entries) {
    final _LayerTotals? totalOrNull = totals[entry.key];
    if (totalOrNull == null) {
      continue;
    }
    final bool isMet = totalOrNull.percent + 1e-9 >= entry.value;
    thresholdsMet = thresholdsMet && isMet;
    stdout.writeln(
      '  ${entry.key.padRight(7)}'
      '${totalOrNull.percent.toStringAsFixed(2).padLeft(7)}%'
      '  need >= ${entry.value.toStringAsFixed(0)}%'
      '  lines ${totalOrNull.hit}/${totalOrNull.found}'
      '  ${isMet ? 'OK' : 'FAIL'}',
    );
  }

  if (!thresholdsMet) {
    stdout.writeln('Files below their layer threshold:');
    final List<_FileCoverage> offenders =
        files.values
            .where((_FileCoverage file) => _isBelow(file, thresholds))
            .toList()
          ..sort(
            (_FileCoverage a, _FileCoverage b) =>
                a.percent.compareTo(b.percent),
          );
    for (final _FileCoverage file in offenders) {
      stdout.writeln(
        '  ${file.percent.toStringAsFixed(1).padLeft(6)}%  ${file.path}',
      );
    }
  }

  final Set<String> gatedSources = _enumerateGatedSources(libPath);
  final List<String> unmeasured = <String>[
    for (final String path in gatedSources)
      if (!measured.contains(path) && !allowlisted.contains(path)) path,
  ]..sort();
  final List<String> staleAllowlist = <String>[
    for (final String entry in allowlisted)
      if (measured.contains(entry) || !gatedSources.contains(entry)) entry,
  ]..sort();

  if (unmeasured.isNotEmpty) {
    stdout.writeln('Source files missing from the coverage report:');
    for (final String path in unmeasured) {
      stdout.writeln('  $path');
    }
    stdout.writeln(
      'Add a test (C-TEST-4, ADR-0017) or list the file with a reason in '
      '${allowlistPath ?? 'the allowlist'} (ADR-0019).',
    );
  }
  if (staleAllowlist.isNotEmpty) {
    stdout.writeln('Stale allowlist entries (measured or not a gated source):');
    for (final String path in staleAllowlist) {
      stdout.writeln('  $path');
    }
  }

  if (unmeasured.isNotEmpty || staleAllowlist.isNotEmpty) {
    exitCode = 3;
    return;
  }
  exitCode = thresholdsMet ? 0 : 1;
}

/// Resolves the allowlist path; an empty `--allowlist=` disables the allowlist.
String? _resolveAllowlistPath(List<String> arguments) {
  final String? raw = _readOption(arguments, '--allowlist');
  if (raw == null) {
    final File fallback = File(_defaultAllowlistPath);
    if (!fallback.existsSync()) {
      stderr.writeln('Allowlist not found: $_defaultAllowlistPath');
    }
    return _defaultAllowlistPath;
  }
  return raw.isEmpty ? null : raw;
}

/// Reads the allowlist, ignoring blank lines and `#` comments.
Set<String> _readAllowlist(String? path) {
  if (path == null) {
    return <String>{};
  }
  final File file = File(path);
  if (!file.existsSync()) {
    return <String>{};
  }
  final Set<String> entries = <String>{};
  for (final String line in file.readAsLinesSync()) {
    // 允许行尾注释，便于就地写明豁免原因。
    final String entry = line.split('#').first.trim().replaceAll('\\', '/');
    if (entry.isNotEmpty) {
      // 统一归档为 `lib/...`，与列表中枚举出的路径同形（便于 `--lib=` 指向别处时复现）。
      entries.add(_toLibRelativePath(entry) ?? entry);
    }
  }
  return entries;
}

/// Lists every gated source file under [libPath] as a `lib/...` relative path.
///
/// Generated files (`*.g.dart` / `*.freezed.dart` / `*.gr.dart` and anything under
/// a `generated/` directory) and files outside the gated layer paths are excluded
/// by [_layerOf], so this set is exactly the set of files the gate expects to see
/// in the report.
Set<String> _enumerateGatedSources(String libPath) {
  final Set<String> sources = <String>{};
  for (final FileSystemEntity entity in Directory(
    libPath,
  ).listSync(recursive: true, followLinks: false)) {
    if (entity is! File || !entity.path.endsWith('.dart')) {
      continue;
    }
    final String? relative = _toLibRelativePath(entity.path);
    if (relative == null || _layerOf(relative) == null) {
      continue;
    }
    sources.add(relative);
  }
  return sources;
}

/// Returns whether [file] sits below the threshold of the layer it belongs to.
bool _isBelow(_FileCoverage file, Map<String, double> thresholds) {
  final String? layer = _layerOf(file.path);
  if (layer == null) {
    return false;
  }
  final double? threshold = thresholds[layer];
  if (threshold == null) {
    return false;
  }
  return file.percent + 1e-9 < threshold;
}

/// Maps [rawPath] to `core`, `domain` or `data`, or `null` when not measured.
String? _layerOf(String rawPath) {
  final String? relative = _toLibRelativePath(rawPath);
  if (relative == null || _isGenerated(relative)) {
    return null;
  }
  if (relative.startsWith('lib/core/')) {
    return 'core';
  }
  if (_domainPattern.hasMatch(relative)) {
    return 'domain';
  }
  if (_dataPattern.hasMatch(relative)) {
    return 'data';
  }
  return null;
}

/// Normalizes [rawPath] to the `lib/...` form used by the layer patterns.
String? _toLibRelativePath(String rawPath) {
  final String path = rawPath.replaceAll('\\', '/');
  final int libIndex = path.lastIndexOf('lib/');
  return libIndex < 0 ? null : path.substring(libIndex);
}

/// Returns whether [relativePath] is generated code excluded from the gate.
bool _isGenerated(String relativePath) =>
    _generatedPattern.hasMatch(relativePath) ||
    relativePath.contains('/generated/');

/// Parses lcov `SF`/`LF`/`LH` records into per-file coverage.
Map<String, _FileCoverage> _parseLcov(List<String> lines) {
  final Map<String, _FileCoverage> files = <String, _FileCoverage>{};
  _FileCoverage? current;
  for (final String line in lines) {
    if (line.startsWith('SF:')) {
      current = _FileCoverage(line.substring(3).trim());
      files[current.path] = current;
    } else if (line == 'end_of_record') {
      current = null;
    } else if (current != null) {
      if (line.startsWith('LF:')) {
        current.found = int.tryParse(line.substring(3).trim()) ?? 0;
      } else if (line.startsWith('LH:')) {
        current.hit = int.tryParse(line.substring(3).trim()) ?? 0;
      }
    }
  }
  return files;
}

/// Reads `--name=value` and returns the raw value.
String? _readOption(List<String> arguments, String name) {
  final String prefix = '$name=';
  for (final String argument in arguments) {
    if (argument.startsWith(prefix)) {
      return argument.substring(prefix.length);
    }
  }
  return null;
}

/// Reads a numeric `--name=value` option.
double? _readNumber(List<String> arguments, String name) {
  final String? raw = _readOption(arguments, name);
  return raw == null ? null : double.tryParse(raw);
}
