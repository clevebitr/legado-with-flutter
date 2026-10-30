import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_reader/core/logging/app_logger.dart';

/// The channel the Android side listens on for the batch check's notification.
const String sourceCheckNotificationChannelName =
    'flutter_reader/source_check_notification';

/// The localized strings the system notification shows.
///
/// The port never builds user-visible text itself (C-UI-5): the caller that has
/// `AppLocalizations` supplies the title and the two formatters, so the notification follows the
/// app's language exactly like the in-app progress does.
final class SourceCheckNotificationText {
  /// Creates one localized set.
  const SourceCheckNotificationText({
    required this.channelName,
    required this.title,
    required this.progress,
    required this.finished,
  });

  /// Name of the Android notification channel (shown in system settings).
  final String channelName;

  /// Title of the ongoing notification.
  final String title;

  /// The `{name} · {completed}/{total}` line for the source being checked.
  final String Function(String sourceName, int completed, int total) progress;

  /// The `finished` line, shown once with the batch's verdict counts.
  final String Function(int succeeded, int failed) finished;
}

/// Shows a batch check's progress as a system notification on platforms that have one.
///
/// Upstream runs `BookSourceCheckService` as a foreground service with an ongoing notification
/// (current source, completed / total, progress bar). This port is that notification, without the
/// service: the check still runs in the app's isolate, so the notification is a *status* surface
/// (visible while backgrounded) rather than the thing keeping the process alive.
abstract interface class SourceCheckNotification {
  /// Shows or updates the ongoing progress notification.
  Future<void> showProgress({
    required SourceCheckNotificationText text,
    required String sourceName,
    required int completed,
    required int total,
  });

  /// Replaces the ongoing notification with the batch's verdict.
  Future<void> showFinished({
    required SourceCheckNotificationText text,
    required int succeeded,
    required int failed,
  });

  /// Removes the notification (cancelled batch / app not showing one).
  Future<void> cancel();
}

/// The [SourceCheckNotification] for platforms without one (Windows, iOS, tests).
final class NoopSourceCheckNotification implements SourceCheckNotification {
  /// Creates the no-op port.
  const NoopSourceCheckNotification();

  @override
  Future<void> showProgress({
    required SourceCheckNotificationText text,
    required String sourceName,
    required int completed,
    required int total,
  }) async {}

  @override
  Future<void> showFinished({
    required SourceCheckNotificationText text,
    required int succeeded,
    required int failed,
  }) async {}

  @override
  Future<void> cancel() async {}
}

/// Android [SourceCheckNotification] backed by `MainActivity`'s notification manager.
///
/// Every call degrades to a no-op when the channel is missing (test host / an old native build) or
/// when the platform rejects it — a notification must never cost the check itself.
final class MethodChannelSourceCheckNotification
    implements SourceCheckNotification {
  /// Creates the channel-backed port.
  MethodChannelSourceCheckNotification({
    required this.logger,
    MethodChannel? channel,
  }) : _channel =
           channel ?? const MethodChannel(sourceCheckNotificationChannelName);

  /// The logger a failed platform call is reported with.
  final AppLogger logger;

  final MethodChannel _channel;

  // 平台一旦表示做不到就置为 false，后续调用直接跳过。
  bool _isSupported = true;

  @override
  Future<void> showProgress({
    required SourceCheckNotificationText text,
    required String sourceName,
    required int completed,
    required int total,
  }) => _invoke('progress', <String, Object?>{
    'channelName': text.channelName,
    'title': text.title,
    'text': text.progress(sourceName, completed, total),
    'completed': completed,
    'total': total,
  });

  @override
  Future<void> showFinished({
    required SourceCheckNotificationText text,
    required int succeeded,
    required int failed,
  }) => _invoke('finished', <String, Object?>{
    'channelName': text.channelName,
    'title': text.title,
    'text': text.finished(succeeded, failed),
  });

  @override
  Future<void> cancel() => _invoke('cancel');

  Future<void> _invoke(String method, [Map<String, Object?>? arguments]) async {
    if (!_isSupported) {
      return;
    }

    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      _isSupported = false;
      logger.debug(
        'The source check notification is not implemented on this platform.',
      );
    } on PlatformException catch (error, stackTrace) {
      _isSupported = false;
      logger.warning(
        'The source check notification failed; the check keeps running.',
        error,
        stackTrace,
      );
    }
  }
}
