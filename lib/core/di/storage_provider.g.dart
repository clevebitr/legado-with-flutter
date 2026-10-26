// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'storage_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the application database.

@ProviderFor(readerDatabase)
final readerDatabaseProvider = ReaderDatabaseProvider._();

/// Provides the application database.

final class ReaderDatabaseProvider
    extends $FunctionalProvider<ReaderDatabase, ReaderDatabase, ReaderDatabase>
    with $Provider<ReaderDatabase> {
  /// Provides the application database.
  ReaderDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'readerDatabaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$readerDatabaseHash();

  @$internal
  @override
  $ProviderElement<ReaderDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ReaderDatabase create(Ref ref) {
    return readerDatabase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReaderDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReaderDatabase>(value),
    );
  }
}

String _$readerDatabaseHash() => r'aa0db4441a56db6a50c6a27d92daa7a9fe72108d';

/// Provides the TTL cache for network payloads.

@ProviderFor(cacheDao)
final cacheDaoProvider = CacheDaoProvider._();

/// Provides the TTL cache for network payloads.

final class CacheDaoProvider
    extends $FunctionalProvider<CacheDao, CacheDao, CacheDao>
    with $Provider<CacheDao> {
  /// Provides the TTL cache for network payloads.
  CacheDaoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cacheDaoProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cacheDaoHash();

  @$internal
  @override
  $ProviderElement<CacheDao> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CacheDao create(Ref ref) {
    return cacheDao(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CacheDao value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CacheDao>(value),
    );
  }
}

String _$cacheDaoHash() => r'7fcdcf8b71b7a43746acab008882baa25d54ffc3';

/// Provides the DAO of the imported book sources.

@ProviderFor(bookSourceDao)
final bookSourceDaoProvider = BookSourceDaoProvider._();

/// Provides the DAO of the imported book sources.

final class BookSourceDaoProvider
    extends $FunctionalProvider<BookSourceDao, BookSourceDao, BookSourceDao>
    with $Provider<BookSourceDao> {
  /// Provides the DAO of the imported book sources.
  BookSourceDaoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookSourceDaoProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookSourceDaoHash();

  @$internal
  @override
  $ProviderElement<BookSourceDao> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BookSourceDao create(Ref ref) {
    return bookSourceDao(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BookSourceDao value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BookSourceDao>(value),
    );
  }
}

String _$bookSourceDaoHash() => r'b2ca7154a6b8bd15f046c93f5d1dac09c61330e4';

/// Provides the DAO of the shelf and the reading progress.

@ProviderFor(bookshelfDao)
final bookshelfDaoProvider = BookshelfDaoProvider._();

/// Provides the DAO of the shelf and the reading progress.

final class BookshelfDaoProvider
    extends $FunctionalProvider<BookshelfDao, BookshelfDao, BookshelfDao>
    with $Provider<BookshelfDao> {
  /// Provides the DAO of the shelf and the reading progress.
  BookshelfDaoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookshelfDaoProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookshelfDaoHash();

  @$internal
  @override
  $ProviderElement<BookshelfDao> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BookshelfDao create(Ref ref) {
    return bookshelfDao(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BookshelfDao value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BookshelfDao>(value),
    );
  }
}

String _$bookshelfDaoHash() => r'7bbfb5bc863cc03300300b2963bc12e607a7f18e';

/// Provides the DAO of the shelf groups.

@ProviderFor(shelfGroupDao)
final shelfGroupDaoProvider = ShelfGroupDaoProvider._();

/// Provides the DAO of the shelf groups.

final class ShelfGroupDaoProvider
    extends $FunctionalProvider<ShelfGroupDao, ShelfGroupDao, ShelfGroupDao>
    with $Provider<ShelfGroupDao> {
  /// Provides the DAO of the shelf groups.
  ShelfGroupDaoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'shelfGroupDaoProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$shelfGroupDaoHash();

  @$internal
  @override
  $ProviderElement<ShelfGroupDao> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ShelfGroupDao create(Ref ref) {
    return shelfGroupDao(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ShelfGroupDao value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ShelfGroupDao>(value),
    );
  }
}

