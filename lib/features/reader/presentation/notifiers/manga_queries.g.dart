// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'manga_queries.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Which reader page opens `sourceUrl` (`docs/dev/roadmap.md` §3.10 M16).
///
/// It is the async seam `ReaderPage` waits on before building either body: the answer decides
/// whether a text request or an image request is the right one, so guessing "text" while the port
/// loads would fetch a chapter body nobody shows.

@ProviderFor(readerSourceKind)
final readerSourceKindProvider = ReaderSourceKindFamily._();

/// Which reader page opens `sourceUrl` (`docs/dev/roadmap.md` §3.10 M16).
///
/// It is the async seam `ReaderPage` waits on before building either body: the answer decides
/// whether a text request or an image request is the right one, so guessing "text" while the port
/// loads would fetch a chapter body nobody shows.

final class ReaderSourceKindProvider
    extends
        $FunctionalProvider<
          AsyncValue<ParseResult<ReaderSourceKind>>,
          ParseResult<ReaderSourceKind>,
          FutureOr<ParseResult<ReaderSourceKind>>
        >
    with
        $FutureModifier<ParseResult<ReaderSourceKind>>,
        $FutureProvider<ParseResult<ReaderSourceKind>> {
  /// Which reader page opens `sourceUrl` (`docs/dev/roadmap.md` §3.10 M16).
  ///
  /// It is the async seam `ReaderPage` waits on before building either body: the answer decides
  /// whether a text request or an image request is the right one, so guessing "text" while the port
  /// loads would fetch a chapter body nobody shows.
  ReaderSourceKindProvider._({
    required ReaderSourceKindFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'readerSourceKindProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$readerSourceKindHash();

  @override
  String toString() {
    return r'readerSourceKindProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ParseResult<ReaderSourceKind>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ParseResult<ReaderSourceKind>> create(Ref ref) {
    final argument = this.argument as String;
    return readerSourceKind(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ReaderSourceKindProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$readerSourceKindHash() => r'6719125f6795e19e65b9a4aaa28859d38d3f657a';

/// Which reader page opens `sourceUrl` (`docs/dev/roadmap.md` §3.10 M16).
///
/// It is the async seam `ReaderPage` waits on before building either body: the answer decides
/// whether a text request or an image request is the right one, so guessing "text" while the port
/// loads would fetch a chapter body nobody shows.

final class ReaderSourceKindFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<ParseResult<ReaderSourceKind>>,
          String
        > {
  ReaderSourceKindFamily._()
    : super(
        retry: null,
        name: r'readerSourceKindProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Which reader page opens `sourceUrl` (`docs/dev/roadmap.md` §3.10 M16).
  ///
  /// It is the async seam `ReaderPage` waits on before building either body: the answer decides
  /// whether a text request or an image request is the right one, so guessing "text" while the port
  /// loads would fetch a chapter body nobody shows.

  ReaderSourceKindProvider call(String sourceUrl) =>
      ReaderSourceKindProvider._(argument: sourceUrl, from: this);

  @override
  String toString() => r'readerSourceKindProvider';
}

/// The images of one manga chapter (`docs/dev/roadmap.md` §3.10 M16).
///
/// Fetch-on-build like [readerContent]: leaving the chapter disposes the request instead of letting
/// a detached continuation write into a dead state. The chapter title comes from the already-loaded
/// chapter list, exactly as the text body does, because it feeds `java.get('title')`.

@ProviderFor(mangaPages)
final mangaPagesProvider = MangaPagesFamily._();

/// The images of one manga chapter (`docs/dev/roadmap.md` §3.10 M16).
///
/// Fetch-on-build like [readerContent]: leaving the chapter disposes the request instead of letting
/// a detached continuation write into a dead state. The chapter title comes from the already-loaded
/// chapter list, exactly as the text body does, because it feeds `java.get('title')`.

final class MangaPagesProvider
    extends
        $FunctionalProvider<
          AsyncValue<ParseResult<List<ReadingPage>>>,
          ParseResult<List<ReadingPage>>,
          FutureOr<ParseResult<List<ReadingPage>>>
        >
    with
        $FutureModifier<ParseResult<List<ReadingPage>>>,
        $FutureProvider<ParseResult<List<ReadingPage>>> {
  /// The images of one manga chapter (`docs/dev/roadmap.md` §3.10 M16).
  ///
  /// Fetch-on-build like [readerContent]: leaving the chapter disposes the request instead of letting
  /// a detached continuation write into a dead state. The chapter title comes from the already-loaded
  /// chapter list, exactly as the text body does, because it feeds `java.get('title')`.
  MangaPagesProvider._({
    required MangaPagesFamily super.from,
    required (ReaderBook, String) super.argument,
  }) : super(
         retry: null,
         name: r'mangaPagesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$mangaPagesHash();

  @override
  String toString() {
    return r'mangaPagesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ParseResult<List<ReadingPage>>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<ParseResult<List<ReadingPage>>> create(Ref ref) {
    final argument = this.argument as (ReaderBook, String);
    return mangaPages(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MangaPagesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$mangaPagesHash() => r'c288cafb599f7f87b797d3329236233a78b12002';

/// The images of one manga chapter (`docs/dev/roadmap.md` §3.10 M16).
///
/// Fetch-on-build like [readerContent]: leaving the chapter disposes the request instead of letting
/// a detached continuation write into a dead state. The chapter title comes from the already-loaded
/// chapter list, exactly as the text body does, because it feeds `java.get('title')`.

final class MangaPagesFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<ParseResult<List<ReadingPage>>>,
          (ReaderBook, String)
        > {
  MangaPagesFamily._()
    : super(
        retry: null,
        name: r'mangaPagesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The images of one manga chapter (`docs/dev/roadmap.md` §3.10 M16).
  ///
  /// Fetch-on-build like [readerContent]: leaving the chapter disposes the request instead of letting
  /// a detached continuation write into a dead state. The chapter title comes from the already-loaded
  /// chapter list, exactly as the text body does, because it feeds `java.get('title')`.

  MangaPagesProvider call((ReaderBook, String) request) =>
      MangaPagesProvider._(argument: request, from: this);

  @override
  String toString() => r'mangaPagesProvider';
}
