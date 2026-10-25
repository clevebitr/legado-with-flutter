/// A successful (2xx) HTTP response.
///
/// Every other status is already mapped to a `ParseFailureKind`.
final class HttpResponse {
  /// Creates a response.
  const HttpResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
    required this.url,
  });

  /// HTTP status code, always in the 2xx range.
  final int statusCode;

  /// Response headers keyed by lower-case name.
  final Map<String, List<String>> headers;

  /// Response body, decoded with the detected charset.
  final String body;

  /// The address the body was finally read from: [url] after any redirect.
  ///
  /// A rule that must re-issue a request against the page it just received (a site that answers
  /// `302` and expects the *redirected* address to carry the session) needs this; without it the
  /// only address a rule knows is the one it started with. Equal to the requested address when
  /// nothing redirected.
  final String url;
}
