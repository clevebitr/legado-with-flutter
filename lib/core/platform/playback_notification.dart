import 'dart:async';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'playback_notification.freezed.dart';

/// What the media notification shows about the current track.
@freezed
abstract class PlaybackNotificationMetadata
    with _$PlaybackNotificationMetadata {
  /// Creates the notification metadata.
  const factory PlaybackNotificationMetadata({
    /// A stable identity for the track (the media URL).
    required String id,

    /// The chapter title.
    required String title,

    /// The book title.
    required String album,

    /// The track's duration, when known.
    Duration? duration,

    /// Cover art, when the reader has one.
    Uri? artUri,
  }) = _PlaybackNotificationMetadata;
}

/// The playback facts the notification and the lock screen render.
///
/// [position] is a discontinuity, not a tick: the system projects the playhead from it, so the
/// player only reports pauses, seeks and track changes.
@freezed
abstract class PlaybackNotificationState with _$PlaybackNotificationState {
  /// Creates a notification state.
  const factory PlaybackNotificationState({
    /// Whether audio is advancing.
    required bool isPlaying,

    /// Whether the player is buffering.
    @Default(false) bool isBuffering,

    /// Whether the track finished.
    @Default(false) bool isCompleted,

    /// The position the system projects from.
    @Default(Duration.zero) Duration position,

    /// The playback speed the system projects with.
    @Default(1.0) double speed,
  }) = _PlaybackNotificationState;
}

/// The actions the system controls (notification, lock screen, headset) invoke.
final class PlaybackNotificationControls {
  /// Creates the callbacks.
  const PlaybackNotificationControls({
    required this.onPlay,
    required this.onPause,
    required this.onNext,
    required this.onPrevious,
    required this.onSeek,
  });

  /// Resume or start playback.
  final void Function() onPlay;

  /// Pause playback.
  final void Function() onPause;

  /// Go to the next chapter.
  final void Function() onNext;

  /// Go to the previous chapter.
  final void Function() onPrevious;

  /// Seek to a position.
  final void Function(Duration position) onSeek;
}

/// A live notification binding the caller updates while it plays.
abstract interface class PlaybackNotificationHandle {
  /// Replaces what the notification shows.
  Future<void> update({
    required PlaybackNotificationMetadata metadata,
    required PlaybackNotificationState state,
  });

  /// Removes the notification and drops the controls.
  Future<void> detach();
}

/// Shows playback in the system notification / lock screen.
abstract interface class PlaybackNotification {
  /// Starts a notification session, or returns `null` when the platform has none.
  Future<PlaybackNotificationHandle?> attach({
    required PlaybackNotificationControls controls,
  });
}

/// The no-op binding used where no media notification exists (Windows, tests).
final class NoopPlaybackNotification implements PlaybackNotification {
  /// Creates the no-op binding.
  const NoopPlaybackNotification();

  @override
  Future<PlaybackNotificationHandle?> attach({
    required PlaybackNotificationControls controls,
  }) async => null;
}
