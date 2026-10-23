import 'package:flutter/material.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/theme/app_theme.dart';
import 'package:flutter_reader/features/reader/di.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_book.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_settings.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_chapter.dart';
import 'package:flutter_reader/features/reader/domain/repositories/speech_synthesizer.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/reader_tts_sheet.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../support/fake_audio_ports.dart';
import '../../../../support/fake_log_printer.dart';
import '../../../../support/fake_reader_ports.dart';
import '../../../../support/offline_corpus.dart';

/// The book every case opens.
const ReaderBook _book = ReaderBook(
  sourceUrl: 'https://source.test',
  bookUrl: 'https://source.test/book/1',
  name: '剑来',
  tocUrl: 'https://source.test/book/1/toc',
);

/// The chapters the fake list answers with.
const List<ReadingChapter> _chapters = <ReadingChapter>[
  ReadingChapter(title: '第1章', url: 'https://source.test/1.html'),
  ReadingChapter(title: '第2章', url: 'https://source.test/2.html'),
];

/// The collaborators one case wires together.
typedef _Fixture = ({
  ProviderContainer container,
  FakeSpeechSynthesizer speech,
  FakeReaderSettingsRepository settings,
});

/// Builds a container around the speech double.
_Fixture _fixture({ParseFailureKind? speakFailure}) {
  final FakeChapterListProvider chapters = FakeChapterListProvider()
    ..chapters = _chapters;
  final FakeChapterContentProvider content = FakeChapterContentProvider()
    ..bodies['https://source.test/1.html'] = '第一句。第二句。'
    ..bodies['https://source.test/2.html'] = '第二章内容。';
  final FakeReaderSettingsRepository settings = FakeReaderSettingsRepository(
    initial: ReaderSettings.defaults,
  );
  final FakeSpeechSynthesizer speech = FakeSpeechSynthesizer()
    ..voicesOf = const <SpeechVoice>[
      SpeechVoice(name: 'Microsoft Huihui', locale: 'zh-CN'),
    ]
    ..speakFailure = speakFailure;
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      readerChapterListProvider.overrideWithValue(chapters),
      readerChapterContentProvider.overrideWithValue(content),
      readerProgressStoreProvider.overrideWithValue(FakeReadingProgressStore()),
      readerSettingsRepositoryProvider.overrideWith(
        (Ref ref) async => settings,
      ),
      speechSynthesizerProvider.overrideWithValue(speech),
      appLoggerProvider.overrideWithValue(
        AppLogger(level: LogLevel.debug, printer: FakeLogPrinter()),
      ),
    ],
  );
  addTearDown(container.dispose);

  return (container: container, speech: speech, settings: settings);
}

/// Pumps the sheet on top of [fixture].
Future<void> _pump(WidgetTester tester, _Fixture fixture) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: fixture.container,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildReaderTheme(fallbackLightColorScheme()),
        home: const Scaffold(
          body: SingleChildScrollView(child: ReaderTtsSheet(book: _book)),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

/// The strings the sheet renders.
AppLocalizations _l10n(WidgetTester tester) =>
    localizationOf(tester, find.byType(ReaderTtsSheet));

void main() {
  group('ReaderTtsSheet', () {
    testWidgets('build_givenDefaultSettings_showsTheControls', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture();

      await _pump(tester, fixture);

      expect(find.text(_l10n(tester).readerTtsTitle), findsOneWidget);
      expect(find.text(_l10n(tester).readerTtsStart), findsOneWidget);
      expect(find.byType(Slider), findsNWidgets(2));
      expect(find.text(_l10n(tester).readerTtsSystemVoice), findsOneWidget);
      expect(find.text(_l10n(tester).readerTtsKeepOnExit), findsOneWidget);
    });

    testWidgets('start_whenTapped_speaksTheChapter', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture();
      await _pump(tester, fixture);

      await tester.tap(find.text(_l10n(tester).readerTtsStart));
      await tester.pump();
      await tester.pump();

      expect(fixture.speech.spoken, <String>['第一句。第二句。']);
      expect(find.text(_l10n(tester).readerTtsPause), findsOneWidget);
    });

    testWidgets('pause_whenTapped_pausesTheEngine', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture();
      await _pump(tester, fixture);
      await tester.tap(find.text(_l10n(tester).readerTtsStart));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text(_l10n(tester).readerTtsPause));
      await tester.pump();

      expect(fixture.speech.pauseCalls, 1);
      expect(find.text(_l10n(tester).readerTtsResume), findsOneWidget);
    });

    testWidgets('stop_whenTapped_stopsTheEngine', (WidgetTester tester) async {
      final _Fixture fixture = _fixture();
      await _pump(tester, fixture);
      await tester.tap(find.text(_l10n(tester).readerTtsStart));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text(_l10n(tester).readerTtsStop));
      await tester.pump();

      expect(fixture.speech.stopCalls, 1);
      expect(find.text(_l10n(tester).readerTtsStart), findsOneWidget);
    });

    testWidgets('keepOnExit_whenToggled_persistsTheSwitch', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture();
      await _pump(tester, fixture);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();

      expect(fixture.settings.stored.stopTtsOnExit, isFalse);
    });

    testWidgets('voiceDropdown_whenAvoiceIsPicked_persistsIt', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture();
      await _pump(tester, fixture);

      await tester.tap(find.byType(DropdownButton<SpeechVoice>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Microsoft Huihui (zh-CN)').last);
      await tester.pumpAndSettle();

      expect(fixture.settings.stored.ttsVoiceName, 'Microsoft Huihui');
      expect(fixture.settings.stored.ttsVoiceLocale, 'zh-CN');
    });

    testWidgets('start_givenASpeakFailure_showsTheFailure', (
      WidgetTester tester,
    ) async {
      final _Fixture fixture = _fixture(
        speakFailure: ParseFailureKind.unsupportedRule,
      );
      await _pump(tester, fixture);

      await tester.tap(find.text(_l10n(tester).readerTtsStart));
      await tester.pump();
      await tester.pump();

      expect(find.text(_l10n(tester).readerTtsFailed), findsOneWidget);
    });
  });
}
