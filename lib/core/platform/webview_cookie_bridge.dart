import 'package:flutter_reader/core/network/cookie_manager.dart';

/// Reads and writes the platform WebView's cookie jar, which is separate from the app's own.
abstract interface class WebViewCookieBridge {
  /// Writes [cookies] into the WebView jar for [url], before the page loads.
  Future<void> write({required Uri url, required List<StoredCookie> cookies});

  /// Reads the WebView jar for [url]; a deleted cookie comes back with `isDeletion` set.
  Future<List<StoredCookie>> read(Uri url);
}
