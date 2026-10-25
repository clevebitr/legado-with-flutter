import 'dart:async';

import 'package:flutter_reader/core/di/logger_provider.dart';
import 'package:flutter_reader/core/error/parse_result.dart';
import 'package:flutter_reader/features/book_source/di.dart';
import 'package:flutter_reader/features/book_source/domain/entities/book_source.dart';
import 'package:flutter_reader/features/book_source/domain/entities/login_form.dart';
import 'package:flutter_reader/features/book_source/domain/entities/stored_book_source.dart';
import 'package:flutter_reader/features/book_source/domain/repositories/book_source_repository.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'book_source_login_notifier.freezed.dart';
part 'book_source_login_notifier.g.dart';

/// What the login page knows at one moment (`docs/dev/roadmap.md` M22, ADR-0072 §决策 3).
@freezed
abstract class BookSourceLoginState with _$BookSourceLoginState {
  /// Creates a state.
  const factory BookSourceLoginState({
    /// The source being signed in.
    required StoredBookSource source,

    /// The rendered form; empty when the source only declares a browser address.
    LoginForm? form,

    /// The values collected so far, keyed by the field's `name`.
    @Default(<String, String>{}) Map<String, String> values,

    /// Why the form could not be resolved, when it could not.
    ParseFailureKind? failure,

    /// Whether a submit (or a button action) is in flight.
    @Default(false) bool isSubmitting,

    /// Whether the last submit succeeded.
    @Default(false) bool isSignedIn,

    /// Why the last submit failed, when it did.
    ParseFailureKind? submitFailure,
  }) = _BookSourceLoginState;
}

/// Drives one source's login form.
///
/// The form comes from `loginUi` (resolved through the sandbox when it is itself a script), the
/// values live here, and a successful submit stores them on the source before running its `login()`.
/// Storing first is upstream's order and it matters: the script may read `source.getLoginInfo()`
/// itself, and the next page fetch has to see the same values.
@riverpod
class BookSourceLogin extends _$BookSourceLogin {
  @override
  Future<BookSourceLoginState> build(int sourceId) async {
    final BookSourceRepository repository = ref.watch(
      bookSourceRepositoryProvider,
    );
    final StoredBookSource? source = await repository.findById(sourceId);
    if (source == null) {
      // 行被删了：让页面显示一个明确的失败，而不是一张没有源的空白表单。
      return BookSourceLoginState(
        source: StoredBookSource(
          id: sourceId,
          source: _emptySource,
          isEnabled: false,
          customOrder: 0,
          importedAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
        failure: ParseFailureKind.invalidBookSource,
      );
    }

    final Map<String, String> stored = await repository.loginInfoOf(sourceId);
    final ParseResult<LoginForm> resolved = await ref
        .read(resolveLoginFormProvider)
        .execute(
          source.source,
          loginInfo: stored,
          bookName: source.source.name,
          bookUrl: source.source.url,
        );

    return switch (resolved) {
      ParseSuccess<LoginForm>(:final LoginForm data) => BookSourceLoginState(
        source: source,
        form: data,
        values: <String, String>{
          for (final LoginField field in data.fields)
            if (field.type != LoginFieldType.button)
              field.name: stored[field.name] ?? field.initialValue,
        },
      ),
      ParseFailure<LoginForm>(:final ParseFailureKind kind) =>
        BookSourceLoginState(source: source, failure: kind),
    };
  }

  /// Records one field's value.
  void setValue(String name, String value) {
    final BookSourceLoginState? current = state.value;
    if (current == null) {
      return;
    }
    state = AsyncData<BookSourceLoginState>(
      current.copyWith(
        values: <String, String>{...current.values, name: value},
        submitFailure: null,
      ),
    );
  }

  /// Stores the values and runs the source's `login()`.
  ///
  /// A source whose `login()` fails keeps the stored values on purpose: the next attempt starts from
  /// what the user typed instead of an empty form.
  Future<void> submit() async {
    final BookSourceLoginState? current = state.value;
    if (current == null || current.isSubmitting) {
      return;
    }
    state = AsyncData<BookSourceLoginState>(
      current.copyWith(isSubmitting: true, submitFailure: null),
    );

    final BookSource source = current.source.source;
    try {
      await ref
          .read(bookSourceRepositoryProvider)
          .saveLoginInfo(current.source.id, current.values);

      final ParseResult<Object?> result = await ref
          .read(signInProvider)
          .execute(
            source,
            info: current.values,
            bookName: source.name,
            bookUrl: source.url,
          );

      state = AsyncData<BookSourceLoginState>(switch (result) {
        ParseSuccess<Object?>() => current.copyWith(
          isSubmitting: false,
          isSignedIn: true,
        ),
        ParseFailure<Object?>(:final ParseFailureKind kind) => current.copyWith(
          isSubmitting: false,
          submitFailure: kind,
        ),
      });
    } on Exception catch (error, stackTrace) {
      // C-ERR-2 的 presentation 兜底：存不进 / 跑不动都要给回执，不能把页面留在提交中。
      ref
          .read(appLoggerProvider)
          .warning('Signing in failed: ${source.url}', error, stackTrace);
      state = AsyncData<BookSourceLoginState>(
        current.copyWith(
          isSubmitting: false,
          submitFailure: ParseFailureKind.parseFailed,
        ),
      );
    }
  }

  /// Runs one button row's action; an absolute address is the page's job (it opens a browser).
  Future<void> runAction(LoginField field) async {
    final BookSourceLoginState? current = state.value;
    final String action = field.action ?? '';
    if (current == null || action.isEmpty || current.isSubmitting) {
      return;
    }
    state = AsyncData<BookSourceLoginState>(
      current.copyWith(isSubmitting: true, submitFailure: null),
    );

    final ParseResult<Object?> result;
    try {
      result = await ref
          .read(signInProvider)
          .runAction(
            field,
            source: current.source.source,
            info: current.values,
            bookName: current.source.source.name,
            bookUrl: current.source.source.url,
          );
    } on Exception catch (error, stackTrace) {
      ref
          .read(appLoggerProvider)
          .warning('A login button failed', error, stackTrace);
      state = AsyncData<BookSourceLoginState>(
        current.copyWith(
          isSubmitting: false,
          submitFailure: ParseFailureKind.parseFailed,
        ),
      );

      return;
    }

    state = AsyncData<BookSourceLoginState>(switch (result) {
      ParseSuccess<Object?>() => current.copyWith(isSubmitting: false),
      ParseFailure<Object?>(:final ParseFailureKind kind) => current.copyWith(
        isSubmitting: false,
        submitFailure: kind,
      ),
    });
  }
}

/// The placeholder source used when the row is gone (the page shows a failure instead of it).
final BookSource _emptySource = BookSource.fromLegadoJson(<String, Object?>{
  'bookSourceName': '',
  'bookSourceUrl': '',
  'ruleSearch': <String, Object?>{},
  'ruleToc': <String, Object?>{},
  'ruleContent': <String, Object?>{},
});
