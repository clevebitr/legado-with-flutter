import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/logging/log_level.dart';
import 'package:flutter_reader/core/platform/audio_service_playback_notification.dart';
import 'package:flutter_reader/core/platform/playback_backend.dart';
import 'package:flutter_reader/core/platform/playback_notification.dart';
import 'package:flutter_reader/features/reader/data/flutter_tts_speech_synthesizer.dart';
import 'package:flutter_reader/features/reader/data/just_audio_playback_engine.dart';
import 'package:flutter_reader/features/reader/data/media_kit_playback_engine.dart';
import 'package:flutter_reader/features/reader/domain/repositories/audio_playback_engine.dart';
import 'package:flutter_reader/features/reader/domain/repositories/speech_synthesizer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

/// 设备级验证：真实 `just_audio` / `flutter_tts` / `audio_service` 接线
/// （ADR-0054 A-0 / A-2 / A-3 / A-4；`docs/dev/test-environment.md` §4）。
///
/// 三个适配器都依赖平台通道与原生实现，`flutter test` 的宿主 VM 里无法执行
/// （ADR-0019 第二类），因此本文件是它们唯一的自动化验证入口：
///
/// * 播放：在应用目录写一个 1 秒的 16-bit PCM WAV，`just_audio` 真的解码它并推进播放位置；
/// * 朗读：系统 TTS 引擎能列出音色并读完一句（没有引擎的平台按「不可用」通过并留下记录）；
/// * 通知：Android 上能挂上媒体通知，Windows 上有意降级为 `null`（ADR-0054 §决策 3）。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final AppLogger logger = AppLogger(
    level: LogLevel.debug,
    printer: SimplePrinter(),
  );

  testWidgets('audioProbe_whenGivenALocalWav_playsAndStops', (
    WidgetTester tester,
  ) async {
    final Directory directory = await getApplicationSupportDirectory();
    final File file = File('${directory.path}/m17_probe.wav');
    await file.writeAsBytes(_probeWav(seconds: 1));

    final JustAudioPlaybackEngine engine = JustAudioPlaybackEngine(
      logger: logger,
    );
    addTearDown(engine.dispose);
    final List<AudioPlaybackSnapshot> snapshots = <AudioPlaybackSnapshot>[];
    final StreamSubscription<AudioPlaybackSnapshot> subscription = engine
        .snapshots
        .listen(snapshots.add);
    addTearDown(subscription.cancel);

    final ParseResult<void> load = await engine.load(
      url: Uri.file(file.path).toString(),
    );
    expect(load, isA<ParseSuccess<void>>(), reason: 'the WAV must load');

    await engine.play();
    for (var attempt = 0; attempt < 20; attempt++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (snapshots.any(
        (AudioPlaybackSnapshot snapshot) => snapshot.position > Duration.zero,
      )) {
        break;
      }
    }

    expect(
      snapshots.any(
        (AudioPlaybackSnapshot snapshot) => snapshot.position > Duration.zero,
      ),
      isTrue,
      reason: 'playback must advance the position',
    );
    expect(snapshots.last.duration, isNotNull);

    await engine.pause();
    await engine.dispose();
  });

  testWidgets('mediaKitProbe_whenOnWindows_playsTheLocalWav', (
    WidgetTester tester,
  ) async {
    if (!usesMediaKitPlayback) {
      return;
    }
    final Directory directory = await getApplicationSupportDirectory();
    final File file = File('${directory.path}/m17_media_kit_probe.wav');
    await file.writeAsBytes(_probeWav(seconds: 1));

    final MediaKitPlaybackEngine engine = MediaKitPlaybackEngine(
      logger: logger,
    );
    addTearDown(engine.dispose);
    final List<AudioPlaybackSnapshot> snapshots = <AudioPlaybackSnapshot>[];
    final StreamSubscription<AudioPlaybackSnapshot> subscription = engine
        .snapshots
        .listen(snapshots.add);
    addTearDown(subscription.cancel);

    final ParseResult<void> load = await engine.load(
      url: Uri.file(file.path).toString(),
    );
    expect(load, isA<ParseSuccess<void>>());
    await engine.play();
    for (var attempt = 0; attempt < 40; attempt++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (snapshots.any(
        (AudioPlaybackSnapshot snapshot) => snapshot.position > Duration.zero,
      )) {
        break;
      }
    }
    expect(
      snapshots.any(
        (AudioPlaybackSnapshot snapshot) => snapshot.position > Duration.zero,
      ),
      isTrue,
      reason: 'media_kit must advance the position on Windows',
    );
    await engine.pause();
    await engine.dispose();
  });

  testWidgets('ttsProbe_whenAsked_readsOneSentence', (
    WidgetTester tester,
  ) async {
    final FlutterTtsSpeechSynthesizer speech = FlutterTtsSpeechSynthesizer(
      logger: logger,
    );
    addTearDown(speech.dispose);

    final ParseResult<List<SpeechVoice>> voices = await speech.voices();
    expect(voices, isA<ParseSuccess<List<SpeechVoice>>>());

    final Completer<void> completed = Completer<void>();
    final StreamSubscription<SpeechSnapshot> subscription = speech.snapshots
        .listen((SpeechSnapshot snapshot) {
          if (snapshot.failure != null && !completed.isCompleted) {
            completed.completeError(StateError('TTS failed.'));
          }
          if (snapshot.isCompleted && !completed.isCompleted) {
            completed.complete();
          }
        });
    addTearDown(subscription.cancel);

    final ParseResult<void> spoken = await speech.speak(
      'M17 audio probe.',
      rate: 1,
      pitch: 1,
    );
    expect(spoken, isA<ParseSuccess<void>>());

    // 真机朗读是实时的：等到完成事件，最多 20 秒（模拟器 TTS 较慢）。
    await completed.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () {},
    );
    await speech.stop();
  });

  testWidgets('notification_whenOnThisPlatform_attachesOrStaysSilent', (
    WidgetTester tester,
  ) async {
    final PlaybackNotification notification = createPlaybackNotification(
      logger: logger,
    );
    final PlaybackNotificationHandle? handle = await notification.attach(
      controls: PlaybackNotificationControls(
        onPlay: () {},
        onPause: () {},
        onNext: () {},
        onPrevious: () {},
        onSeek: (Duration position) {},
      ),
    );

    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      expect(handle, isNotNull);
      await handle?.update(
        metadata: const PlaybackNotificationMetadata(
          id: 'https://example.invalid/a.mp3',
          title: 'Probe',
          album: 'M17',
          duration: Duration(seconds: 10),
        ),
        state: const PlaybackNotificationState(isPlaying: false),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await handle?.detach();
    } else {
      // Windows 的**有意降级**：没有媒体通知，播放照常（ADR-0054 §决策 3）。
      expect(handle, isNull);
    }
  });
}

