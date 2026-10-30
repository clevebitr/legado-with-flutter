import 'dart:async';
import 'dart:io';

import 'package:flutter_reader/core/utils/clock.dart';

// 私有字段不能做具名初始化形参（Dart 限制），手写赋值是必要的。
// ignore_for_file: prefer_initializing_formals

/// One log file on disk.
final class LogFileInfo {
  /// Creates the description of [file].
  const LogFileInfo({
    required this.file,
    required this.bytes,
    required this.day,
  });

  /// The file itself.
  final File file;

  /// Its size in bytes.
  final int bytes;

  /// The day the file covers (from its name, `app-YYYY-MM-DD.log`).
  final DateTime day;
}

/// The on-disk log, rotated **per day**, with a bounded total size.
///
/// Three platforms, one rule set (`ADR-0082`): the directory comes from the platform
/// (`getApplicationSupportDirectory`), one file per day named `app-YYYY-MM-DD.log`, the newest
/// [retention] worth of days kept, and the whole directory capped at [maxTotalBytes] — oldest
/// files go first. Without the cap a runaway source (an `@js:` loop that logs every replay pass)
/// would grow the file until the device complains; the log must never be the reason an app dies.
///
/// Writes are serialized through one queue and appended, so a slow disk cannot reorder lines, and
/// [appendSync] exists for the crash path where there is no time left to await anything.
final class LogFile {
  /// Creates the log inside [directory] (created when missing).
  LogFile({
    required this.directory,
    Clock clock = const SystemClock(),
    this.retention = const Duration(days: 7),
    this.maxTotalBytes = 20 * 1024 * 1024,
  }) : _clock = clock;

  /// The folder the log files live in.
  final Directory directory;

  /// How many days of files are kept.
  final Duration retention;

  /// The cap on the sum of every file's size.
  final int maxTotalBytes;

  final Clock _clock;

  Future<void> _pending = Future<void>.value();

  /// The file the next line goes to.
  File get currentFile => File('${directory.path}/${_nameOf(_clock.now())}');

  /// The directory path, for the diagnostics page.
  String get directoryPath => directory.path;

  /// Appends [line] (no newline needed) to today's file.
  ///
  /// Failures are swallowed on purpose: a log write must never surface as an application error.
  /// The line is dropped instead, which is the same trade the cache stores make.
  Future<void> append(String line) {
    _pending = _pending.then((_) => _write(line));

    return _pending;
  }

  /// Waits until every queued line reached the disk.
  ///
  /// Used by tests and by the diagnostics page right before it reads the file it is showing.
  Future<void> flush() => _pending;

  /// Appends [line] synchronously, for the crash path.
  void appendSync(String line) {
    try {
      directory.createSync(recursive: true);
      currentFile.writeAsStringSync(
        '$line\n',
        mode: FileMode.append,
        flush: true,
      );
    } on FileSystemException {
      // 崩溃路径上已经没有第二次机会：写不进去就丢掉这一行。
    }
  }

  /// Deletes files older than [retention], then the oldest ones until the directory fits
  /// [maxTotalBytes].
  Future<void> prune() async {
    final List<LogFileInfo> files = await list();
    if (files.isEmpty) {
      return;
    }
    final DateTime oldestKept = _dayOf(_clock.now().subtract(retention));
    final List<LogFileInfo> kept = <LogFileInfo>[];
    for (final LogFileInfo info in files) {
      if (info.day.isBefore(oldestKept)) {
        await _delete(info.file);
      } else {
        kept.add(info);
      }
    }
    var total = kept.fold<int>(
      0,
      (int sum, LogFileInfo info) => sum + info.bytes,
    );
    // 列表按日期升序，从最早的开始删，最新那份永远留着。
    for (final LogFileInfo info in kept) {
      if (total <= maxTotalBytes || info.file.path == currentFile.path) {
        continue;
      }
      await _delete(info.file);
      total -= info.bytes;
    }
  }

  /// Every log file, oldest first.
  Future<List<LogFileInfo>> list() async {
    if (!directory.existsSync()) {
      return const <LogFileInfo>[];
    }
    final List<LogFileInfo> files = <LogFileInfo>[];
    await for (final FileSystemEntity entity in directory.list()) {
      if (entity is! File) {
        continue;
      }
      final DateTime? day = _dayOfFile(entity.path);
      if (day == null) {
        continue;
      }
      files.add(
        LogFileInfo(file: entity, bytes: await entity.length(), day: day),
      );
    }
    files.sort((LogFileInfo a, LogFileInfo b) => a.day.compareTo(b.day));

    return files;
  }

  /// Deletes every log file and answers how many went away.
  Future<int> clear() async {
    final List<LogFileInfo> files = await list();
    for (final LogFileInfo info in files) {
      await _delete(info.file);
    }

    return files.length;
  }

  Future<void> _write(String line) async {
    try {
      await directory.create(recursive: true);
      await currentFile.writeAsString('$line\n', mode: FileMode.append);
    } on FileSystemException {
      // 与 appendSync 同一口径：日志写失败不影响应用。
    }
  }

  Future<void> _delete(File file) async {
    try {
      await file.delete();
    } on FileSystemException {
      // 删不掉只是占空间，不该抛给调用方。
    }
  }

  static String _nameOf(DateTime day) =>
      'app-${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}.log';

  static final RegExp _name = RegExp(r'app-(\d{4})-(\d{2})-(\d{2})\.log$');

  static DateTime? _dayOfFile(String path) {
    final RegExpMatch? match = _name.firstMatch(path);
    if (match == null) {
      return null;
    }

    return DateTime.tryParse(
      '${match.group(1)}-${match.group(2)}-${match.group(3)}',
    );
  }

  static DateTime _dayOf(DateTime moment) =>
      DateTime(moment.year, moment.month, moment.day);
}
