// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_source_import_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Runs one book source import from the form.

@ProviderFor(BookSourceImportNotifier)
final bookSourceImportProvider = BookSourceImportNotifierProvider._();

/// Runs one book source import from the form.
final class BookSourceImportNotifierProvider
    extends $NotifierProvider<BookSourceImportNotifier, BookSourceImportState> {
  /// Runs one book source import from the form.
  BookSourceImportNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookSourceImportProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookSourceImportNotifierHash();

  @$internal
  @override
  BookSourceImportNotifier create() => BookSourceImportNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BookSourceImportState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BookSourceImportState>(value),
    );
  }
}

String _$bookSourceImportNotifierHash() =>
    r'1f2730cf1775d20e5bc3866e07ff21691162b360';

/// Runs one book source import from the form.

abstract class _$BookSourceImportNotifier
    extends $Notifier<BookSourceImportState> {
  BookSourceImportState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<BookSourceImportState, BookSourceImportState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<BookSourceImportState, BookSourceImportState>,
              BookSourceImportState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
