/// Checks per-layer line-coverage thresholds against an lcov report.
///
/// Run after `flutter test --coverage`:
///
///     dart run tool/check_coverage.dart
///     dart run tool/check_coverage.dart --file=coverage/lcov.info --data=85
///
/// Thresholds default to `docs/dev/testing.md`: core 100%, domain 100%, data 80%.
/// They may be raised per invocation but never lowered without an ADR.
///
/// Exit codes: 0 = all thresholds met, 1 = a threshold is not met,
/// 2 = the report file is missing.
library;

import 'dart:io';

/// Minimum line-coverage percentage required per architectural layer.
const Map<String, double> _defaultThresholds = <String, double>{
  'core': 100,
  'domain': 100,
  'data': 80,
};

final RegExp _domainPattern = RegExp(r'^lib/features/[^/]+/domain/');
final RegExp _dataPattern = RegExp(r'^lib/features/[^/]+/data/');

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
      _readOption(arguments, '--file') ?? 'coverage/lcov.info';
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

  final Map<String, _FileCoverage> files = _parseLcov(report.readAsLinesSync());
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

  bool failed = false;
  stdout.writeln('Layer coverage:');
  for (final MapEntry<String, double> entry in thresholds.entries) {
    final _LayerTotals? totalOrNull = totals[entry.key];
    if (totalOrNull == null) {
      continue;
    }
    final bool isMet = totalOrNull.percent + 1e-9 >= entry.value;
    failed = failed || !isMet;
    stdout.writeln(
      '  ${entry.key.padRight(7)}'
      '${totalOrNull.percent.toStringAsFixed(2).padLeft(7)}%'
      '  need >= ${entry.value.toStringAsFixed(0)}%'
      '  lines ${totalOrNull.hit}/${totalOrNull.found}'
      '  ${isMet ? 'OK' : 'FAIL'}',
    );
  }

  if (failed) {
    stdout.writeln('Files below their layer threshold:');
    final List<_FileCoverage> offenders = files.values
        .where((_FileCoverage file) => _isBelow(file, thresholds))
        .toList()
      ..sort((_FileCoverage a, _FileCoverage b) =>
          a.percent.compareTo(b.percent));
    for (final _FileCoverage file in offenders) {
      stdout.writeln(
        '  ${file.percent.toStringAsFixed(1).padLeft(6)}%  ${file.path}',
      );
    }
  }

  exitCode = failed ? 1 : 0;
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
  final String path = rawPath.replaceAll('\\', '/');
  if (path.endsWith('.g.dart') ||
      path.endsWith('.freezed.dart') ||
      path.endsWith('.gr.dart') ||
      path.contains('/generated/')) {
    return null;
  }
  final int libIndex = path.lastIndexOf('lib/');
  final String relative = libIndex < 0 ? path : path.substring(libIndex);
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
