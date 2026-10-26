// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_messages_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the channel `java.toast` / `java.longToast` travel on (ADR-0076 §决策 1).
///
/// Defaults to the silent no-op: `core/` cannot show a widget, so the composition root overrides it
/// with the snack-bar implementation (`lib/app.dart`). A build without the override still runs every
/// rule — the message is logged by the bridge, only the toast is missing.

@ProviderFor(userMessages)
final userMessagesProvider = UserMessagesProvider._();

/// Provides the channel `java.toast` / `java.longToast` travel on (ADR-0076 §决策 1).
///
/// Defaults to the silent no-op: `core/` cannot show a widget, so the composition root overrides it
/// with the snack-bar implementation (`lib/app.dart`). A build without the override still runs every
/// rule — the message is logged by the bridge, only the toast is missing.

final class UserMessagesProvider
    extends $FunctionalProvider<UserMessages, UserMessages, UserMessages>
    with $Provider<UserMessages> {
  /// Provides the channel `java.toast` / `java.longToast` travel on (ADR-0076 §决策 1).
  ///
  /// Defaults to the silent no-op: `core/` cannot show a widget, so the composition root overrides it
  /// with the snack-bar implementation (`lib/app.dart`). A build without the override still runs every
  /// rule — the message is logged by the bridge, only the toast is missing.
  UserMessagesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userMessagesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userMessagesHash();

  @$internal
  @override
  $ProviderElement<UserMessages> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  UserMessages create(Ref ref) {
    return userMessages(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UserMessages value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UserMessages>(value),
    );
  }
}

String _$userMessagesHash() => r'7b597b66843e4b064168f5fcc5f8d1e990993f24';
