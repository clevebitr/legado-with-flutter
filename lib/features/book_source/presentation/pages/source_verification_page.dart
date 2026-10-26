// coverage:ignore-file
import 'dart:convert' show jsonDecode;

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' as webview;
import 'package:flutter_reader/core/network/cookie_manager.dart';
import 'package:flutter_reader/core/network/persistent_cookie_manager.dart';
import 'package:flutter_reader/core/platform/in_app_webview_cookie_bridge.dart';
import 'package:flutter_reader/core/platform/source_verification.dart';
import 'package:flutter_reader/core/platform/webview_cookie_bridge.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:m3e_design/m3e_design.dart';

/// The **visible** browser a human uses to pass a source's anti-bot check
/// (`docs/dev/roadmap.md` M21a, ADR-0068 §决策 2).
///
/// 本文件按 ADR-0019 第二类登记在 `tool/coverage_allowlist.txt`：它就是一个 WebView 控件，
/// 宿主 VM 里没有 WebView2 / Android WebView，交互也无法自动化。它的两个决定由别处保证：
/// 「cookie 什么时候进出」由 [WebViewCookieBridge] 与 [PersistentCookieManager] 的测试钉住，
/// 「页面能不能真的过盾」由设备级用例（Windows WebView2 + Android WebView）验证。
///
/// Three behaviours are deliberate:
///
/// * **cookies go in before the first byte is loaded** (`_ready` gate): a site that redirects on a
///   missing session cookie would otherwise bounce the user out before the page is usable;
/// * **the confirm button and the system back button do the same thing** (upstream's
///   `finishWithVerification` on back): a user who backs out has almost always finished the
///   challenge, and re-asking is worse than a wrong-page refetch (the caller reports it normally);
/// * **an explicit close is a cancel**: `null` travels back, and the caller reports `cancelled`
///   instead of pretending the source is broken.
class SourceVerificationPage extends StatefulWidget {
  /// Creates the page for [request].
  const SourceVerificationPage({
    required this.request,
    required this.cookies,
    required this.cookieJar,
    super.key,
    this.cookieBridge = const InAppWebViewCookieBridge(),
  });

  /// What the rule asked for.
  final SourceVerificationRequest request;

  /// The cookies the app already holds for the target host (written before the load).
  final List<StoredCookie> cookies;

  /// The app's jar; anything the WebView collected is imported here on finish.
  final PersistentCookieManager cookieJar;

  /// The platform cookie bridge (a test can pass a fake one).
  final WebViewCookieBridge cookieBridge;

  @override
  State<SourceVerificationPage> createState() => _SourceVerificationPageState();
}

/// State of the verification page: the ready gate, the controller and the finish guard.
class _SourceVerificationPageState extends State<SourceVerificationPage> {
  /// Whether the cookies were written; the WebView is not built before that.
  bool _ready = false;

  /// Whether a finish is in flight (the buttons are disabled meanwhile).
  bool _finishing = false;

  /// Load progress, 0..1, for the thin bar under the app bar.
  double _progress = 0;

  /// The controller, kept for the `outerHTML` read and the final URL.
  webview.InAppWebViewController? _controller;

  @override
  void initState() {
    super.initState();
    _seedCookies();
  }

  /// Writes the stored cookies into the WebView jar, then lets the page load.
  Future<void> _seedCookies() async {
    final Uri target = Uri.parse(widget.request.url);
    await widget.cookieBridge.write(url: target, cookies: widget.cookies);
    if (!mounted) {
      return;
    }
    setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;
    final String? html = widget.request.html;

    return PopScope<SourceVerificationOutcome>(
      // 系统返回键与「完成」同义（上游 `finishWithVerification`）：先收 cookie，再离开。
      canPop: false,
      onPopInvokedWithResult: (bool didPop, SourceVerificationOutcome? result) {
        if (!didPop) {
          _finish();
        }
      },
      child: Scaffold(
        backgroundColor: tokens.colors.surface,
        appBar: AppBar(
          backgroundColor: tokens.colors.surface,
          title: Text(
            l10n.sourceVerificationTitle(
              widget.request.title,
              widget.request.sourceName,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: l10n.actionCancel,
            onPressed: _finishing ? null : () => Navigator.of(context).pop(),
          ),
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.check),
              tooltip: l10n.sourceVerificationDone,
              onPressed: _finishing ? null : _finish,
            ),
          ],
          bottom: _progress < 1 && !_ready
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(2),
                  child: LinearProgressIndicator(),
                )
              : null,
        ),
        body: !_ready
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: <Widget>[
                  if (_progress < 1) LinearProgressIndicator(value: _progress),
                  Expanded(
                    child: webview.InAppWebView(
                      initialUrlRequest: html == null
                          ? webview.URLRequest(
                              url: webview.WebUri(widget.request.url),
                              headers: widget.request.headers,
                            )
                          : null,
                      initialData: html == null
                          ? null
                          : webview.InAppWebViewInitialData(data: html),
                      initialSettings: webview.InAppWebViewSettings(
                        javaScriptEnabled: true,
                        useShouldOverrideUrlLoading: false,
                      ),
                      onWebViewCreated: (
                        webview.InAppWebViewController controller,
                      ) => _controller = controller,
                      onProgressChanged:
                          (
                            webview.InAppWebViewController controller,
                            int progress,
                          ) {
                            if (mounted) {
                              setState(() => _progress = progress / 100);
                            }
                          },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Harvests the cookies, imports them into the app jar and answers the page.
  ///
  /// The body is the WebView's `document.documentElement.outerHTML`; the caller decides whether to
  /// re-fetch over HTTP with the new cookies (`refetchAfterSuccess`), which keeps the network call
  /// in one place (the adapter) instead of here.
  Future<void> _finish() async {
    if (_finishing) {
      return;
    }
    setState(() => _finishing = true);
    final webview.InAppWebViewController? controller = _controller;
    // `getUrl()` 在插件里是异步的（返回 WebUri? 的 Future）。
    final webview.WebUri? loaded = await controller?.getUrl();
    final String? loadedUrl = loaded?.toString();
    final Uri target = Uri.parse(loadedUrl ?? widget.request.url);

    String? html;
    if (controller != null) {
      final Object? dom = await controller.evaluateJavascript(
        source: 'document.documentElement.outerHTML',
      );
      html = dom is String ? _unescapeJson(dom) : null;
    }
    final List<StoredCookie> collected = await widget.cookieBridge.read(target);
    await widget.cookieJar.importFromWebView(collected);
    if (!mounted) {
      return;
    }
    Navigator.of(
      context,
    ).pop(SourceVerificationOutcome(url: target.toString(), body: html ?? ''));
  }

  /// `evaluateJavascript` answers a JSON-encoded string on some platforms; unwrap it.
  ///
  /// Android's WebView returns the DOM wrapped in JSON quotes with escaped characters while
  /// WebView2 answers the raw text, so a value that is already plain is returned untouched.
  /// [jsonDecode] does the unescaping correctly; a chain of `replaceAll` calls would turn a literal
  /// backslash-n inside a code block into a newline and corrupt the page.
  String _unescapeJson(String value) {
    final String trimmed = value.trim();
    if (!trimmed.startsWith('"') || !trimmed.endsWith('"')) {
      return value;
    }
    try {
      final Object? decoded = jsonDecode(trimmed);

      return decoded is String ? decoded : value;
    } on FormatException {
      return value;
    }
  }
}
