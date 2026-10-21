// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bookshelf_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The shelf, and the only place that changes it (`docs/dev/roadmap.md` 5.4)。
///
/// `keepAlive` for the same reason as the source list: the shelf is read on every visit and a
/// reload after each mutation is an explicit decision, while the writes below are the only
/// writers (C-STATE-6: the state itself stays an immutable list).
///
/// The mutations answer [ParseResult] instead of throwing, because the shelf is written from
/// another feature through `BookshelfWriter` (ADR-0041 §决策 2) and that port has to report a
/// failure without turning it into an exception.

@ProviderFor(Bookshelf)
final bookshelfProvider = BookshelfProvider._();

/// The shelf, and the only place that changes it (`docs/dev/roadmap.md` 5.4)。
///
/// `keepAlive` for the same reason as the source list: the shelf is read on every visit and a
/// reload after each mutation is an explicit decision, while the writes below are the only
/// writers (C-STATE-6: the state itself stays an immutable list).
///
/// The mutations answer [ParseResult] instead of throwing, because the shelf is written from
/// another feature through `BookshelfWriter` (ADR-0041 §决策 2) and that port has to report a
/// failure without turning it into an exception.
final class BookshelfProvider
    extends $AsyncNotifierProvider<Bookshelf, List<ShelvedBook>> {
  /// The shelf, and the only place that changes it (`docs/dev/roadmap.md` 5.4)。
  ///
  /// `keepAlive` for the same reason as the source list: the shelf is read on every visit and a
  /// reload after each mutation is an explicit decision, while the writes below are the only
  /// writers (C-STATE-6: the state itself stays an immutable list).
  ///
  /// The mutations answer [ParseResult] instead of throwing, because the shelf is written from
  /// another feature through `BookshelfWriter` (ADR-0041 §决策 2) and that port has to report a
  /// failure without turning it into an exception.
  BookshelfProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookshelfProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookshelfHash();

  @$internal
  @override
  Bookshelf create() => Bookshelf();
}

String _$bookshelfHash() => r'937d7c42f89df3095cb4026adaaa0ceac27edaa1';

/// The shelf, and the only place that changes it (`docs/dev/roadmap.md` 5.4)。
///
/// `keepAlive` for the same reason as the source list: the shelf is read on every visit and a
/// reload after each mutation is an explicit decision, while the writes below are the only
/// writers (C-STATE-6: the state itself stays an immutable list).
///
/// The mutations answer [ParseResult] instead of throwing, because the shelf is written from
/// another feature through `BookshelfWriter` (ADR-0041 §决策 2) and that port has to report a
/// failure without turning it into an exception.

abstract class _$Bookshelf extends $AsyncNotifier<List<ShelvedBook>> {
  FutureOr<List<ShelvedBook>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<ShelvedBook>>, List<ShelvedBook>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<ShelvedBook>>, List<ShelvedBook>>,
              AsyncValue<List<ShelvedBook>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
