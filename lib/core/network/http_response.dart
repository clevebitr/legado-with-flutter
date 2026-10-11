/// A successful (2xx) HTTP response.
///
/// Only 2xx responses become an [HttpResponse]: every other status is mapped to
/// a `ParseFailureKind` by the client, so callers never have to inspect a status
/// code to know whether the request worked (`docs/dev/book-source.md` §7).
final class HttpResponse {
  /// Creates a response.
  const HttpResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
  });

  /// HTTP status code, always in the 2xx range.
  final int statusCode;

  /// Response headers keyed by lower-case name.
  final Map<String, List<String>> headers;

  /// Response body, decoded with the detected charset (C-NET-3).
  final String body;
}