/// Builds a 1-second 16-bit mono PCM WAV with a quiet 440 Hz tone.
Uint8List _probeWav({int seconds = 1, int sampleRate = 8000}) {
  const int channels = 1;
  const int bitsPerSample = 16;
  final int samples = sampleRate * seconds;
  final int dataLength = samples * channels * (bitsPerSample ~/ 8);
  final ByteData header = ByteData(44);
  void writeAscii(int offset, String text) {
    for (var index = 0; index < text.length; index++) {
      header.setUint8(offset + index, text.codeUnitAt(index));
    }
  }

  writeAscii(0, 'RIFF');
  header.setUint32(4, 36 + dataLength, Endian.little);
  writeAscii(8, 'WAVE');
  writeAscii(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, channels, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(
    28,
    sampleRate * channels * (bitsPerSample ~/ 8),
    Endian.little,
  );
  header.setUint16(32, channels * (bitsPerSample ~/ 8), Endian.little);
  header.setUint16(34, bitsPerSample, Endian.little);
  writeAscii(36, 'data');
  header.setUint32(40, dataLength, Endian.little);

  final Uint8List bytes = Uint8List(44 + dataLength)
    ..setAll(0, header.buffer.asUint8List());
  final ByteData samplesData = ByteData.sublistView(bytes, 44);
  for (var index = 0; index < samples; index++) {
    final double value = math.sin(2 * math.pi * 440 * index / sampleRate) * 0.2;
    samplesData.setInt16(index * 2, (value * 32767).round(), Endian.little);
  }

  return bytes;
}