String _$shelfGroupDaoHash() => r'1f962e6bb0da8c17fa8f3e08fd657b32ed1099ed';

/// Provides the DAO of the bookmarks.

@ProviderFor(bookmarkDao)
final bookmarkDaoProvider = BookmarkDaoProvider._();

/// Provides the DAO of the bookmarks.

final class BookmarkDaoProvider
    extends $FunctionalProvider<BookmarkDao, BookmarkDao, BookmarkDao>
    with $Provider<BookmarkDao> {
  /// Provides the DAO of the bookmarks.
  BookmarkDaoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bookmarkDaoProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bookmarkDaoHash();

  @$internal
  @override
  $ProviderElement<BookmarkDao> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BookmarkDao create(Ref ref) {
    return bookmarkDao(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BookmarkDao value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BookmarkDao>(value),
    );
  }
}

String _$bookmarkDaoHash() => r'8d7c43d836b60c09ffae41e82b779fad9d88e896';

/// Provides the DAO of the persisted cookie jar.

@ProviderFor(cookieDao)
final cookieDaoProvider = CookieDaoProvider._();

/// Provides the DAO of the persisted cookie jar.

final class CookieDaoProvider
    extends $FunctionalProvider<CookieDao, CookieDao, CookieDao>
    with $Provider<CookieDao> {
  /// Provides the DAO of the persisted cookie jar.
  CookieDaoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cookieDaoProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cookieDaoHash();

  @$internal
  @override
  $ProviderElement<CookieDao> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CookieDao create(Ref ref) {
    return cookieDao(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CookieDao value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CookieDao>(value),
    );
  }
}

String _$cookieDaoHash() => r'2a42a016b49c5d2114c6a5a89ffb598b669d740c';

/// Provides the storage behind the cookie jar.

@ProviderFor(cookieStore)
final cookieStoreProvider = CookieStoreProvider._();

/// Provides the storage behind the cookie jar.

final class CookieStoreProvider
    extends $FunctionalProvider<CookieStore, CookieStore, CookieStore>
    with $Provider<CookieStore> {
  /// Provides the storage behind the cookie jar.
  CookieStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cookieStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cookieStoreHash();

  @$internal
  @override
  $ProviderElement<CookieStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CookieStore create(Ref ref) {
    return cookieStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CookieStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CookieStore>(value),
    );
  }
}

String _$cookieStoreHash() => r'e3128f6c0f9a0a2cd719894aa2a6df4aa54bdb47';

/// Provides the DAO of the per-source variables (`source.getVariable`, ADR-0076 §决策 1).

@ProviderFor(sourceVariableDao)
final sourceVariableDaoProvider = SourceVariableDaoProvider._();

/// Provides the DAO of the per-source variables (`source.getVariable`, ADR-0076 §决策 1).

final class SourceVariableDaoProvider
    extends
        $FunctionalProvider<
          SourceVariableDao,
          SourceVariableDao,
          SourceVariableDao
        >
    with $Provider<SourceVariableDao> {
  /// Provides the DAO of the per-source variables (`source.getVariable`, ADR-0076 §决策 1).
  SourceVariableDaoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sourceVariableDaoProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sourceVariableDaoHash();

  @$internal
  @override
  $ProviderElement<SourceVariableDao> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SourceVariableDao create(Ref ref) {
    return sourceVariableDao(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SourceVariableDao value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SourceVariableDao>(value),
    );
  }
}

String _$sourceVariableDaoHash() => r'd70a044b4e44310913262cb929888401d27febb5';

/// Provides the per-source variable store the rule engine seeds jobs from and the bridge writes
/// through.
///
/// `keepAlive` matters: the store holds an in-memory copy per source, and a rebuild between two
/// stages (search → detail → toc) would read the table again for no reason.

