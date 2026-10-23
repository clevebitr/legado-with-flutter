// coverage:ignore-file
import 'dart:async';

import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';
import 'package:flutter_reader/features/reader/domain/repositories/audio_playback_engine.dart';
import 'package:media_kit/media_kit.dart';

/// [AudioPlaybackEngine] on top of `media_kit` for Windows (ADR-0056).
///
/// `just_audio_windows` stops at position 0 for some real streams and can crash the native
/// plugin on a failed load (M17 census). `media_kit` (mpv) decodes the same streams, so Windows
/// uses it while Android / iOS keep `just_audio`. The choice itself lives in
/// `core/platform/playback_backend.dart`; this file only knows `media_kit`.
///
/// The adapter never logs a media URL (signed query strings are tokens, C-SEC-4); only the host.
final class MediaKitPlaybackEngine implements AudioPlaybackEngine {
  /// Creates the adapter and starts observing the player.
  MediaKitPlaybackEngine({required this._logger}) {
    _ensureInitialized();
    _player = Player();
    _subscriptions.addAll(<StreamSubscription<Object?>>[
      _player.stream.position.listen((Duration position) {
        if (position > Duration.zero) {
          _sawProgress = true;
          _stall?.cancel();
        }
        _emit();
      }),
      _player.stream.duration.listen((_) => _emit()),
      _player.stream.playing.listen((_) => _emit()),
      _player.stream.completed.listen((_) => _emit()),
      _player.stream.buffering.listen((_) => _emit()),
      _player.stream.error.listen((_) => _emitFailure()),
    ]);
  }

  final AppLogger _logger;
  late final Player _player;
  final StreamController<AudioPlaybackSnapshot> _snapshots =
      StreamController<AudioPlaybackSnapshot>.broadcast();
  final List<StreamSubscription<Object?>> _subscriptions =
      <StreamSubscription<Object?>>[];

  static bool _initialized = false;
  bool _disposed = false;
  bool _sawProgress = false;
  Timer? _stall;

  /// Initialises the native mpv bindings once per process.
  static void _ensureInitialized() {
    if (_initialized) {
      return;
    }
    MediaKit.ensureInitialized();
    _initialized = true;
  }

  @override
  Stream<AudioPlaybackSnapshot> get snapshots => _snapshots.stream;

  @override
  Future<ParseResult<void>> load({
    required String url,
    Map<String, String> headers = const <String, String>{},
  }) async {
    _sawProgress = false;
    _stall?.cancel();
    try {
      await _player.open(
        Media(url, httpHeaders: headers.isEmpty ? null : headers),
        play: false,
      );
      _emit();
      return const ParseResult<void>.success(null);
    } on Exception catch (error, stackTrace) {
      // media_kit 没有导出具名异常：这是原生播放器的边界，失败统一转成 ParseFailure（ADR-0056）。
      _logger.warning(
        'MediaKit load failed: host=${_hostOf(url)}',
        error,
        stackTrace,
      );
      return const ParseResult<void>.failure(
        kind: ParseFailureKind.parseFailed,
        rulePath: 'reader.audioPlayer',
      );
    }
  }

  @override
  Future<ParseResult<void>> play() async {
    unawaited(_player.play().then<void>((_) {}, onError: _emitFailure));
    _startStallWatch();
    return const ParseResult<void>.success(null);
  }

  @override
  Future<ParseResult<void>> pause() async {
    _stall?.cancel();
    return _guard(_player.pause, 'pause');
  }

  @override
  Future<ParseResult<void>> seek(Duration position) =>
      _guard(() => _player.seek(position), 'seek');

  @override
  Future<ParseResult<void>> setSpeed(double speed) =>
      _guard(() => _player.setRate(speed), 'rate');

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _stall?.cancel();
    for (final StreamSubscription<Object?> subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _player.dispose();
    await _snapshots.close();
  }

  /// After six seconds of “playing” with no progress, report a retryable failure.
  ///
  /// This is the graceful end of the position-0 bug: the UI shows a failure and offers a retry
  /// instead of a silent 0:00 player. A stream that starts later than six seconds is rare; the
  /// timer is cancelled as soon as one position frame above zero is seen.
  void _startStallWatch() {
    _stall?.cancel();
    _stall = Timer(const Duration(seconds: 6), () {
      if (_disposed || _sawProgress || !_player.state.playing) {
        return;
      }
      _emitFailure();
    });
  }

  /// Runs one player command, turning a platform exception into a failure.
  Future<ParseResult<void>> _guard(
    Future<void> Function() command,
    String operation,
  ) async {
    try {
      await command();
      _emit();
      return const ParseResult<void>.success(null);
    } on Exception catch (error, stackTrace) {
      _logger.warning(
        'MediaKit command failed: operation=$operation',
        error,
        stackTrace,
      );
      return const ParseResult<void>.failure(
        kind: ParseFailureKind.parseFailed,
        rulePath: 'reader.audioPlayer',
      );
    }
  }

  /// Pushes the current player values, optionally with a [failure].
  void _emit({ParseFailure<Never>? failure}) {
    if (_disposed) {
      return;
    }
    final PlayerState state = _player.state;
    _snapshots.add(
      AudioPlaybackSnapshot(
        isPlaying: state.playing,
        isBuffering: state.buffering,
        isCompleted: state.completed,
        position: state.position,
        duration: state.duration == Duration.zero ? null : state.duration,
        failure: failure,
      ),
    );
  }

  /// Turns an mpv error into a snapshot the UI can retry from.
  void _emitFailure([Object? error, StackTrace? stackTrace]) {
    _stall?.cancel();
    _logger.warning('MediaKit playback failed.', error, stackTrace);
    _emit(
      failure: const ParseFailure<Never>(
        kind: ParseFailureKind.parseFailed,
        rulePath: 'reader.audioPlayer',
      ),
    );
  }

  /// The host of [url], which is safe to log when the signed query is dropped.
  static String _hostOf(String url) => Uri.tryParse(url)?.host ?? 'unknown';
}
