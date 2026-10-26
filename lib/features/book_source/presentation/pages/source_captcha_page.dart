import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:m3e_design/m3e_design.dart';

/// The image-captcha dialog of `java.getVerificationCode(imageUrl)`
/// (`docs/dev/roadmap.md` M21a, ADR-0068 §决策 5).
///
/// It is a page rather than a `showDialog` because the caller has no `BuildContext`: the request
/// comes from a JS rule through the bridge, and the composition root pushes this page on the root
/// navigator (ADR-0068 §决策 3). It answers the typed text, or `null` when the user cancels.
///
/// The image arrives as **bytes**, not as a URL: a captcha is bound to the session cookie and must
/// not be cached by the image cache (C-PERF-3 is about covers, not about a one-time code), so the
/// adapter fetches it through `HttpClient` and hands the decoded bytes over.
class SourceCaptchaPage extends StatefulWidget {
  /// Creates the page for one captcha.
  const SourceCaptchaPage({
    required this.image,
    required this.sourceName,
    super.key,
  });

  /// The captcha image bytes.
  final Uint8List image;

  /// The source's display name, shown so the user knows what they are answering.
  final String sourceName;

  @override
  State<SourceCaptchaPage> createState() => _SourceCaptchaPageState();
}

/// State of the captcha page: the text field and its input action.
class _SourceCaptchaPageState extends State<SourceCaptchaPage> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Answers the typed text (trimmed); a blank answer is refused instead of sent.
  void _submit() {
    final String code = _controller.text.trim();
    if (code.isEmpty) {
      return;
    }
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;

    return Scaffold(
      backgroundColor: tokens.colors.surface,
      appBar: AppBar(
        backgroundColor: tokens.colors.surface,
        title: Text(l10n.sourceCaptchaTitle(widget.sourceName)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: l10n.actionCancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(tokens.spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // 验证码图片：固定高度 + 等比缩放，避免不同站点的窄长图把布局顶歪。
            SizedBox(
              height: 120,
              child: Image.memory(
                widget.image,
                fit: BoxFit.contain,
                semanticLabel: l10n.sourceCaptchaImage,
              ),
            ),
            SizedBox(height: tokens.spacing.lg),
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: l10n.sourceCaptchaHint,
                border: const OutlineInputBorder(),
              ),
            ),
            SizedBox(height: tokens.spacing.md),
            FilledButton(
              onPressed: _submit,
              child: Text(l10n.sourceCaptchaConfirm),
            ),
          ],
        ),
      ),
    );
  }
}
