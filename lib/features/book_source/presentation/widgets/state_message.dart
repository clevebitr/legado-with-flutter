import 'package:flutter/material.dart';
import 'package:m3e_design/m3e_design.dart';

/// A centred informational message filling the space it is given.
///
/// Used for the empty states of the feature ("no book source yet" and "no match").
/// An empty state is not a failure, so it carries no action and no failure kind.
class StateMessage extends StatelessWidget {
  /// Creates the message.
  const StateMessage({required this.message, super.key});

  /// Localized text, always taken from `AppLocalizations` (C-UI-5).
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
