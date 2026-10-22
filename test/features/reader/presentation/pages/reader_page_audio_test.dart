import 'package:flutter/material.dart';
import 'package:flutter_reader/core/di/clock_provider.dart';
import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/platform/playback_notification.dart';
import 'package:flutter_reader/core/theme/app_theme.dart';
import 'package:flutter_reader/features/reader/di.dart';
import 'package:flutter_reader/features/reader/domain/entities/audio_track.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_book.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_media_kind.dart';
import 'package:flutter_reader/features/reader/domain/entities/reader_settings.dart';
import 'package:flutter_reader/features/reader/domain/entities/reading_chapter.dart';
import 'package:flutter_reader/features/reader/domain/repositories/source_kind_provider.dart';
import 'package:flutter_reader/features/reader/presentation/pages/reader_page.dart';
import 'package:flutter_reader/features/reader/presentation/widgets/audio_reader_view.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../support/fake_audio_ports.dart';
import '../../../../support/fake_clock.dart';
import '../../../../support/fake_log_printer.dart';
import '../../../../support/fake_reader_ports.dart';

/// The book every case opens.
const ReaderBook _book = ReaderBook(
  sourceUrl: 'https://source.test',
  bookUrl: 'https://source.test/book/1',
  name: '听书',
  tocUrl: 'https://source.test/book/1/toc',
);

/// The chapters the fake list answers with.
const List<ReadingChapter> _chapters = <ReadingChapter>[
  ReadingChapter(title: '第1章', url: 'https://source.test/1.html'),
  ReadingChapter(title: '第2章', url: 'https://source.test/2.html'),
];

/// A [SourceKindProvider] that always answers [kind].
final class _FakeSourceKind implements SourceKindProvider {
  const _FakeSourceKind(this.kind);

  final ReaderMediaKind kind;

  @override
  Future<ReaderMediaKind> kindOf({required String sourceUrl}) async => kind;
}

/// Builds a container for one reader page case.
ProviderContainer _fixture({required ReaderMediaKind kind}) {
  final FakeChapterListProvider chapters = FakeChapterListProvider()
    ..chapters = _chapters;
  final FakeChapterContentProvider content = FakeChapterContentProvider()
    ..bodies['https://source.test/1.html'] = '第一章正文'
    ..bodies['https://source.test/2.html'] = '第二章正文';
  final FakeAudioTrackProvider tracks = FakeAudioTrackProvider()
    ..tracks['https://source.test/1.html'] = <ReaderAudioTrack>[
      const ReaderAudioTrack(url: 'https://cdn.test/1.mp3'),
    ]
    ..tracks['https://source.test/2.html'] = <ReaderAudioTrack>[
      const ReaderAudioTrack(url: 'https://cdn.test/2.mp3'),
    ];
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      readerChapterListProvider.overrideWithValue(chapters),
      readerChapterContentProvider.overrideWithValue(content),
      readerProgressStoreProvider.overrideWithValue(FakeReadingProgressStore()),
      readerSettingsRepositoryProvider.overrideWith(
        (Ref ref) async =>
            FakeReaderSettingsRepository(initial: ReaderSettings.defaults),
      ),
      readerSourceKindProvider.overrideWithValue(_FakeSourceKind(kind)),
      readerAudioTrackProvider.overrideWithValue(tracks),
      audioPlaybackEngineProvider.overrideWithValue(FakeAudioPlaybackEngine()),
      playbackNotificationProvider.overrideWithValue(
        const NoopPlaybackNotification(),
      ),
      clockProvider.overrideWithValue(FakeClock()),
      appLoggerProvider.overrideWithValue(
        AppLogger(level: LogLevel.debug, printer: FakeLogPrinter()),
      ),
    ],
  );
  addTearDown(container.dispose);

  return container;
}

/// Pumps the reader page.
Future<void> _pump(WidgetTester tester, ProviderContainer container) async {
  tester.view.physicalSize = const Size(1200, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildReaderTheme(fallbackLightColorScheme()),
        home: const ReaderPage(book: _book),
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  group('ReaderPage dispatch', () {
    testWidgets('build_givenAnAudioSource_opensThePlayer', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _fixture(kind: ReaderMediaKind.audio));

      expect(find.byType(AudioReaderView), findsOneWidget);
      // 音频书不去抓正文：文本视图根本不存在。
      expect(find.textContaining('第一章正文'), findsNothing);
    });

    testWidgets('build_givenATextSource_keepsTheTextReader', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _fixture(kind: ReaderMediaKind.text));

      expect(find.byType(AudioReaderView), findsNothing);
      expect(find.textContaining('第一章正文'), findsOneWidget);
    });
  });
}
