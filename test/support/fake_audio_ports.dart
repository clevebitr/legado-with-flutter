import 'dart:async';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/reader/domain/entities/audio_track.dart';
import 'package:flutter_reader/features/reader/domain/repositories/audio_playback_engine.dart';
import 'package:flutter_reader/features/reader/domain/repositories/audio_track_source.dart';
import 'package:flutter_reader/features/reader/domain/repositories/speech_synthesizer.dart';

/// In-memory [AudioTrackProvider] for the audio reader tests.
final class FakeAudioTrackProvider implements AudioTrackProvider {
  /// Tracks per chapter URL.
  final Map<String, List<ReaderAudioTrack>> tracks =
      <String, List<ReaderAudioTrack>>{};

  /// Failures per chapter URL; anything absent falls back to [tracks].
  final Map<String, ParseFailureKind> failures = <String, ParseFailureKind>{};

  /// The chapter URLs requested, in order.
  final List<String> requests = <String>[];

  @override
  Future<ParseResult<List<ReaderAudioTrack>>> fetch({
    required String sourceUrl,
    required String chapterUrl,
    String bookName = '',
    String chapterTitle = '',
  }) async {
    requests.add(chapterUrl);
    final ParseFailureKind? kind = failures[chapterUrl];
    if (kind != null) {
      return failureAt<List<ReaderAudioTrack>>(
        kind: kind,
        rulePath: 'reader.audioTracks',
      );
    }

    return ParseSuccess<List<ReaderAudioTrack>>(
      tracks[chapterUrl] ?? const <ReaderAudioTrack>[],
    );
  }
}

/// Scripted [AudioPlaybackEngine] for the audio reader tests.
///
/// It records every command and lets the test push snapshots through [emit], so a notifier test
/// never touches a native player (`docs/dev/testing.md` §4).
final class FakeAudioPlaybackEngine implements AudioPlaybackEngine {
  final StreamController<AudioPlaybackSnapshot> _snapshots =
      StreamController<AudioPlaybackSnapshot>.broadcast();

  /// URL of every [load], in order.
  final List<String> loadedUrls = <String>[];

  /// Headers of every [load], in order.
  final List<Map<String, String>> loadedHeaders = <Map<String, String>>[];

  /// Positions passed to [seek], in order.
  final List<Duration> seeks = <Duration>[];

  /// Speeds passed to [setSpeed], in order.
  final List<double> speeds = <double>[];

  /// How often [play] was called.
  int playCalls = 0;

  /// How often [pause] was called.
  int pauseCalls = 0;

  /// How often [dispose] was called.
  int disposeCalls = 0;

  /// When set, [load] fails with it instead of succeeding.
  ParseFailureKind? loadFailure;

  @override
  Stream<AudioPlaybackSnapshot> get snapshots => _snapshots.stream;

  /// Pushes one snapshot to the notifier.
  void emit(AudioPlaybackSnapshot snapshot) => _snapshots.add(snapshot);

  @override
  Future<ParseResult<void>> load({
    required String url,
    Map<String, String> headers = const <String, String>{},
  }) async {
    loadedUrls.add(url);
    loadedHeaders.add(headers);
    final ParseFailureKind? kind = loadFailure;
    if (kind != null) {
      return failureAt<void>(kind: kind, rulePath: 'reader.audioPlayer');
    }

    return const ParseResult<void>.success(null);
  }

  @override
  Future<ParseResult<void>> play() async {
    playCalls++;
    return const ParseResult<void>.success(null);
  }

  @override
  Future<ParseResult<void>> pause() async {
    pauseCalls++;
    return const ParseResult<void>.success(null);
  }

  @override
  Future<ParseResult<void>> seek(Duration position) async {
    seeks.add(position);
    return const ParseResult<void>.success(null);
  }

  @override
  Future<ParseResult<void>> setSpeed(double speed) async {
    speeds.add(speed);
    return const ParseResult<void>.success(null);
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    await _snapshots.close();
  }
}

/// Scripted [SpeechSynthesizer] for the read-aloud tests.
final class FakeSpeechSynthesizer implements SpeechSynthesizer {
  final StreamController<SpeechSnapshot> _snapshots =
      StreamController<SpeechSnapshot>.broadcast();

  /// Every text passed to [speak], in order.
  final List<String> spoken = <String>[];

  /// Rates passed to [speak], in order.
  final List<double> rates = <double>[];

  /// Voices passed to [speak], in order.
  final List<SpeechVoice?> spokenVoices = <SpeechVoice?>[];

  /// The voice list [voicesOf] answers with.
  List<SpeechVoice> voicesOf = const <SpeechVoice>[];

  /// When set, [speak] fails with it.
  ParseFailureKind? speakFailure;

  /// How often [pause] was called.
  int pauseCalls = 0;

  /// How often [stop] was called.
  int stopCalls = 0;

  @override
  Stream<SpeechSnapshot> get snapshots => _snapshots.stream;

  /// Pushes one snapshot to the notifier.
  void emit(SpeechSnapshot snapshot) => _snapshots.add(snapshot);

  @override
  Future<ParseResult<List<SpeechVoice>>> voices() async =>
      ParseSuccess<List<SpeechVoice>>(voicesOf);

  @override
  Future<ParseResult<void>> speak(
    String text, {
    required double rate,
    required double pitch,
    SpeechVoice? voice,
  }) async {
    spoken.add(text);
    rates.add(rate);
    spokenVoices.add(voice);
    final ParseFailureKind? kind = speakFailure;
    if (kind != null) {
      return failureAt<void>(kind: kind, rulePath: 'reader.tts');
    }

    return const ParseResult<void>.success(null);
  }

  @override
  Future<ParseResult<void>> pause() async {
    pauseCalls++;
    return const ParseResult<void>.success(null);
  }

  @override
  Future<ParseResult<void>> stop() async {
    stopCalls++;
    return const ParseResult<void>.success(null);
  }

  @override
  Future<void> dispose() async {
    await _snapshots.close();
  }
}
