import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';

/// The script part of a source's `loginUrl`, or an empty string
/// (`docs/dev/roadmap.md` M22, ADR-0072 §决策 3).
///
/// Upstream `BaseSource.getLoginJs()` accepts three forms and this mirrors it: `@js:…`, `<js>…</js>`,
/// or a bare script. A plain URL (no script) answers空 — the caller then opens it in the browser
/// instead of evaluating anything.
String loginScriptOf(BookSource source) {
  final String raw = (source.loginUrl ?? '').trim();
  if (raw.startsWith('@js:')) {
    return raw.substring(4);
  }
  if (raw.startsWith('<js>')) {
    final int end = raw.lastIndexOf('<');

    return raw.substring(4, end <= 4 ? raw.length : end);
  }

  return _looksLikeScript(raw) ? raw : '';
}

/// A bare `loginUrl` is a script only when it declares `login` or opens with JS — otherwise it is a
/// page address (or a URL rule), which is what the browser path uses.
bool _looksLikeScript(String raw) =>
    raw.contains('function login') ||
    raw.contains('login=') ||
    raw.contains('login =') ||
    raw.contains('=>');
