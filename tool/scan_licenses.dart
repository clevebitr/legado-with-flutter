/// Classifies the licence of every locked package from the local pub cache.
///
/// This is the executable form of the procedure in `NOTICE.md` §6. It needs no
/// network access and only reads files that `flutter pub get` already downloaded:
///
///     dart run tool/scan_licenses.dart            # counts + risky items
///     dart run tool/scan_licenses.dart --list     # also print every package
///
/// A package whose licence file bundles several licences is classified by the
/// **first** one, because a package's own licence comes first and bundled
/// third-party notices follow (for example `sqlcipher_flutter_libs` starts with
/// MIT and only later includes the OpenSSL Apache-2.0 text). That is implemented
/// by comparing the position of each family's marker instead of parsing the
/// section separators.
///
/// The BSD third clause is matched as `Neither the name`, **not** as
/// `3. Neither the name`: Dart's own packages write it as a bullet
/// (`* Neither the name`), and the numbered form silently misclassified 93
/// packages as BSD-2-Clause until 2026-10-11.
///
/// Exit codes: 0 = every package classified into a permissive licence,
/// 1 = a package has no licence file or landed in an unknown or forbidden
/// family, 2 = the pub cache could not be located.
library;

import 'dart:io';

/// Packages that come from the Flutter SDK instead of the pub cache.
const Set<String> _sdkPackages = <String>{
  'flutter',
  'flutter_test',
  'flutter_localizations',
  'sky_engine',
  'flutter_web_plugins',
};

/// Marker string per licence family, matched case-insensitively.
const Map<String, String> _familyMarkers = <String, String>{
  'MIT': 'permission is hereby granted',
  'Apache-2.0': 'apache license',
  'BSD': 'redistribution and use in source and binary forms',
  'GPL': 'gnu general public license',
  'MPL': 'mozilla public license',
};

/// Marker that separates BSD-3-Clause from BSD-2-Clause.
const String _bsdThirdClause = 'neither the name';

/// Licence families that must never be introduced (C-DEP-7).
const Set<String> _forbiddenFamilies = <String>{'GPL', 'MPL', 'UNKNOWN'};

/// One entry of `pubspec.lock`.
final class _LockedPackage {
  _LockedPackage(this.name, this.version);

  final String name;
  final String version;

  /// Directory name inside `<pub cache>/hosted/pub.dev/`.
  String get directoryName => '$name-$version';
}

/// Entry point; see the library documentation for usage and exit codes.
void main(List<String> arguments) {
  final bool listAll = arguments.contains('--list');
  final Directory? cache = _locatePubCache();
  if (cache == null) {
    stderr.writeln(
      'Pub cache not found. Looked at PUB_CACHE, %LOCALAPPDATA%\\Pub\\Cache '
      'and ~/.pub-cache.',
    );
    exitCode = 2;
    return;
  }

  final List<_LockedPackage> packages = _readLockFile(File('pubspec.lock'));
  final Map<String, int> counts = <String, int>{};
  final List<String> risky = <String>[];
  final List<String> lines = <String>[];
  int sdkCount = 0;

  for (final _LockedPackage package in packages) {
    if (_sdkPackages.contains(package.name)) {
      sdkCount++;
      continue;
    }
    final Directory directory = Directory(
      '${cache.path}/hosted/pub.dev/${package.directoryName}',
    );
    final String? text = directory.existsSync()
        ? _readLicenceText(directory)
        : null;
    if (text == null) {
      risky.add('${package.directoryName}: no LICENSE/COPYING file found');
      counts['NO LICENCE FILE'] = (counts['NO LICENCE FILE'] ?? 0) + 1;
      continue;
    }
    final String family = _classify(text);
    counts[family] = (counts[family] ?? 0) + 1;
    if (_forbiddenFamilies.contains(family)) {
      risky.add('${package.directoryName}: $family');
    }
    lines.add(
      '  ${package.name.padRight(28)} ${package.version.padRight(12)} $family',
    );
  }

  stdout.writeln('Licence scan (procedure: NOTICE.md §6)');
  final List<String> families = counts.keys.toList()
    ..sort((String a, String b) => counts[b]!.compareTo(counts[a]!));
  for (final String family in families) {
    stdout.writeln('  ${family.padRight(16)} ${counts[family]}');
  }
  stdout.writeln('  ${'Flutter SDK'.padRight(16)} $sdkCount');
  stdout.writeln(
    '  ${'total'.padRight(16)} ${counts.values.fold<int>(sdkCount, (int a, int b) => a + b)}',
  );
  if (listAll) {
    stdout.writeln('Packages:');
    lines.sort();
    for (final String line in lines) {
      stdout.writeln(line);
    }
  }
  if (risky.isEmpty) {
    stdout.writeln('Risky items: none.');
    stdout.writeln(
      'Compare the counts above with the baseline in NOTICE.md §5.',
    );
    exitCode = 0;
    return;
  }
  stdout.writeln('Risky items:');
  for (final String item in risky) {
    stdout.writeln('  $item');
  }
  stdout.writeln('Open an ADR before introducing any of these (NOTICE.md §6).');
  exitCode = 1;
}

