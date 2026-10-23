/// A successful (2xx) HTTP response.
///
/// Every other status is already mapped to a `ParseFailureKind`.
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

  /// Response body, decoded with the detected charset.
  final String body;
}
