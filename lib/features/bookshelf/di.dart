import 'package:flutter_reader/core/di/storage_provider.dart';
import 'package:flutter_reader/features/bookshelf/data/bookshelf_repository_impl.dart';
import 'package:flutter_reader/features/bookshelf/domain/repositories/bookshelf_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'di.g.dart';

/// Provides the shelf persistence (`docs/dev/roadmap.md` 5.4).
///
/// The composition root's `BookshelfWriter` adapter is the only consumer outside this feature;
/// the reader (5.3) will write progress through its own port, so this provider stays feature
/// internal (C-ARCH-2).
@riverpod
BookshelfRepository bookshelfRepository(Ref ref) =>
    BookshelfRepositoryImpl(dao: ref.watch(bookshelfDaoProvider));
