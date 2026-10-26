import 'package:flutter_reader/core/platform/user_messages.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'user_messages_provider.g.dart';

/// Provides the channel `java.toast` / `java.longToast` travel on (ADR-0076 §决策 1).
///
/// Defaults to the silent no-op: `core/` cannot show a widget, so the composition root overrides it
/// with the snack-bar implementation (`lib/app.dart`). A build without the override still runs every
/// rule — the message is logged by the bridge, only the toast is missing.
@Riverpod(keepAlive: true)
UserMessages userMessages(Ref ref) => const UnboundUserMessages();
