import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'audio_playback_engine.freezed.dart';

/// One observation of the audio player (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 4).
///
/// It is a snapshot, not a command: the engine pushes it whenever the underlying player reports a
/// new position, a new processing state or an error, and the notifier copies it into the UI state.
///
/// [failure] is used for errors that happen **after** a successful load (a dropped connection, a
/// codec the platform rejects): a plain stream error would tear down the listener and leave the
/// player silent with no way back, while a failure the UI can show has a retry.
@freezed
abstract class AudioPlaybackSnapshot with _$AudioPlaybackSnapshot {
  /// Creates a playback snapshot.
  const factory AudioPlaybackSnapshot({
    /// Whether audio is advancing right now.
    @Default(false) bool isPlaying,

    /// Whether the player is loading or buffering.
    @Default(false) bool isBuffering,

    /// Whether the stream reached its end.
    @Default(false) bool isCompleted,

    /// Position inside the current track.
    @Default(Duration.zero) Duration position,

    /// The track's duration, or `null` before the player decoded its metadata.
    Duration? duration,

    /// A playback failure the player reported after the load.
    ParseFailure<Never>? failure,
  }) = _AudioPlaybackSnapshot;
}

/// Plays audio tracks for the reader (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 3).
///
/// This is the reader's own port over `just_audio`: the feature never imports the plugin, which
/// lets every host test drive the notifier with a fake, and keeps the Windows / Android / iOS
/// differences inside the adapter (C-ARCH-2, C-PLT-1).
///
/// Every command returns [ParseResult] instead of throwing (C-ERR-1). [play] returns as soon as
/// playback is requested — waiting for the whole track would block the caller until it ends.
abstract interface class AudioPlaybackEngine {
  /// Snapshots of the player, emitted while it is prepared and playing.
  Stream<AudioPlaybackSnapshot> get snapshots;

  /// Loads [url] and prepares it for playback.
  ///
  /// [headers] are the source's own request headers; an empty map means “none”.
  Future<ParseResult<void>> load({
    required String url,
    Map<String, String> headers,
  });

  /// Starts or resumes playback.
  Future<ParseResult<void>> play();

  /// Pauses playback, keeping the position.
  Future<ParseResult<void>> pause();

  /// Moves the playhead to [position].
  Future<ParseResult<void>> seek(Duration position);

  /// Sets the playback speed (1.0 = normal).
  Future<ParseResult<void>> setSpeed(double speed);

  /// Releases the native player.
  Future<void> dispose();
}
