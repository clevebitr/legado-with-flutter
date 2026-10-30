/// A port for showing the user an address a **rule** wants to open (`java.openUrl`, M25/S3b).
///
/// Upstream's `JsExtensions.openUrl` starts a confirmation screen and then the system browser
/// (`JsExtensions.kt:1162-1185`): a book source must never be able to launch anything behind the
/// user's back, so the address is shown first. `core/` has no widgets and no `BuildContext`, and
/// `url_launcher` is a plugin, so the two halves are a port here and an implementation at the
/// composition root.
abstract interface class ExternalUrlOpener {
  /// Shows [url] with [sourceName] and opens it when the user agrees.
  ///
  /// Answers whether the address was opened. A caller that cannot wait (a `@js:` rule never waits
  /// for `openUrl`, exactly like `java.startBrowser`) ignores the answer; it exists so a test can
  /// assert what the port decided.
  Future<bool> open(String url, {String sourceName = ''});
}

/// An [ExternalUrlOpener] that opens nothing.
///
/// The honest default: a build whose composition root did not bind the port (a headless test, a
/// platform without a browser) cannot show a dialog, and failing a rule over a link it merely
/// *offered* to open would be worse than dropping it — the bridge logs the address it refused.
final class UnboundExternalUrlOpener implements ExternalUrlOpener {
  /// Creates the no-op port.
  const UnboundExternalUrlOpener();

  @override
  Future<bool> open(String url, {String sourceName = ''}) async => false;
}
