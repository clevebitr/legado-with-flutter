import 'package:freezed_annotation/freezed_annotation.dart';

part 'login_form.freezed.dart';

/// What one row of a source's `loginUi` form is
/// (`docs/dev/roadmap.md` M22, ADR-0072 §决策 3).
enum LoginFieldType {
  /// A single-line text input (upstream's default when `type` is missing).
  text,

  /// A masked input.
  password,

  /// A boolean switch.
  toggle,

  /// One of [LoginField.options].
  select,

  /// A button: it contributes no value, it runs [LoginField.action] (or opens it).
  button,
}

/// One row of the login form, already resolved enough to render.
///
/// [title] is what the page shows: upstream's `viewName` when it produced one (a quoted literal or a
/// script), otherwise [name]. [action] is kept for buttons only — it is either a URL to open or a
/// script to run on top of the source's `login()` script.
@freezed
abstract class LoginField with _$LoginField {
  /// Creates one field.
  const factory LoginField({
    /// The key the value is stored under (upstream's `name`).
    required String name,

    /// What the page shows.
    required String title,

    /// Which control to render.
    required LoginFieldType type,

    /// The choices of a [LoginFieldType.select], in order.
    @Default(<String>[]) List<String> options,

    /// The starting value (upstream's `default`).
    @Default('') String initialValue,

    /// What a [LoginFieldType.button] does, verbatim.
    String? action,
  }) = _LoginField;
}

/// One source's login form (`docs/dev/roadmap.md` M22, ADR-0072 §决策 3).
@freezed
abstract class LoginForm with _$LoginForm {
  const LoginForm._();

  /// Creates a form.
  const factory LoginForm({
    /// The rows, in the file's order.
    required List<LoginField> fields,
  }) = _LoginForm;

  /// Whether the form has anything to render.
  bool get isEmpty => fields.isEmpty;

  /// Whether any row collects a value (a form of buttons alone collects nothing).
  bool get hasInputs =>
      fields.any((LoginField field) => field.type != LoginFieldType.button);
}