/// Locates the pub cache root (`<cache>/hosted/pub.dev` lives inside it).
Directory? _locatePubCache() {
  final Map<String, String?> candidates = <String, String?>{
    'PUB_CACHE': Platform.environment['PUB_CACHE'],
    'LOCALAPPDATA': Platform.environment['LOCALAPPDATA'] == null
        ? null
        : '${Platform.environment['LOCALAPPDATA']}/Pub/Cache',
    'HOME': Platform.environment['HOME'] == null
        ? null
        : '${Platform.environment['HOME']}/.pub-cache',
    'USERPROFILE': Platform.environment['USERPROFILE'] == null
        ? null
        : '${Platform.environment['USERPROFILE']}/.pub-cache',
  };
  for (final String? candidate in candidates.values) {
    if (candidate == null || candidate.isEmpty) {
      continue;
    }
    final Directory directory = Directory(candidate);
    if (directory.existsSync()) {
      return directory;
    }
  }
  return null;
}

/// Reads package names and versions out of `pubspec.lock`.
List<_LockedPackage> _readLockFile(File lockFile) {
  final List<_LockedPackage> packages = <_LockedPackage>[];
  final RegExp namePattern = RegExp(r'^  ([a-z0-9_]+):\s*$');
  final RegExp fieldPattern = RegExp(r'^    (name|version):\s*"?([^"]+)"?\s*$');

  String? name;
  String? version;
  for (final String line in lockFile.readAsLinesSync()) {
    final Match? header = namePattern.firstMatch(line);
    if (header != null) {
      if (name != null && version != null) {
        packages.add(_LockedPackage(name, version));
      }
      name = header.group(1);
      version = null;
      continue;
    }
    final Match? field = fieldPattern.firstMatch(line);
    if (field != null && field.group(1) == 'version') {
      version = field.group(2);
    }
  }
  if (name != null && version != null) {
    packages.add(_LockedPackage(name, version));
  }
  return packages;
}

/// Returns the concatenated licence text of [directory], or `null` when it has
/// no `LICENSE*` / `COPYING*` file.
String? _readLicenceText(Directory directory) {
  final List<File> files =
      <File>[
          for (final FileSystemEntity entity in directory.listSync())
            if (entity is File && _isLicenceFile(entity.uri.pathSegments.last))
              entity,
        ]
        // 固定顺序，保证同一目录多次扫描得到相同文本。
        ..sort((File a, File b) => a.path.compareTo(b.path));

  if (files.isEmpty) {
    return null;
  }
  final StringBuffer buffer = StringBuffer();
  for (final File file in files) {
    buffer.write(file.readAsStringSync());
  }
  return buffer.toString();
}

/// Returns whether [fileName] looks like a licence file.
bool _isLicenceFile(String fileName) =>
    fileName.startsWith('LICENSE') || fileName.startsWith('COPYING');

/// Returns the licence family of [text]; see the library documentation for the
/// "first licence wins" and BSD third-clause rules.
String _classify(String text) {
  final String lower = text.toLowerCase();
  String? family;
  int earliest = -1;
  for (final MapEntry<String, String> marker in _familyMarkers.entries) {
    final int index = lower.indexOf(marker.value);
    if (index < 0) {
      continue;
    }
    if (earliest < 0 || index < earliest) {
      earliest = index;
      family = marker.key;
    }
  }
  if (family == null) {
    return 'UNKNOWN';
  }
  if (family == 'BSD') {
    return lower.contains(_bsdThirdClause) ? 'BSD-3-Clause' : 'BSD-2-Clause';
  }
  return family;
}
