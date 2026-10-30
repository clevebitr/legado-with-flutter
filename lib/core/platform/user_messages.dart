/// Shows short, rule-authored text to the user (`java.toast` / `java.longToast`).
///
/// Upstream's sandbox has an Android `Toast` at hand; here the sandbox is an isolate and the UI is
/// on the other side of the bridge, so the message travels through this port (ADR-0076 §决策 1).
/// The port is deliberately one-way and fire-and-forget: a toast must never make a rule wait, and
/// no rule may read an answer back from it.
abstract interface class UserMessages {
  /// Shows [message] once. Implementations may drop it when no UI is on screen.
  void show(String message);
}

/// A [UserMessages] that shows nothing: the default when no composition root bound the port.
///
/// A silent no-op is the honest fallback (the message is still logged by the bridge); throwing
/// would fail a rule over a message nobody asked for.
final class UnboundUserMessages implements UserMessages {
  /// Creates the no-op port.
  const UnboundUserMessages();

  @override
  void show(String message) {}
}
