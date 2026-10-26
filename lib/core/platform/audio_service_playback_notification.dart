// coverage:ignore-file
import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/core/platform/playback_notification.dart';

/// The method channel the Android activity listens on for the notification permission.
const String notificationPermissionChannel =
    'flutter_reader/notification_permission';

/// Picks the media-notification binding for this platform.
PlaybackNotification createPlaybackNotification({required AppLogger logger}) {
  if (Platform.isAndroid || Platform.isIOS || Platform.isWindows) {
    return AudioServicePlaybackNotification(logger: logger);
  }

  return const NoopPlaybackNotification();
}

/// [PlaybackNotification] backed by `audio_service`.
///
/// `AudioService.init` must run once per process, so the handler is a file-level singleton and
/// later attaches only replace its callbacks.
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

  // 共享 handler 首次使用时初始化 audio_service。
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
            // 暂停时不退出前台：Android 12+ 禁止后台重启前台服务，否则再次播放会抛异常。
            androidStopForegroundOnPause: false,
          ),
        );
    final _ReaderAudioHandler handler = await pending;
    _handler = handler;

    return handler;
  }

  Future<void> _requestNotificationPermission() async {
    if (!Platform.isAndroid) {
      return;
    }
    // 不等待授权结果：被拒也仍有可用的前台服务，阻塞播放比缺通知更糟。
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

// The handle the reader updates; it forwards to the shared handler's streams.
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

// audio_service 的 handler 只转发系统动作，播放器本身仍是朗读引擎。
final class _ReaderAudioHandler extends BaseAudioHandler {
  _ReaderAudioHandler(this.controls);

  // 当前朗读绑定的动作。
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
