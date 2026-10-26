// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_source_login_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Drives one source's login form.
///
/// The form comes from `loginUi` (resolved through the sandbox when it is itself a script), the
/// values live here, and a successful submit stores them on the source before running its `login()`.
/// Storing first is upstream's order and it matters: the script may read `source.getLoginInfo()`
/// itself, and the next page fetch has to see the same values.

@ProviderFor(BookSourceLogin)
final bookSourceLoginProvider = BookSourceLoginFamily._();

/// Drives one source's login form.
///
/// The form comes from `loginUi` (resolved through the sandbox when it is itself a script), the
/// values live here, and a successful submit stores them on the source before running its `login()`.
/// Storing first is upstream's order and it matters: the script may read `source.getLoginInfo()`
/// itself, and the next page fetch has to see the same values.
final class BookSourceLoginProvider
    extends $AsyncNotifierProvider<BookSourceLogin, BookSourceLoginState> {
  /// Drives one source's login form.
  ///
  /// The form comes from `loginUi` (resolved through the sandbox when it is itself a script), the
  /// values live here, and a successful submit stores them on the source before running its `login()`.
  /// Storing first is upstream's order and it matters: the script may read `source.getLoginInfo()`
  /// itself, and the next page fetch has to see the same values.
  BookSourceLoginProvider._({
    required BookSourceLoginFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'bookSourceLoginProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$bookSourceLoginHash();

  @override
  String toString() {
    return r'bookSourceLoginProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  BookSourceLogin create() => BookSourceLogin();

  @override
  bool operator ==(Object other) {
    return other is BookSourceLoginProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$bookSourceLoginHash() => r'1a6563c16f7a860827e5baaaf9e5301128bfa0f0';

/// Drives one source's login form.
///
/// The form comes from `loginUi` (resolved through the sandbox when it is itself a script), the
/// values live here, and a successful submit stores them on the source before running its `login()`.
/// Storing first is upstream's order and it matters: the script may read `source.getLoginInfo()`
/// itself, and the next page fetch has to see the same values.

final class BookSourceLoginFamily extends $Family
    with
        $ClassFamilyOverride<
          BookSourceLogin,
          AsyncValue<BookSourceLoginState>,
          BookSourceLoginState,
          FutureOr<BookSourceLoginState>,
          int
        > {
  BookSourceLoginFamily._()
    : super(
        retry: null,
        name: r'bookSourceLoginProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Drives one source's login form.
  ///
  /// The form comes from `loginUi` (resolved through the sandbox when it is itself a script), the
  /// values live here, and a successful submit stores them on the source before running its `login()`.
  /// Storing first is upstream's order and it matters: the script may read `source.getLoginInfo()`
  /// itself, and the next page fetch has to see the same values.

  BookSourceLoginProvider call(int sourceId) =>
      BookSourceLoginProvider._(argument: sourceId, from: this);

  @override
  String toString() => r'bookSourceLoginProvider';
}

/// Drives one source's login form.
///
/// The form comes from `loginUi` (resolved through the sandbox when it is itself a script), the
/// values live here, and a successful submit stores them on the source before running its `login()`.
/// Storing first is upstream's order and it matters: the script may read `source.getLoginInfo()`
/// itself, and the next page fetch has to see the same values.

abstract class _$BookSourceLogin extends $AsyncNotifier<BookSourceLoginState> {
  late final _$args = ref.$arg as int;
  int get sourceId => _$args;

  FutureOr<BookSourceLoginState> build(int sourceId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<BookSourceLoginState>, BookSourceLoginState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<BookSourceLoginState>,
                BookSourceLoginState
              >,
              AsyncValue<BookSourceLoginState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