@ProviderFor(sourceVariableStore)
final sourceVariableStoreProvider = SourceVariableStoreProvider._();

/// Provides the per-source variable store the rule engine seeds jobs from and the bridge writes
/// through.
///
/// `keepAlive` matters: the store holds an in-memory copy per source, and a rebuild between two
/// stages (search → detail → toc) would read the table again for no reason.

final class SourceVariableStoreProvider
    extends
        $FunctionalProvider<
          SourceVariableStore,
          SourceVariableStore,
          SourceVariableStore
        >
    with $Provider<SourceVariableStore> {
  /// Provides the per-source variable store the rule engine seeds jobs from and the bridge writes
  /// through.
  ///
  /// `keepAlive` matters: the store holds an in-memory copy per source, and a rebuild between two
  /// stages (search → detail → toc) would read the table again for no reason.
  SourceVariableStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sourceVariableStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sourceVariableStoreHash();

  @$internal
  @override
  $ProviderElement<SourceVariableStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SourceVariableStore create(Ref ref) {
    return sourceVariableStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SourceVariableStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SourceVariableStore>(value),
    );
  }
}

String _$sourceVariableStoreHash() =>
    r'6a781f1a467108c9c9da87d80111e7f84197b07b';

/// Provides the DAO of the reading records.

@ProviderFor(readRecordDao)
final readRecordDaoProvider = ReadRecordDaoProvider._();

/// Provides the DAO of the reading records.

final class ReadRecordDaoProvider
    extends $FunctionalProvider<ReadRecordDao, ReadRecordDao, ReadRecordDao>
    with $Provider<ReadRecordDao> {
  /// Provides the DAO of the reading records.
  ReadRecordDaoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'readRecordDaoProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$readRecordDaoHash();

  @$internal
  @override
  $ProviderElement<ReadRecordDao> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ReadRecordDao create(Ref ref) {
    return readRecordDao(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReadRecordDao value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReadRecordDao>(value),
    );
  }
}

String _$readRecordDaoHash() => r'96e142bea54bbe17d5271c8c20a11cd78f908dc9';

/// Provides the DAO of the user-editable rules (替换净化 / 目录 / 字典 / 高亮).

@ProviderFor(ruleDao)
final ruleDaoProvider = RuleDaoProvider._();

/// Provides the DAO of the user-editable rules (替换净化 / 目录 / 字典 / 高亮).

final class RuleDaoProvider
    extends $FunctionalProvider<RuleDao, RuleDao, RuleDao>
    with $Provider<RuleDao> {
  /// Provides the DAO of the user-editable rules (替换净化 / 目录 / 字典 / 高亮).
  RuleDaoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ruleDaoProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ruleDaoHash();

  @$internal
  @override
  $ProviderElement<RuleDao> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RuleDao create(Ref ref) {
    return ruleDao(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RuleDao value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RuleDao>(value),
    );
  }
}

String _$ruleDaoHash() => r'587caa574599184a2d3f9fd44b81cb72cc6d564f';

/// Provides the store user-picked images are copied into (`ADR-0075` §决策 1).

@ProviderFor(localImageStore)
final localImageStoreProvider = LocalImageStoreProvider._();

/// Provides the store user-picked images are copied into (`ADR-0075` §决策 1).

final class LocalImageStoreProvider
    extends
        $FunctionalProvider<LocalImageStore, LocalImageStore, LocalImageStore>
    with $Provider<LocalImageStore> {
  /// Provides the store user-picked images are copied into (`ADR-0075` §决策 1).
  LocalImageStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localImageStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localImageStoreHash();

  @$internal
  @override
  $ProviderElement<LocalImageStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LocalImageStore create(Ref ref) {
    return localImageStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LocalImageStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LocalImageStore>(value),
    );
  }
}

String _$localImageStoreHash() => r'c1b93eaa248f0c55fa99a1087ae2b42abb372661';
