// coverage:ignore-file
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/features/reader/domain/repositories/audio_playback_engine.dart';
import 'package:just_audio/just_audio.dart';

/// [AudioPlaybackEngine] on top of `just_audio` (`docs/dev/roadmap.md` §3.10, ADR-0054 §决策 3).
///
/// `just_audio` is only imported here, in the reader's `data/` layer: the notifier, the page and
/// every host test see the port instead, so a platform that cannot play audio (or a test that must
/// not) is a different binding, not a different notifier.
///
/// The adapter never logs a full media URL: these addresses routinely carry signatures
/// (`?sign=...`), and C-SEC-4 forbids tokens in logs. Only the host survives into the log line.
final class JustAudioPlaybackEngine implements AudioPlaybackEngine {
  /// Creates the adapter and starts observing the player.
  JustAudioPlaybackEngine({required this._logger}) {
    _subscriptions.addAll(<StreamSubscription<Object?>>[
      _player.playerStateStream.listen((_) => _emit()),
      _player.positionStream.listen((_) => _emit()),
      _player.durationStream.listen((_) => _emit()),
      _player.playbackEventStream.listen((_) {}, onError: _emitFailure),
    ]);
  }

  final AppLogger _logger;
  final AudioPlayer _player = AudioPlayer();
  final StreamController<AudioPlaybackSnapshot> _snapshots =
      StreamController<AudioPlaybackSnapshot>.broadcast();
  final List<StreamSubscription<Object?>> _subscriptions =
      <StreamSubscription<Object?>>[];

  bool _disposed = false;

  /// The host of the last loaded track, used in log lines instead of the signed URL.
  String? _loadedHost;

  @override
  Stream<AudioPlaybackSnapshot> get snapshots => _snapshots.stream;

  @override
  Future<ParseResult<void>> load({
    required String url,
    Map<String, String> headers = const <String, String>{},
  }) async {
    _loadedHost = Uri.tryParse(url)?.host;
    try {
      await _player.setUrl(
        url,
        headers: headers.isEmpty ? null : headers,
        // 媒体地址可能是 http（C-SEC-2 的明文边界）：播放走平台原生栈而不是 `HttpClient`，
        // 是否允许明文由平台配置决定（Android 默认拒绝、Windows 允许）。
      );
      // `setUrl` 已经拿到时长，立刻推一帧，避免「0:00 / 0:00」的空档。
      _emit();
      return const ParseResult<void>.success(null);
    } on PlayerException catch (error, stackTrace) {
      return _failure(error, stackTrace, error.code.toString());
    } on PlayerInterruptedException catch (error, stackTrace) {
      // 被下一次 load 取代是正常竞态：记 warning，不弹失败。
      _logger.warning(
        'Audio load was interrupted: host=${_loadedHost ?? 'unknown'}',
        error,
        stackTrace,
      );
      return const ParseResult<void>.failure(
        kind: ParseFailureKind.parseFailed,
        rulePath: 'reader.audioPlayer',
      );
    } on PlatformException catch (error, stackTrace) {
      return _failure(error, stackTrace, error.code.toString());
    } on FormatException catch (error, stackTrace) {
      return _failure(error, stackTrace, 'format');
    }
  }

  @override
  Future<ParseResult<void>> play() async {
    // `AudioPlayer.play()` 的 Future 到播放**结束**才完成；这里只负责发起，
    // 结束与错误统一由 `playbackEventStream` 推给快照。
    unawaited(_player.play().then<void>((_) {}, onError: _emitFailure));
    return const ParseResult<void>.success(null);
  }

  @override
  Future<ParseResult<void>> pause() => _guard(_player.pause, 'pause');

  @override
  Future<ParseResult<void>> seek(Duration position) =>
      _guard(() => _player.seek(position), 'seek');

  @override
  Future<ParseResult<void>> setSpeed(double speed) =>
      _guard(() => _player.setSpeed(speed), 'speed');

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    for (final StreamSubscription<Object?> subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _player.dispose();
    await _snapshots.close();
  }

  /// Runs one player command, turning the plugin's exceptions into a failure.
  Future<ParseResult<void>> _guard(
    Future<void> Function() command,
    String operation,
  ) async {
    try {
      await command();
      _emit();
      return const ParseResult<void>.success(null);
    } on PlayerException catch (error, stackTrace) {
      return _failure(error, stackTrace, '$operation:${error.code}');
    } on PlatformException catch (error, stackTrace) {
      return _failure(error, stackTrace, '$operation:${error.code}');
    }
  }

  /// Pushes the current player values, optionally with a [failure].
  void _emit({ParseFailure<Never>? failure}) {
    if (_disposed) {
      return;
    }
    _snapshots.add(
      AudioPlaybackSnapshot(
        isPlaying: _player.playing,
        isBuffering:
            _player.processingState == ProcessingState.loading ||
            _player.processingState == ProcessingState.buffering,
        isCompleted: _player.processingState == ProcessingState.completed,
        position: _player.position,
        duration: _player.duration,
        failure: failure,
      ),
    );
  }

  /// Turns a runtime player error into a snapshot the UI can retry from.
  void _emitFailure(Object error, StackTrace? stackTrace) {
    _logger.warning(
      'Audio playback failed: host=${_loadedHost ?? 'unknown'}',
      error,
      stackTrace,
    );
    _emit(
      failure: const ParseFailure<Never>(
        kind: ParseFailureKind.parseFailed,
        rulePath: 'reader.audioPlayer',
      ),
    );
  }

  /// Logs [error] and returns the failure a command reports.
  ParseResult<void> _failure(
    Object error,
    StackTrace stackTrace,
    String operation,
  ) {
    _logger.warning(
      'Audio command failed: host=${_loadedHost ?? 'unknown'} '
      'operation=$operation',
      error,
      stackTrace,
    );

    return const ParseResult<void>.failure(
      kind: ParseFailureKind.parseFailed,
      rulePath: 'reader.audioPlayer',
    );
  }
}
