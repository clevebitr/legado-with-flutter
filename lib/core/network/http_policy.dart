/// Request timeout applied to connect, send and receive (C-NET-2).
const Duration defaultHttpTimeout = Duration(seconds: 15);

/// Additional attempts made after a retryable failure (C-NET-2).
const int defaultMaxRetries = 1;

/// `User-Agent` sent unless a request overrides it (C-NET-4).
///
/// The version is deliberately absent: `pubspec.yaml` already owns it, and
/// copying it here would create the second source `PLAN.md` §6 warns about.
/// Book sources that need a browser-like agent declare their own headers.
const String defaultUserAgent = 'flutter_reader';

/// Network policy shared by every request (C-NET-2, C-NET-4, C-SEC-2).
final class HttpPolicy {
  /// Creates a policy.
  ///
  /// [maxRetries] counts *additional* attempts, so `1` means "at most two
  /// requests"; the bound is explicit because unlimited retries are forbidden
  /// (C-NET-2).
  ///
  /// [timeout] must be positive. It cannot be asserted here: Dart's constant
  /// evaluation refuses `Duration` comparisons (verified), and keeping this
  /// constructor `const` is worth more than the assertion.
  const HttpPolicy({
    this.timeout = defaultHttpTimeout,
    this.maxRetries = defaultMaxRetries,
    this.userAgent = defaultUserAgent,
    this.allowPlainHttp = false,
  }) : assert(maxRetries >= 0, 'Retries must be bounded and non-negative.');

  /// Time to wait for connect, send and receive, applied to every attempt.
  ///
  /// Must be positive: dio treats `Duration.zero` as "no timeout", which C-NET-2
  /// forbids. The value is validated where user input enters — the settings phase
  /// that overrides `httpPolicyProvider` — because a `const` constructor cannot
  /// assert on `Duration` (see the constructor documentation).
  final Duration timeout;

  /// Upper bound of additional attempts after the first one (C-NET-2).
  final int maxRetries;

  /// `User-Agent` used unless a request overrides it (C-NET-4).
  final String userAgent;

  /// Whether plaintext `http://` is allowed.
  ///
  /// `false` by default: C-SEC-2 only permits plaintext when the user opts in
  /// through a dedicated setting, so the flag is isolated here and no request
  /// site may bypass it.
  final bool allowPlainHttp;
}
