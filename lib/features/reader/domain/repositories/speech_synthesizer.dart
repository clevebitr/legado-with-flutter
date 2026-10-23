import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'speech_synthesizer.freezed.dart';

/// One voice the system TTS engine offers (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 5).
///
/// [locale] is what the platform reports (for example `zh-CN`); it is part of the identity because
/// two engines may ship a voice with the same display name under different locales.
@freezed
abstract class SpeechVoice with _$SpeechVoice {
  /// Creates one voice.
  const factory SpeechVoice({
    /// The display name the system reports.
    required String name,

    /// The voice's locale tag, or an empty string when the platform omits it.
    @Default('') String locale,
  }) = _SpeechVoice;
}

/// A character range inside the text one utterance carries (`ADR-0062 §决策 5`).
///
/// The engine reports progress as offsets of the **string it was given**, so the notifier adds the
/// current segment's start to turn it into an offset of the chapter body.
@freezed
abstract class SpeechRange with _$SpeechRange {
  /// Creates a range.
  const factory SpeechRange({
    /// The offset of the first character being voiced.
    required int start,

    /// The offset just past the last character being voiced.
    required int end,
  }) = _SpeechRange;
}

/// One observation of the speech engine (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 5).
@freezed
abstract class SpeechSnapshot with _$SpeechSnapshot {
  /// Creates a speech snapshot.
  const factory SpeechSnapshot({
    /// Whether the engine is speaking (or paused, which the platform still reports as active).
    @Default(false) bool isSpeaking,

    /// Whether the engine is paused.
    @Default(false) bool isPaused,

    /// Whether the current utterance finished.
    @Default(false) bool isCompleted,

    /// The range of the current utterance the engine is voicing right now, or `null`.
    ///
    /// Android and iOS report it; a platform without progress support leaves it `null`, and the
    /// highlight then covers the whole utterance (ADR-0062 §决策 5).
    SpeechRange? spokenRange,

    /// An engine error to show instead of the normal controls.
    ParseFailure<Never>? failure,
  }) = _SpeechSnapshot;
}

/// Reads a chapter aloud with the platform's TTS engine (`docs/dev/roadmap.md` §3.10).
///
/// The reader owns this port so the feature never imports `flutter_tts` (C-ARCH-2). Commands return
/// [ParseResult] like every other failing operation (C-ERR-1); the notifier turns them into state.
///
/// [speak] speaks **one chunk**. Splitting a chapter into chunks belongs to the notifier: the
/// engine's own queue is platform specific, and Android truncates very long utterances.
abstract interface class SpeechSynthesizer {
  /// Snapshots of the engine, emitted on start / pause / completion / error.
  Stream<SpeechSnapshot> get snapshots;

  /// The voices this engine exposes, or an empty list when the platform has no voice list.
  Future<ParseResult<List<SpeechVoice>>> voices();

  /// Speaks [text] with [rate] (1.0 = normal), [pitch] (1.0 = normal) and [voice].
  Future<ParseResult<void>> speak(
    String text, {
    required double rate,
    required double pitch,
    SpeechVoice? voice,
  });

  /// Pauses the current utterance.
  Future<ParseResult<void>> pause();

  /// Stops the current utterance and drops the queue.
  Future<ParseResult<void>> stop();

  /// Releases the engine.
  Future<void> dispose();
}
