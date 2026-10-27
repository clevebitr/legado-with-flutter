import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/di/platform_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/log_file.dart';
import 'package:flutter_reader/core/platform/file_sharer.dart';
import 'package:flutter_reader/core/theme/app_theme.dart';
import 'package:flutter_reader/features/settings/presentation/pages/log_files_page.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

/// A [FileSharer] that records the log files the page handed over.
final class _RecordingFileSharer implements FileSharer {
  _RecordingFileSharer({this.isSupported = true, this.failure});

  @override
  final bool isSupported;

  final ParseFailure<bool>? failure;

  final List<ShareableFile> shared = <ShareableFile>[];
  String? subject;
  bool called = false;

  @override
  Future<ParseResult<bool>> share(
    List<ShareableFile> files, {
    String? subject,
  }) async {
    called = true;
    this.subject = subject;
    shared.addAll(files);
    final ParseFailure<bool>? error = failure;
    if (error != null) {
      return error;
    }

    return const ParseSuccess<bool>(true);
  }
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(LogFilesPage)));

/// Creates a temporary log directory and writes one file into it.
Future<Directory> _logsWithOneFile(WidgetTester tester) async {
  final Directory directory = await tester.runAsync(
    () => Directory.systemTemp.createTemp('log_files_page'),
  ) as Directory;
  addTearDown(() async {
    await directory.delete(recursive: true);
  });
  await tester.runAsync(
    () => File('${directory.path}/app-2026-10-27.log').writeAsString('line\n'),
  );

  return directory;
}

Future<_RecordingFileSharer> _pump(
  WidgetTester tester, {
  required Directory directory,
  bool supported = true,
  ParseFailure<bool>? failure,
}) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final _RecordingFileSharer sharer = _RecordingFileSharer(
    isSupported: supported,
    failure: failure,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        logFileProvider.overrideWithValue(LogFile(directory: directory)),
        fileSharerProvider.overrideWithValue(sharer),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildReaderTheme(fallbackLightColorScheme()),
        home: const LogFilesPage(),
      ),
    ),
  );
  // 读目录与 flush 都是真实文件 IO：假时钟等不到它们。
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pumpAndSettle();

  return sharer;
}

void main() {
  testWidgets('page_givenOneFile_sharesEveryFileOnDisk', (
    WidgetTester tester,
  ) async {
    final Directory directory = await _logsWithOneFile(tester);
    final _RecordingFileSharer sharer = await _pump(
      tester,
      directory: directory,
    );
    final AppLocalizations l10n = _l10n(tester);

    expect(find.text('app-2026-10-27.log'), findsOneWidget);
    expect(find.text(l10n.logFilesShareAll), findsOneWidget);

    await tester.tap(find.text(l10n.logFilesShareAll));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();

    expect(sharer.called, isTrue);
    expect(sharer.subject, l10n.logFilesTitle);
    final ShareableFile file = sharer.shared.single;
    expect(file.name, 'app-2026-10-27.log');
    expect(file.mimeType, 'text/plain');
    expect(file.path, '${directory.path}/app-2026-10-27.log');
    expect(file.bytes, isNull);
  });

  testWidgets('page_whenSharingFails_saysSo', (WidgetTester tester) async {
    final Directory directory = await _logsWithOneFile(tester);
    await _pump(
      tester,
      directory: directory,
      failure: const ParseFailure<bool>(
        kind: ParseFailureKind.parseFailed,
        rulePath: 'share',
      ),
    );
    final AppLocalizations l10n = _l10n(tester);

    await tester.tap(find.text(l10n.logFilesShareAll));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.logFilesShareFailed), findsOneWidget);
  });

  testWidgets('page_givenNoShareSheet_hidesEveryShareAction', (
    WidgetTester tester,
  ) async {
    final Directory directory = await _logsWithOneFile(tester);
    await _pump(tester, directory: directory, supported: false);
    final AppLocalizations l10n = _l10n(tester);

    expect(find.text(l10n.logFilesShareAll), findsNothing);
    expect(find.byTooltip(l10n.logFilesShareFile), findsNothing);
  });

  testWidgets('page_givenNoLogFile_hidesTheShareAllEntry', (
    WidgetTester tester,
  ) async {
    final Directory directory = await tester.runAsync(
      () => Directory.systemTemp.createTemp('log_files_page_empty'),
    ) as Directory;
    addTearDown(() async {
      await directory.delete(recursive: true);
    });
    await _pump(tester, directory: directory);
    final AppLocalizations l10n = _l10n(tester);

    expect(find.text(l10n.logFilesEmpty), findsOneWidget);
    expect(find.text(l10n.logFilesShareAll), findsNothing);
  });
}
