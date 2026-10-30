import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reader/core/di/platform_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/core/platform/source_verification.dart';
import 'package:flutter_reader/core/widgets/failure_message.dart';
import 'package:flutter_reader/core/widgets/state_message.dart';
import 'package:flutter_reader/features/book_source/domain/entities/login_form.dart';
import 'package:flutter_reader/features/book_source/presentation/notifiers/book_source_login_notifier.dart';
import 'package:flutter_reader/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_design/m3e_design.dart';

/// One source's native login form (`docs/dev/roadmap.md` M22, ADR-0072 §决策 3).
///
/// It renders whatever the source's `loginUi` declares — text, password, toggle, select and button
/// rows — and submits by storing the values and running the source's own `login()` script. Sources
/// that only declare a `loginUrl` never reach this page: the list opens the browser for them.
class BookSourceLoginPage extends ConsumerStatefulWidget {
  /// Creates the page for the source with [sourceId].
  const BookSourceLoginPage({required this.sourceId, super.key});

  /// The stored source to sign in.
  final int sourceId;

  @override
  ConsumerState<BookSourceLoginPage> createState() =>
      _BookSourceLoginPageState();
}

class _BookSourceLoginPageState extends ConsumerState<BookSourceLoginPage> {
  /// One controller per text/password field, created once the form is known.
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};

  @override
  void dispose() {
    for (final TextEditingController controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// The controller of [field], seeded with its value exactly once.
  TextEditingController _controllerOf(LoginField field) =>
      _controllers.putIfAbsent(
        field.name,
        () => TextEditingController(text: field.initialValue),
      );

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final M3ETheme tokens = context.m3e;
    final AsyncValue<BookSourceLoginState> state = ref.watch(
      bookSourceLoginProvider(widget.sourceId),
    );

    return Scaffold(
      backgroundColor: tokens.colors.surface,
      appBar: AppBar(
        title: Text(l10n.bookSourceLoginTitle),
        backgroundColor: tokens.colors.surface,
      ),
      body: switch (state) {
        AsyncData<BookSourceLoginState>(:final BookSourceLoginState value) =>
          switch (value.failure) {
            final ParseFailureKind kind => FailureMessage(
              kind: kind,
              onRetry: () =>
                  ref.invalidate(bookSourceLoginProvider(widget.sourceId)),
            ),
            null => _form(context, l10n, tokens, value),
          },
        AsyncError<BookSourceLoginState>() => StateMessage(
          message: l10n.bookSourceLoginLoadFailed,
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  /// The rows, the submit button and the outcome of the last attempt.
  Widget _form(
    BuildContext context,
    AppLocalizations l10n,
    M3ETheme tokens,
    BookSourceLoginState state,
  ) {
    final LoginForm form =
        state.form ?? const LoginForm(fields: <LoginField>[]);

    if (form.isEmpty) {
      // 只有 `loginUrl`（没有 `loginUi`）的源不该走到这里：列表那边直接开浏览器。
      return StateMessage(
        message: l10n.bookSourceLoginNoForm,
        icon: Icons.login_outlined,
      );
    }

    return ListView(
      padding: EdgeInsets.all(tokens.spacing.lg),
      children: <Widget>[
        if (state.source.source.name.isNotEmpty)
          Text(
            state.source.source.name,
            style: tokens.typography.base.titleMedium,
          ),
        SizedBox(height: tokens.spacing.md),
        for (final LoginField field in form.fields) _row(field, state, tokens),
        SizedBox(height: tokens.spacing.lg),
        FilledButton(
          onPressed: state.isSubmitting
              ? null
              : () => unawaited(
                  ref
                      .read(bookSourceLoginProvider(widget.sourceId).notifier)
                      .submit(),
                ),
          child: Text(
            state.isSubmitting ? l10n.bookSourceLoginWorking : l10n.actionSave,
          ),
        ),
        if (state.isSignedIn) ...<Widget>[
          SizedBox(height: tokens.spacing.sm),
          Text(
            l10n.bookSourceLoginDone,
            style: tokens.typography.base.bodySmall,
          ),
        ],
        if (state.submitFailure case final ParseFailureKind kind) ...<Widget>[
          SizedBox(height: tokens.spacing.sm),
          FailureMessage(kind: kind),
        ],
      ],
    );
  }

  /// One row: a labelled input, a switch, a dropdown or a button.
  Widget _row(LoginField field, BookSourceLoginState state, M3ETheme tokens) {
    final BookSourceLogin notifier = ref.read(
      bookSourceLoginProvider(widget.sourceId).notifier,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.md),
      child: switch (field.type) {
        LoginFieldType.toggle => SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: state.values[field.name] == 'true',
          onChanged: state.isSubmitting
              ? null
              : (bool value) => notifier.setValue(field.name, '$value'),
          title: Text(field.title),
        ),
        LoginFieldType.select => DropdownButtonFormField<String>(
          initialValue: _selectedOption(field, state),
          decoration: InputDecoration(labelText: field.title),
          items: <DropdownMenuItem<String>>[
            for (final String option in field.options)
              DropdownMenuItem<String>(value: option, child: Text(option)),
          ],
          onChanged: state.isSubmitting
              ? null
              : (String? value) => notifier.setValue(field.name, value ?? ''),
        ),
        LoginFieldType.button => OutlinedButton(
          onPressed: state.isSubmitting ? null : () => _press(field, notifier),
          child: Text(field.title),
        ),
        LoginFieldType.text || LoginFieldType.password => TextField(
          controller: _controllerOf(field),
          obscureText: field.type == LoginFieldType.password,
          enabled: !state.isSubmitting,
          decoration: InputDecoration(labelText: field.title),
          onChanged: (String value) => notifier.setValue(field.name, value),
        ),
      },
    );
  }

  /// The value a select shows: the stored one when it is still a choice, otherwise the first.
  String? _selectedOption(LoginField field, BookSourceLoginState state) {
    final String? value = state.values[field.name];
    if (value != null && field.options.contains(value)) {
      return value;
    }

    return field.options.isEmpty ? null : field.options.first;
  }

  /// Presses a button row: an absolute address opens in the browser, anything else is a script.
  void _press(LoginField field, BookSourceLogin notifier) {
    final String action = field.action ?? '';
    final BookSourceLoginState? current = ref
        .read(bookSourceLoginProvider(widget.sourceId))
        .value;
    if (action.startsWith('http://') || action.startsWith('https://')) {
      // 沙箱里 `open` 打不开页面：地址型按钮交给浏览器（与「去登录」同一条路）。
      unawaited(
        ref
            .read(sourceVerificationProvider)
            .verify(
              SourceVerificationRequest(
                sourceUrl: current?.source.source.url ?? '',
                sourceName: current?.source.source.name ?? '',
                url: action,
                title: field.title,
                headers: current?.source.source.headers,
              ),
            ),
      );

      return;
    }

    unawaited(notifier.runAction(field));
  }
}
