import 'package:flutter/material.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:m3e_design/m3e_design.dart';

/// Shows the user-facing message of a [ParseFailureKind], with an optional retry.
class FailureMessage extends StatelessWidget {
  /// Creates the message.
  const FailureMessage({required this.kind, this.onRetry, super.key});

  /// The failure to explain; the kind itself carries no text.
  final ParseFailureKind kind;

  /// Re-runs the failed operation; the action is hidden when `null`.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              resolveFailureMessage(l10n, kind),
              textAlign: TextAlign.center,
              style: tokens.typography.base.bodyLarge,
            ),
            if (onRetry != null) ...<Widget>[
              SizedBox(height: tokens.spacing.lg),
              FilledButton(onPressed: onRetry, child: Text(l10n.actionRetry)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Turns [kind] into the text the user reads.
///
/// `cancelled` is silent and yields an empty string.
String resolveFailureMessage(AppLocalizations l10n, ParseFailureKind kind) =>
    switch (kind) {
      ParseFailureKind.networkTimeout => l10n.failureNetworkTimeout,
      ParseFailureKind.networkFailed => l10n.failureNetworkFailed,
      ParseFailureKind.networkForbidden => l10n.failureNetworkForbidden,
      ParseFailureKind.notFound => l10n.failureNotFound,
      ParseFailureKind.encodingFailed => l10n.failureEncodingFailed,
      ParseFailureKind.parseFailed => l10n.failureParseFailed,
      ParseFailureKind.unsupportedRule => l10n.failureUnsupportedRule,
      ParseFailureKind.invalidBookSource => l10n.failureInvalidBookSource,
      // 取消是静默的，没有对应文案。
      ParseFailureKind.cancelled => '',
    };
