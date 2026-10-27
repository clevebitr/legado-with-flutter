/// One error as a single log line: its type and its **full** text.
///
/// Logs are not redacted (`ADR-0082`): this repository is open source and the raw error text —
/// Dart exception message, `HttpException` URI, JS engine message — is what actually locates a
/// broken source. The type stays in front so a log can still be grepped by failure kind.
String describeError(Object error) {
  final String text = error.toString();
  final String type = '${error.runtimeType}';
  // `FormatException.toString()` 本身就以类型开头：别写两遍。
  final String body = text.startsWith('$type: ')
      ? text.substring(type.length + 2)
      : text;

  return '<$type: $body>';
}
