import 'package:flutter/material.dart';
import 'package:m3e_design/m3e_design.dart';

/// A centred informational message filling the space it is given.
///
/// For empty states, which are not failures and carry no action.
class StateMessage extends StatelessWidget {
  /// Creates the message.
  const StateMessage({required this.message, super.key});

  /// Localized text, always taken from `AppLocalizations`.
  final String message;

  @override
  Widget build(BuildContext context) {
    final M3ETheme tokens = context.m3e;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.xl),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: tokens.typography.base.bodyLarge,
        ),
      ),
    );
  }
}
