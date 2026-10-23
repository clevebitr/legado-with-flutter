// coverage:ignore-file
import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/platform/playback_notification.dart';

/// The method channel the Android activity listens on for the notification permission.
///
/// It is spelled once here and once in `MainActivity.kt`; the two sides are one contract, and no
/// Dart code outside this file may invoke it.
const String notificationPermissionChannel =
    'flutter_reader/notification_permission';

/// Picks the media-notification binding for this platform (C-PLT-1).
///
/// Android, iOS and Windows all show the current track in the system's own media surface:
/// `audio_service` covers the first two and `audio_service_win` implements its platform interface
/// with WinRT `SystemMediaTransportControls` (ADR-0057 §决策 4). Any other target gets the no-op
/// binding, so playback still works while the app is in front. This function is the **only** place
/// in the audio path that asks which platform it runs on.
PlaybackNotification createPlaybackNotification({required AppLogger logger}) {
  if (Platform.isAndroid || Platform.isIOS || Platform.isWindows) {
    return AudioServicePlaybackNotification(logger: logger);
  }

  return const NoopPlaybackNotification();
}

/// [PlaybackNotification] backed by `audio_service` (ADR-0054 §决策 3/4).
///
/// `AudioService.init` must run **once per process** and its handler outlives any page, so the
/// handler is a file-level singleton: opening the player a second time reuses it and only replaces
/// the callbacks. A second `init` would replace the engine and is the documented way to break
/// headset buttons.
final class AudioServicePlaybackNotification implements PlaybackNotification {
  /// Creates the binding.
  const AudioServicePlaybackNotification({required this._logger});

  final AppLogger _logger;

  static _ReaderAudioHandler? _handler;
  static Future<_ReaderAudioHandler>? _initialising;

  @override
  Future<PlaybackNotificationHandle?> attach({
    required PlaybackNotificationControls controls,
  }) async {
    await _requestNotificationPermission();
    final _ReaderAudioHandler handler = await _handlerOf(controls);
    handler.controls = controls;

    return _Handle(handler);
  }

  /// Returns the shared handler, initialising `audio_service` the first time.
  Future<_ReaderAudioHandler> _handlerOf(
    PlaybackNotificationControls controls,
  ) async {
    final _ReaderAudioHandler? ready = _handler;
    if (ready != null) {
      return ready;
    }
    final Future<_ReaderAudioHandler> pending = _initialising ??=
        AudioService.init(
          builder: () => _ReaderAudioHandler(controls),
          config: const AudioServiceConfig(
            androidNotificationChannelId: 'flutter_reader.playback',
            androidNotificationChannelName: 'Playback',
            androidNotificationOngoing: false,
            // 暂停时不退出前台：Android 12+ 禁止后台重启前台服务，退出后再按播放会抛
            // `ForegroundServiceStartNotAllowedException`（audio_service README 的同一建议）。
            androidStopForegroundOnPause: false,
          ),
        );
    final _ReaderAudioHandler handler = await pending;
    _handler = handler;

    return handler;
  }

  /// Asks Android 13+ for the notification permission, once per attach.
  ///
  /// The result is deliberately not awaited as a grant: a denied permission still leaves a working
  /// foreground service, and blocking playback on a dialog answer would be worse than a missing
  /// notification. A missing channel (host tests, other platforms) is a no-op.
  Future<void> _requestNotificationPermission() async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      await const MethodChannel(notificationPermissionChannel)
          .invokeMethod<void>('request');
    } on PlatformException catch (error, stackTrace) {
      _logger.warning(
        'Requesting the notification permission failed.',
        error,
        stackTrace,
      );
    } on MissingPluginException catch (error, stackTrace) {
      _logger.warning(
        'The notification permission channel is not bound.',
        error,
        stackTrace,
      );
    }
  }
}

/// The handle the reader updates; it forwards to the shared handler's streams.
final class _Handle implements PlaybackNotificationHandle {
  const _Handle(this._handler);

  final _ReaderAudioHandler _handler;

  @override
  Future<void> update({
    required PlaybackNotificationMetadata metadata,
    required PlaybackNotificationState state,
  }) async {
    _handler.mediaItem.add(
      MediaItem(
        id: metadata.id,
        title: metadata.title,
        album: metadata.album,
        duration: metadata.duration,
        artUri: metadata.artUri,
      ),
    );
    _handler.playbackState.add(
      PlaybackState(
        controls: <MediaControl>[
          MediaControl.skipToPrevious,
          if (state.isPlaying) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const <MediaAction>{MediaAction.seek},
        androidCompactActionIndices: const <int>[0, 1, 2],
        processingState: state.isCompleted
            ? AudioProcessingState.completed
            : state.isBuffering
            ? AudioProcessingState.buffering
            : AudioProcessingState.ready,
        playing: state.isPlaying,
        updatePosition: state.position,
        speed: state.speed,
      ),
    );
  }

  @override
  Future<void> detach() async {
    _handler.playbackState.add(
      PlaybackState(processingState: AudioProcessingState.idle, playing: false),
    );
    _handler.mediaItem.add(null);
  }
}

/// The `audio_service` handler: it owns nothing but the callbacks.
///
/// The player itself is the reader's own engine, so the handler only forwards system actions to
/// [controls] — the notification stays a **view** of the player, never a second source of truth.
final class _ReaderAudioHandler extends BaseAudioHandler {
  _ReaderAudioHandler(this.controls);

  /// The actions the current reader bound.
  PlaybackNotificationControls controls;

  @override
  Future<void> play() async => controls.onPlay();

  @override
  Future<void> pause() async => controls.onPause();

  @override
  Future<void> skipToNext() async => controls.onNext();

  @override
  Future<void> skipToPrevious() async => controls.onPrevious();

  @override
  Future<void> seek(Duration position) async => controls.onSeek(position);

  @override
  Future<void> stop() async {
    controls.onPause();
    await super.stop();
  }
}
