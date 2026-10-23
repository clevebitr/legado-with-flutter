// coverage:ignore-file
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/features/reader/domain/repositories/speech_synthesizer.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// [SpeechSynthesizer] on top of `flutter_tts` (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 3).
///
/// The plugin's callbacks arrive as platform-channel messages, so the adapter turns them into
/// snapshots and never lets a channel exception reach the notifier. Only the engine's own display
/// names and locales are logged — never the spoken text (C-SEC-4).
///
/// Android implements `pause` as “stop and remember the remaining text”; a later [speak] of the
/// same text resumes from that point, which is why the notifier re-sends the **current chunk** on
/// resume instead of calling a separate resume method (the plugin has none).
final class FlutterTtsSpeechSynthesizer implements SpeechSynthesizer {
  /// Creates the adapter and installs the plugin's handlers.
  FlutterTtsSpeechSynthesizer({required this._logger}) {
    _tts.setStartHandler(() => _emit(const SpeechSnapshot(isSpeaking: true)));
    _tts.setCompletionHandler(
      () => _emit(const SpeechSnapshot(isSpeaking: false, isCompleted: true)),
    );
    _tts.setCancelHandler(() => _emit(const SpeechSnapshot()));
    _tts.setPauseHandler(
      () => _emit(const SpeechSnapshot(isSpeaking: true, isPaused: true)),
    );
    _tts.setContinueHandler(
      () => _emit(const SpeechSnapshot(isSpeaking: true)),
    );
    _tts.setProgressHandler(
      (String text, int start, int end, String word) => _emit(
        SpeechSnapshot(
          isSpeaking: true,
          spokenRange: SpeechRange(start: start, end: end),
        ),
      ),
    );
    _tts.setErrorHandler(_onError);
  }

  final AppLogger _logger;
  final FlutterTts _tts = FlutterTts();
  final StreamController<SpeechSnapshot> _snapshots =
      StreamController<SpeechSnapshot>.broadcast();
  bool _disposed = false;

  @override
  Stream<SpeechSnapshot> get snapshots => _snapshots.stream;

  @override
  Future<ParseResult<List<SpeechVoice>>> voices() async {
    try {
      final Object? raw = await _tts.getVoices;
      if (raw is! List<Object?>) {
        return const ParseSuccess<List<SpeechVoice>>(<SpeechVoice>[]);
      }
      final List<SpeechVoice> voices = <SpeechVoice>[];
      for (final Object? item in raw) {
        if (item is! Map<Object?, Object?>) {
          continue;
        }
        final Object? name = item['name'];
        final Object? locale = item['locale'];
        if (name is! String || name.isEmpty) {
          continue;
        }
        voices.add(
          SpeechVoice(name: name, locale: locale is String ? locale : ''),
        );
      }

      return ParseSuccess<List<SpeechVoice>>(voices);
    } on PlatformException catch (error, stackTrace) {
      _logger.warning(
        'Reading the system TTS voice list failed.',
        error,
        stackTrace,
      );

      return const ParseFailure<List<SpeechVoice>>(
        kind: ParseFailureKind.unsupportedRule,
        rulePath: 'reader.ttsVoices',
      );
    }
  }

  @override
  Future<ParseResult<void>> speak(
    String text, {
    required double rate,
    required double pitch,
    SpeechVoice? voice,
  }) async {
    try {
      // flutter_tts 的跨平台区间是 0.0–1.0，0.5 是正常语速；UI 用 1.0 表示正常。
      await _tts.setSpeechRate((rate * 0.5).clamp(0.1, 1.0));
      await _tts.setPitch(pitch.clamp(0.5, 2.0));
      if (voice != null && voice.name.isNotEmpty) {
        await _tts.setVoice(<String, String>{
          'name': voice.name,
          'locale': voice.locale,
        });
      }
      await _tts.speak(text);

      return const ParseResult<void>.success(null);
    } on PlatformException catch (error, stackTrace) {
      _logger.warning('Starting speech failed.', error, stackTrace);

      return const ParseResult<void>.failure(
        kind: ParseFailureKind.unsupportedRule,
        rulePath: 'reader.tts',
      );
    }
  }

  @override
  Future<ParseResult<void>> pause() => _guard(_tts.pause, 'pause');

  @override
  Future<ParseResult<void>> stop() => _guard(_tts.stop, 'stop');

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    try {
      await _tts.stop();
    } on PlatformException catch (error, stackTrace) {
      _logger.warning('Stopping speech on dispose failed.', error, stackTrace);
    }
    await _snapshots.close();
  }

  /// Runs one plugin command, turning a channel exception into a failure.
  Future<ParseResult<void>> _guard(
    Future<Object?> Function() command,
    String operation,
  ) async {
    try {
      await command();

      return const ParseResult<void>.success(null);
    } on PlatformException catch (error, stackTrace) {
      _logger.warning(
        'Speech command failed: operation=$operation',
        error,
        stackTrace,
      );

      return const ParseResult<void>.failure(
        kind: ParseFailureKind.unsupportedRule,
        rulePath: 'reader.tts',
      );
    }
  }

  /// Turns a platform error message into a failure snapshot.
  void _onError(Object? message) {
    _logger.warning('The system TTS engine reported an error: $message');
    _emit(
      const SpeechSnapshot(
        failure: ParseFailure<Never>(
          kind: ParseFailureKind.unsupportedRule,
          rulePath: 'reader.tts',
        ),
      ),
    );
  }

  /// Pushes [snapshot] to the notifier.
  void _emit(SpeechSnapshot snapshot) {
    if (_disposed) {
      return;
    }
    _snapshots.add(snapshot);
  }
}
