import 'package:flutter/material.dart';
import 'package:m3e_design/m3e_design.dart';

/// A centred informational message filling the space it is given.
///
/// For empty states, which are not failures and carry no action. An [icon] is optional:
/// a picture makes an empty list read as “nothing here yet” instead of “it broke”.
class StateMessage extends StatelessWidget {
  /// Creates the message.
  const StateMessage({required this.message, this.icon, super.key});

  /// Localized text, always taken from `AppLocalizations`.
  final String message;

  /// The glyph above the text, or `null` for text only.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final M3ETheme tokens = context.m3e;
    final IconData? glyph = icon;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(tokens.spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (glyph != null) ...<Widget>[
              Icon(
                glyph,
                size: tokens.spacing.xxl,
                color: tokens.colors.outline,
              ),
              SizedBox(height: tokens.spacing.md),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: tokens.typography.base.bodyLarge?.copyWith(
                color: tokens.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
