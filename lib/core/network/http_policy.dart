import 'package:flutter_reader/core/network/request_limiter.dart';

/// Request timeout applied to connect, send and receive.
const Duration defaultHttpTimeout = Duration(seconds: 15);

/// Additional attempts made after a retryable failure.
const int defaultMaxRetries = 1;

/// `User-Agent` sent unless a request overrides it.
///
/// A **desktop Chrome** string, matching upstream: a bare `flutter_reader` UA is what makes a
/// number of real sites answer 403 before the rules ever run (ADR-0069). A source that needs its
/// own UA declares it in `header` (C-NET-4), which still wins.
const String defaultUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

/// Network policy shared by every request.
final class HttpPolicy {
  /// Creates a policy.
  ///
  /// [maxRetries] counts additional attempts; [timeout] must be positive and is validated by callers.
  const HttpPolicy({
    this.timeout = defaultHttpTimeout,
    this.maxRetries = defaultMaxRetries,
    this.maxConcurrentRequestsPerSource = defaultMaxConcurrentRequestsPerSource,
    this.userAgent = defaultUserAgent,
    this.allowPlainHttp = false,
  }) : assert(maxRetries >= 0, 'Retries must be bounded and non-negative.'),
       assert(
         maxConcurrentRequestsPerSource > 0,
         'A concurrency budget must be positive.',
       );

  /// Time to wait for connect, send and receive; must be positive.
  final Duration timeout;

  /// Upper bound of additional attempts after the first one.
  final int maxRetries;

  /// Requests one book source may have in flight at once; excess requests queue.
  final int maxConcurrentRequestsPerSource;

  /// `User-Agent` used unless a request overrides it.
  final String userAgent;

  /// Whether plaintext `http://` is allowed; off by default.
  final bool allowPlainHttp;
}
