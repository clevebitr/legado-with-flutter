import 'package:flutter_reader/core/error/parse_result.dart';

/// Resolves the ARB message key of [kind], or `null` when the UI stays silent.
///
/// Keys follow `failure<PascalCaseName>`, for example `failureNetworkTimeout`.
String? resolveFailureArbKey(ParseFailureKind kind) => switch (kind) {
  // 逐值列举，新增 kind 时编译器会强制在此分类。
  ParseFailureKind.networkTimeout => 'failureNetworkTimeout',
  ParseFailureKind.networkFailed => 'failureNetworkFailed',
  ParseFailureKind.networkForbidden => 'failureNetworkForbidden',
  ParseFailureKind.notFound => 'failureNotFound',
  ParseFailureKind.encodingFailed => 'failureEncodingFailed',
  ParseFailureKind.parseFailed => 'failureParseFailed',
  ParseFailureKind.unsupportedRule => 'failureUnsupportedRule',
  ParseFailureKind.invalidBookSource => 'failureInvalidBookSource',
  ParseFailureKind.cancelled => null,
};
