import 'package:freezed_annotation/freezed_annotation.dart';

part 'parse_result.freezed.dart';

/// Kinds of recoverable failures produced by the parsing, network and storage
/// layers.
///
/// [ParseFailureKind.cancelled] is silent and has no message key.
enum ParseFailureKind {
  /// The connection or read exceeded the configured timeout.
  networkTimeout,

  /// DNS resolution or the connection failed, including 5xx responses.
  networkFailed,

  /// The remote site refused the request with HTTP 403.
  networkForbidden,

  /// The remote site answered with HTTP 404.
  notFound,

  /// The charset could not be detected or the response could not be decoded.
  encodingFailed,

  /// A rule matched nothing, or a JS rule threw or timed out.
  parseFailed,

  /// The book source used a rule syntax that is not supported yet.
  unsupportedRule,

  /// The imported book source JSON misses required fields or is malformed.
  invalidBookSource,

  /// The user cancelled the operation; the UI stays silent about it.
  cancelled;

  /// Whether retrying the same operation may succeed.
  bool get isRetryable => switch (this) {
    // 逐值列出且不写通配分支：新增 kind 时必须明确它是否可重试。
    ParseFailureKind.networkTimeout => true,
    ParseFailureKind.networkFailed => true,
    ParseFailureKind.networkForbidden => false,
    ParseFailureKind.notFound => false,
    ParseFailureKind.encodingFailed => false,
    ParseFailureKind.parseFailed => false,
    ParseFailureKind.unsupportedRule => false,
    ParseFailureKind.invalidBookSource => false,
    ParseFailureKind.cancelled => false,
  };
}

/// Result of an operation that can fail without throwing.
///
/// Consumers must `switch` exhaustively over [ParseSuccess] and [ParseFailure];
/// equality is structural and unsuitable as a cache key.
// 结果构造后不再修改，故不生成 copyWith。
@Freezed(copyWith: false)
sealed class ParseResult<T> with _$ParseResult<T> {
  /// Creates a successful result carrying [data].
  const factory ParseResult.success(T data) = ParseSuccess<T>;

  /// Creates a failure of [kind] at [rulePath].
  ///
  /// [cause] and [stackTrace] are for diagnostics only, never for the UI.
  const factory ParseResult.failure({
    required ParseFailureKind kind,
    required String rulePath,
    Object? cause,
    StackTrace? stackTrace,
  }) = ParseFailure<T>;
}

/// Creates a [ParseFailure], asserting that [rulePath] is non-empty.
ParseFailure<T> failureAt<T>({
  required ParseFailureKind kind,
  required String rulePath,
  Object? cause,
  StackTrace? stackTrace,
}) {
  assert(
    rulePath.isNotEmpty,
    'A ParseFailure needs a non-empty rulePath (C-SRC-8).',
  );

  return ParseFailure<T>(
    kind: kind,
    rulePath: rulePath,
    cause: cause,
    stackTrace: stackTrace,
  );
}

/// Convenience accessors for [ParseResult].
extension ParseResultExtension<T> on ParseResult<T> {
  /// Returns the wrapped data, or `null` when the result is a failure.
  T? get dataOrNull => switch (this) {
    ParseSuccess<T>(:final T data) => data,
    ParseFailure<T>() => null,
  };

  /// Invokes [onSuccess] with the wrapped data when this result succeeded.
  void whenSuccess(void Function(T data) onSuccess) {
    if (this case ParseSuccess<T>(:final T data)) {
      onSuccess(data);
    }
  }
}
