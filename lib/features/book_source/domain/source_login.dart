import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';

/// The login fields one source declares, in the shape the page fetcher consumes.
///
/// They answer two different questions (`book-source.md` §2, ADR-0068 addendum of 2026-10-24):
///
/// * [checkScript] — `loginCheckJs`, the **response interceptor** that runs after every fetched
///   page and may replace it (that is how a source sends the user to a login page and retries);
/// * [canSignIn] — whether the source declares *how* to sign in (`loginUrl` / `loginUi`), which is
///   what makes 「去登录」 an actionable answer instead of a generic parse failure.
final class SourceLoginGuard {
  /// Creates the guard of one source.
  const SourceLoginGuard({this.checkScript, this.loginUrl, this.loginUi});

  /// A source that declares nothing about logging in.
  const SourceLoginGuard.none()
    : checkScript = null,
      loginUrl = null,
      loginUi = null;

  /// The `loginCheckJs` response interceptor, verbatim.
  final String? checkScript;

  /// The `loginUrl` field: an address (maybe a URL rule) or a script defining `login()`.
  final String? loginUrl;

  /// The `loginUi` field: the native login form description, kept verbatim.
  final String? loginUi;

  /// Whether an interceptor has to run after each page.
  bool get hasCheck {
    final String? script = checkScript;

    return script != null && script.trim().isNotEmpty;
  }

  /// Whether the source declares a way to sign in.
  bool get canSignIn => _isDeclared(loginUrl) || _isDeclared(loginUi);

  /// Whether any of the three fields is non-blank, i.e. whether the guard can do anything.
  bool get isDeclared => hasCheck || canSignIn;
}

/// The response the source's login fields imply.
extension BookSourceLogin on BookSource {
  /// The login guard this source declares.
  SourceLoginGuard get loginGuard => SourceLoginGuard(
    checkScript: loginCheckJs,
    loginUrl: loginUrl,
    loginUi: loginUi,
  );
}

/// What a `loginCheckJs` interceptor did to the response it was handed.
///
/// `null` (i.e. `ParseSuccess(null)`) means "the script left the response alone": it returned
/// `undefined` / `null` / the same object, which upstream treats as 「沿用本次响应」.
final class LoginReplacement {
  /// Creates a replacement response.
  const LoginReplacement({required this.body, this.url});

  /// The body the script produced.
  final String body;

  /// The URL that travels with it, when the script produced one.
  final String? url;
}

/// Reads what a `loginCheckJs` interceptor returned (`book-source.md` §6).
///
/// The accepted shapes are, in order:
///
/// * `null` / `undefined` → [ParseSuccess] carrying `null`: keep the response;
/// * an object with a **`body` string** → the replacement; a `__url` / `url` string is taken as
///   the new address, which is how the sandbox's response object and
///   `java.startBrowserAwait(...)`'s `{url, body}` round-trip;
/// * a **string** → the replacement body. Upstream rejects it (`loginCheckJs did not return
///   StrResponse`) because a `StrResponse` is what the stage expects; a plain body is what a
///   hand-written `result.body.replace(…)` expression produces, and taking it costs nothing
///   (tolerance registered in `book-source.md` §6);
/// * anything else (a boolean, a number, an array) → [ParseFailureKind.parseFailed]: the stage
///   cannot tell what such a value means, and guessing would parse a body nobody produced.
ParseResult<LoginReplacement?> readLoginCheckResult(Object? value) {
  if (value == null) {
    return const ParseSuccess<LoginReplacement?>(null);
  }
  if (value is String) {
    return ParseSuccess<LoginReplacement?>(LoginReplacement(body: value));
  }
  if (value is Map<Object?, Object?>) {
    final Object? body = value['body'];
    if (body is! String) {
      return _notAResponse();
    }
    final Object? url = value['__url'] ?? value['url'];

    return ParseSuccess<LoginReplacement?>(
      LoginReplacement(
        body: body,
        url: url is String && url.trim().isNotEmpty ? url : null,
      ),
    );
  }

  return _notAResponse();
}

ParseResult<LoginReplacement?> _notAResponse() =>
    const ParseFailure<LoginReplacement?>(
      kind: ParseFailureKind.parseFailed,
      rulePath: 'loginCheckJs',
    );

bool _isDeclared(String? value) => value != null && value.trim().isNotEmpty;
