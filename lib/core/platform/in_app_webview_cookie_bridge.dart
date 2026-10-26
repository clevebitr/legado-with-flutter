// coverage:ignore-file
import 'package:flutter_inappwebview/flutter_inappwebview.dart' as webview;
import 'package:flutter_reader/core/network/cookie_manager.dart';
import 'package:flutter_reader/core/platform/webview_cookie_bridge.dart';

/// [WebViewCookieBridge] on top of `flutter_inappwebview`'s `CookieManager`.
final class InAppWebViewCookieBridge implements WebViewCookieBridge {
  /// Creates the bridge.
  const InAppWebViewCookieBridge();

  @override
  Future<void> write({
    required Uri url,
    required List<StoredCookie> cookies,
  }) async {
    if (cookies.isEmpty) {
      return;
    }
    final webview.CookieManager manager = webview.CookieManager.instance();
    final webview.WebUri target = webview.WebUri(url.toString());
    for (final StoredCookie cookie in cookies) {
      final DateTime? expires = cookie.expiresAt;
      // 插件的 `setCookie` 收平铺参数（不是 `Cookie` 对象），字段一一对应。
      await manager.setCookie(
        url: target,
        name: cookie.name,
        value: cookie.value,
        domain: cookie.domain,
        path: cookie.path,
        isSecure: cookie.isSecure,
        expiresDate: expires?.millisecondsSinceEpoch,
      );
    }
  }

  @override
  Future<List<StoredCookie>> read(Uri url) async {
    final List<webview.Cookie> cookies = await webview.CookieManager.instance()
        .getCookies(url: webview.WebUri(url.toString()));
    final String fallbackDomain = url.host.toLowerCase();

    return <StoredCookie>[
      for (final webview.Cookie cookie in cookies)
        StoredCookie(
          name: cookie.name,
          // 插件的 `value` 是 `dynamic`：WebView 给的一律按字符串处理。
          value: '${cookie.value ?? ''}',
          domain: cookie.domain ?? fallbackDomain,
          path: cookie.path ?? '/',
          isSecure: cookie.isSecure ?? false,
          isDeletion: cookie.value == null || '${cookie.value}'.isEmpty,
          expiresAt: _expiryOf(cookie.expiresDate),
        ),
    ];
  }

  // 插件给的是毫秒时间戳，可能为空。
  DateTime? _expiryOf(int? milliseconds) => milliseconds == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(milliseconds);
}
