import 'dart:convert';

import 'package:flutter_reader/core/storage/book_source_dao.dart';
import 'package:flutter_reader/core/storage/bookmark_dao.dart';
import 'package:flutter_reader/core/storage/bookshelf_dao.dart';
import 'package:flutter_reader/core/storage/database.dart';
import 'package:flutter_reader/core/storage/preference_store.dart';
import 'package:flutter_reader/core/storage/read_record_dao.dart';
import 'package:flutter_reader/core/storage/rule_dao.dart';
import 'package:flutter_reader/core/storage/shelf_group_dao.dart';
import 'package:flutter_reader/features/backup/data/backup_row_codec.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_contents.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_restore_report.dart';
import 'package:flutter_reader/features/backup/domain/entities/backup_table.dart';
import 'package:flutter_reader/features/backup/domain/entities/restore_mode.dart';
import 'package:flutter_reader/features/backup/domain/repositories/backup_repository.dart';

/// [BackupRepository] on top of the Drift DAOs and the preference store
/// (`docs/dev/roadmap.md` M22, ADR-0073).
///
/// Two rules shape everything below:
///
/// * **Rows are addressed by their natural key** (`ADR-0073` §决策 3). Synthetic `id`s belong to one
///   installation, so they are never exported, and a group is carried as a name because the id it
///   has here means nothing there.
/// * **A restore merges and never deletes.** An existing row keeps the state the user has here
///   unless the backup is the authority for that column (progress advances, sources refresh their
///   payload), and a row this build cannot read is skipped rather than failing the whole table.
final class BackupRepositoryImpl implements BackupRepository {
  /// Creates the repository.
  const BackupRepositoryImpl({
    required this._database,
    required this._sources,
    required this._books,
    required this._groups,
    required this._bookmarks,
    required this._records,
    required this._rules,
    required this._preferences,
  });

  final ReaderDatabase _database;
  final BookSourceDao _sources;
  final BookshelfDao _books;
  final ShelfGroupDao _groups;
  final BookmarkDao _bookmarks;
  final ReadRecordDao _records;
  final RuleDao _rules;
  final PreferenceStore _preferences;

  @override
  Future<BackupContents> collect() async {
    final List<BookGroupRow> groups = await _groups.findAll();
    final Map<int, String> groupNames = <int, String>{
      for (final BookGroupRow group in groups) group.id: group.name,
    };

    return BackupContents(
      tables: <BackupTable, List<Map<String, Object?>>>{
        BackupTable.bookSources: <Map<String, Object?>>[
          for (final BookSourceRow source in await _sources.findAll())
            <String, Object?>{
              'url': source.url,
              'fingerprint': source.fingerprint,
              'payload': source.payload,
              'name': source.name,
              'groupName': source.groupName,
              'comment': source.comment,
              'sourceType': source.sourceType,
              'isEnabled': source.isEnabled,
              'customOrder': source.customOrder,
              'isExploreEnabled': source.isExploreEnabled,
              'weight': source.weight,
              'lastUpdateTime': source.lastUpdateTime,
              'respondTime': source.respondTime,
              'loginInfo': source.loginInfo,
              'loginHeader': source.loginHeader,
              'importedAt': dateToJson(source.importedAt),
              'updatedAt': dateToJson(source.updatedAt),
            },
        ],
        BackupTable.books: <Map<String, Object?>>[
          for (final BookshelfRow row in await _books.findAll())
            <String, Object?>{
              'sourceUrl': row.book.sourceUrl,
              'bookUrl': row.book.bookUrl,
              'tocUrl': row.book.tocUrl,
              'name': row.book.name,
              'author': row.book.author,
              'kind': row.book.kind,
              'coverUrl': row.book.coverUrl,
              'intro': row.book.intro,
              'lastChapter': row.book.lastChapter,
              'status': row.book.status,
              'isPinned': row.book.isPinned,
              // 分组以名字导出：合成 id 换了设备就没有意义（ADR-0073 §决策 3）。
              'groupName': row.book.groupId == null
                  ? null
                  : groupNames[row.book.groupId],
              'customCoverPath': row.book.customCoverPath,
              'customIntro': row.book.customIntro,
              'addedAt': dateToJson(row.book.addedAt),
              'updatedAt': dateToJson(row.book.updatedAt),
            },
        ],
        BackupTable.readingProgress: <Map<String, Object?>>[
          for (final ReadingProgressRow progress
              in await _books.findAllProgress())
            <String, Object?>{
              'sourceUrl': progress.sourceUrl,
              'bookUrl': progress.bookUrl,
              'chapterUrl': progress.chapterUrl,
              'chapterName': progress.chapterName,
              'charOffset': progress.charOffset,
              'updatedAt': dateToJson(progress.updatedAt),
            },
        ],
        BackupTable.bookGroups: <Map<String, Object?>>[
          for (final BookGroupRow group in groups)
            <String, Object?>{
              'name': group.name,
              'sortOrder': group.sortOrder,
              'createdAt': dateToJson(group.createdAt),
            },
        ],
        BackupTable.bookmarks: <Map<String, Object?>>[
          for (final BookmarkRow bookmark in await _bookmarks.findAll())
            <String, Object?>{
              'sourceUrl': bookmark.sourceUrl,
              'bookUrl': bookmark.bookUrl,
              'bookName': bookmark.bookName,
              'tocUrl': bookmark.tocUrl,
              'chapterUrl': bookmark.chapterUrl,
              'chapterName': bookmark.chapterName,
              'chapterIndex': bookmark.chapterIndex,
              'charOffset': bookmark.charOffset,
              'excerpt': bookmark.excerpt,
              'createdAt': dateToJson(bookmark.createdAt),
            },
        ],
        BackupTable.readRecords: <Map<String, Object?>>[
          for (final ReadRecordRow record in await _records.findAll())
            <String, Object?>{
              'sourceUrl': record.sourceUrl,
              'bookUrl': record.bookUrl,
              'bookName': record.bookName,
              'chapterUrl': record.chapterUrl,
              'chapterName': record.chapterName,
              'startedAt': dateToJson(record.startedAt),
              'endedAt': dateToJson(record.endedAt),
              'durationSeconds': record.durationSeconds,
            },
        ],
        BackupTable.rules: <Map<String, Object?>>[
          for (final RuleRow rule in await _rules.findAll())
            <String, Object?>{
              'kind': rule.kind,
              'name': rule.name,
              // payload 是**文本**而不是对象：库里存的就是这段 JSON，原样带走才能保证未知键保真。
              'payload': rule.payload,
              'isEnabled': rule.isEnabled,
              'isBuiltIn': rule.isBuiltIn,
              'sortOrder': rule.sortOrder,
              'createdAt': dateToJson(rule.createdAt),
            },
        ],
      },
      preferences: _preferences.snapshot(),
    );
  }

  @override
  Future<BackupRestoreReport> restore(
    BackupContents contents, {
    RestoreMode mode = RestoreMode.merge,
  }) =>
      // 一个事务覆盖全部表与设置：任何一步抛错都整次不落库（ADR-0073 §决策 3）。
      _database.transaction(() async {
        final Map<BackupTable, BackupTableOutcome> outcomes =
            <BackupTable, BackupTableOutcome>{};

        if (mode == RestoreMode.overwrite) {
          await _clearTables();
        }

        outcomes[BackupTable.bookGroups] = await _restoreGroups(contents);
        outcomes[BackupTable.books] = await _restoreBooks(contents);
        outcomes[BackupTable.readingProgress] = await _restoreProgress(
          contents,
        );
        outcomes[BackupTable.bookmarks] = await _restoreBookmarks(contents);
        outcomes[BackupTable.readRecords] = await _restoreReadRecords(contents);
        outcomes[BackupTable.rules] = await _restoreRules(contents);
        outcomes[BackupTable.bookSources] = await _restoreSources(contents);
        final int preferencesWritten = await _preferences.writeAll(
          contents.preferences,
        );

        return BackupRestoreReport(
          outcomes: outcomes,
          preferencesWritten: preferencesWritten,
        );
      });

  /// Empties the seven tables before an overwrite restore writes them back.
  ///
  /// `preferences` is deliberately not touched: it has no natural key, so 「清空」 would mean deleting
  /// keys this build does not understand (ADR-0074 §决策 3).
  Future<void> _clearTables() async {
    await _books.deleteAll();
    await _bookmarks.deleteAll();
    await _records.deleteAll();
    await _rules.deleteAll();
    // 分组要在书架之后清：书架行没了，group id 引用也一起没了。
    await _groups.deleteAll();
    await _sources.deleteAll();
  }

  Future<BackupTableOutcome> _restoreGroups(BackupContents contents) async {
    final _Counter counter = _Counter();
    final List<BookGroupRow> existing = await _groups.findAll();
    var nextOrder = existing.isEmpty
        ? 0
        : existing
                  .map((BookGroupRow group) => group.sortOrder)
                  .reduce((int a, int b) => a > b ? a : b) +
              1;

    for (final Map<String, Object?> row in _rowsOf(
      contents,
      BackupTable.bookGroups,
    )) {
      try {
        final String name = stringOf(row, 'name');
        if (await _groups.findByName(name) != null) {
          counter.skipped += 1;
          continue;
        }
        await _groups.insertNew(
          name: name,
          // 备份里的排序号可能与本地已有分组冲突；排在现有分组之后更可预期。
          sortOrder: nextOrder,
          createdAt: optionalDateOf(row, 'createdAt'),
        );
        nextOrder += 1;
        counter.inserted += 1;
      } on BadBackupRow {
        counter.skipped += 1;
      }
    }

    return counter.outcome;
  }

  Future<BackupTableOutcome> _restoreBooks(BackupContents contents) async {
    final _Counter counter = _Counter();
    final Map<String, int> groupIds = <String, int>{
      for (final BookGroupRow group in await _groups.findAll())
        group.name: group.id,
    };

    for (final Map<String, Object?> row in _rowsOf(
      contents,
      BackupTable.books,
    )) {
      try {
        final String sourceUrl = stringOf(row, 'sourceUrl');
        final String bookUrl = stringOf(row, 'bookUrl');
        final String name = stringOf(row, 'name');
        final int? groupId = await _groupIdOf(
          optionalStringOf(row, 'groupName'),
          groupIds,
        );
        final BookRow? existing = await _books.findIdentity(
          sourceUrl: sourceUrl,
          bookUrl: bookUrl,
        );

        if (existing == null) {
          final int id = await _books.insertNew(
            sourceUrl: sourceUrl,
            bookUrl: bookUrl,
            tocUrl: optionalStringOf(row, 'tocUrl'),
            name: name,
            author: optionalStringOf(row, 'author'),
            kind: optionalStringOf(row, 'kind'),
            coverUrl: optionalStringOf(row, 'coverUrl'),
            intro: optionalStringOf(row, 'intro'),
            lastChapter: optionalStringOf(row, 'lastChapter'),
            customIntro: optionalStringOf(row, 'customIntro'),
            addedAt: optionalDateOf(row, 'addedAt'),
            updatedAt: optionalDateOf(row, 'updatedAt'),
          );
          await _books.restoreUserState(
            id: id,
            status: optionalIntOf(row, 'status') ?? 0,
            isPinned: optionalBoolOf(row, 'isPinned', fallback: false),
            groupId: groupId,
            customCoverPath: optionalStringOf(row, 'customCoverPath'),
            customIntro: optionalStringOf(row, 'customIntro'),
          );
          counter.inserted += 1;
          continue;
        }

        // 已存在的书：只覆盖用户态。备份没有的值保留本地（合并而不是回滚）。
        await _books.restoreUserState(
          id: existing.id,
          status: optionalIntOf(row, 'status') ?? existing.status,
          isPinned: optionalBoolOf(
            row,
            'isPinned',
            fallback: existing.isPinned,
          ),
          groupId: groupId ?? existing.groupId,
          customCoverPath:
              optionalStringOf(row, 'customCoverPath') ??
              existing.customCoverPath,
          customIntro: optionalStringOf(row, 'customIntro'),
          tocUrl: existing.tocUrl == null
              ? optionalStringOf(row, 'tocUrl')
              : null,
        );
        counter.updated += 1;
      } on BadBackupRow {
        counter.skipped += 1;
      }
    }

    return counter.outcome;
  }

  Future<BackupTableOutcome> _restoreProgress(BackupContents contents) async {
    final _Counter counter = _Counter();

    for (final Map<String, Object?> row in _rowsOf(
      contents,
      BackupTable.readingProgress,
    )) {
      try {
        final String sourceUrl = stringOf(row, 'sourceUrl');
        final String bookUrl = stringOf(row, 'bookUrl');
        final String chapterUrl = stringOf(row, 'chapterUrl');
        final DateTime? updatedAt = optionalDateOf(row, 'updatedAt');
        final ReadingProgressRow? existing = await _books.findProgress(
          sourceUrl: sourceUrl,
          bookUrl: bookUrl,
        );

        if (existing != null &&
            (updatedAt == null || !updatedAt.isAfter(existing.updatedAt))) {
          // 不把用户往回拨：本地读得比备份更晚时，本地进度就是更新的那个。
          counter.skipped += 1;
          continue;
        }

        await _books.upsertProgress(
          sourceUrl: sourceUrl,
          bookUrl: bookUrl,
          chapterUrl: chapterUrl,
          chapterName: optionalStringOf(row, 'chapterName'),
          charOffset: optionalIntOf(row, 'charOffset') ?? 0,
          updatedAt: updatedAt,
        );
        if (existing == null) {
          counter.inserted += 1;
        } else {
          counter.updated += 1;
        }
      } on BadBackupRow {
        counter.skipped += 1;
      }
    }

    return counter.outcome;
  }

  Future<BackupTableOutcome> _restoreBookmarks(BackupContents contents) async {
    final _Counter counter = _Counter();

    for (final Map<String, Object?> row in _rowsOf(
      contents,
      BackupTable.bookmarks,
    )) {
      try {
        final String sourceUrl = stringOf(row, 'sourceUrl');
        final String bookUrl = stringOf(row, 'bookUrl');
        final String chapterUrl = stringOf(row, 'chapterUrl');
        final int charOffset = optionalIntOf(row, 'charOffset') ?? 0;

        if (await _bookmarks.findAt(
              sourceUrl: sourceUrl,
              bookUrl: bookUrl,
              chapterUrl: chapterUrl,
              charOffset: charOffset,
            ) !=
            null) {
          counter.skipped += 1;
          continue;
        }

        await _bookmarks.insertNew(
          sourceUrl: sourceUrl,
          bookUrl: bookUrl,
          bookName: stringOf(row, 'bookName'),
          tocUrl: optionalStringOf(row, 'tocUrl'),
          chapterUrl: chapterUrl,
          chapterName: optionalStringOf(row, 'chapterName'),
          chapterIndex: optionalIntOf(row, 'chapterIndex') ?? 0,
          charOffset: charOffset,
          excerpt: optionalStringOf(row, 'excerpt'),
          createdAt: optionalDateOf(row, 'createdAt'),
        );
        counter.inserted += 1;
      } on BadBackupRow {
        counter.skipped += 1;
      }
    }

    return counter.outcome;
  }

  Future<BackupTableOutcome> _restoreReadRecords(
    BackupContents contents,
  ) async {
    final _Counter counter = _Counter();

    for (final Map<String, Object?> row in _rowsOf(
      contents,
      BackupTable.readRecords,
    )) {
      try {
        final String sourceUrl = stringOf(row, 'sourceUrl');
        final String bookUrl = stringOf(row, 'bookUrl');
        final DateTime startedAt = dateOf(row, 'startedAt');

        if (await _records.findSession(
              sourceUrl: sourceUrl,
              bookUrl: bookUrl,
              startedAt: startedAt,
            ) !=
            null) {
          counter.skipped += 1;
          continue;
        }

        await _records.insertNew(
          sourceUrl: sourceUrl,
          bookUrl: bookUrl,
          bookName: stringOf(row, 'bookName'),
          chapterUrl: optionalStringOf(row, 'chapterUrl'),
          chapterName: optionalStringOf(row, 'chapterName'),
          startedAt: startedAt,
          endedAt: dateOf(row, 'endedAt'),
          durationSeconds: optionalIntOf(row, 'durationSeconds') ?? 0,
        );
        counter.inserted += 1;
      } on BadBackupRow {
        counter.skipped += 1;
      }
    }

    return counter.outcome;
  }

  Future<BackupTableOutcome> _restoreRules(BackupContents contents) async {
    final _Counter counter = _Counter();

    for (final Map<String, Object?> row in _rowsOf(
      contents,
      BackupTable.rules,
    )) {
      try {
        final String kind = stringOf(row, 'kind');
        final String name = stringOf(row, 'name');
        final Map<String, Object?> payload = _payloadOf(row);

        if (await _rules.findByKindAndName(kind: kind, name: name) != null) {
          // 本地编辑胜过备份：同名同类的规则不动，避免覆盖用户调过的表达式。
          counter.skipped += 1;
          continue;
        }

        await _rules.insert(
          kind: kind,
          name: name,
          payload: payload,
          isEnabled: optionalBoolOf(row, 'isEnabled', fallback: true),
          isBuiltIn: optionalBoolOf(row, 'isBuiltIn', fallback: false),
          sortOrder: optionalIntOf(row, 'sortOrder'),
          now: optionalDateOf(row, 'createdAt'),
        );
        counter.inserted += 1;
      } on BadBackupRow {
        counter.skipped += 1;
      } on FormatException {
        // payload 不是 JSON 对象：这条规则读不出来，跳过它而不是失败整次恢复。
        counter.skipped += 1;
      }
    }

    return counter.outcome;
  }

  Future<BackupTableOutcome> _restoreSources(BackupContents contents) async {
    final _Counter counter = _Counter();

    for (final Map<String, Object?> row in _rowsOf(
      contents,
      BackupTable.bookSources,
    )) {
      try {
        final String url = stringOf(row, 'url');
        final String fingerprint = stringOf(row, 'fingerprint');
        final String payload = stringOf(row, 'payload');
        final BookSourceRow? existing = await _sources.findIdentity(
          url: url,
          fingerprint: fingerprint,
        );

        if (existing == null) {
          await _sources.insertNew(
            url: url,
            fingerprint: fingerprint,
            payload: payload,
            name: stringOf(row, 'name'),
            groupName: optionalStringOf(row, 'groupName'),
            sourceType: optionalIntOf(row, 'sourceType') ?? 0,
            isEnabled: optionalBoolOf(row, 'isEnabled', fallback: true),
            customOrder: optionalIntOf(row, 'customOrder') ?? 0,
            weight: optionalIntOf(row, 'weight') ?? 0,
            lastUpdateTime: optionalIntOf(row, 'lastUpdateTime'),
            respondTime: optionalIntOf(row, 'respondTime'),
            isExploreEnabled: optionalBoolOf(
              row,
              'isExploreEnabled',
              fallback: true,
            ),
            comment: optionalStringOf(row, 'comment'),
            loginInfo: optionalStringOf(row, 'loginInfo'),
            loginHeader: optionalStringOf(row, 'loginHeader'),
            importedAt: optionalDateOf(row, 'importedAt'),
            updatedAt: optionalDateOf(row, 'updatedAt'),
          );
          counter.inserted += 1;
          continue;
        }

        // 已存在：刷新 payload 与用户态；`customOrder` 不搬（本机的排序是用户在本机排的）。
        await _sources.refreshPayload(id: existing.id, payload: payload);
        await _sources.writeCheckState(
          id: existing.id,
          groupName: optionalStringOf(row, 'groupName') ?? existing.groupName,
          comment: optionalStringOf(row, 'comment') ?? existing.comment,
          respondTime:
              optionalIntOf(row, 'respondTime') ?? existing.respondTime,
        );
        await _sources.writeLoginInfo(
          id: existing.id,
          loginInfo: optionalStringOf(row, 'loginInfo') ?? existing.loginInfo,
        );
        await _sources.writeLoginHeader(
          id: existing.id,
          loginHeader:
              optionalStringOf(row, 'loginHeader') ?? existing.loginHeader,
        );
        await _sources.setEnabled(
          id: existing.id,
          isEnabled: optionalBoolOf(
            row,
            'isEnabled',
            fallback: existing.isEnabled,
          ),
        );
        await _sources.setExploreEnabled(
          id: existing.id,
          isExploreEnabled: optionalBoolOf(
            row,
            'isExploreEnabled',
            fallback: existing.isExploreEnabled,
          ),
        );
        counter.updated += 1;
      } on BadBackupRow {
        counter.skipped += 1;
      }
    }

    return counter.outcome;
  }

  /// The id a restored book's group name points at, or `null` when neither side knows the name.
  ///
  /// A name only in the backup was created by [_restoreGroups] earlier in the same transaction, so a
  /// lookup here answers it; a name that exists nowhere falls back to 「未分组」 instead of inventing
  /// a group the backup did not carry.
  Future<int?> _groupIdOf(String? name, Map<String, int> cache) async {
    if (name == null) {
      return null;
    }
    final int? cached = cache[name];
    if (cached != null) {
      return cached;
    }
    final BookGroupRow? group = await _groups.findByName(name);
    if (group == null) {
      return null;
    }
    cache[name] = group.id;

    return group.id;
  }

  /// The rule payload of one row, decoded from the text the export wrote.
  Map<String, Object?> _payloadOf(Map<String, Object?> row) {
    final Object? decoded = jsonDecode(stringOf(row, 'payload'));
    if (decoded is! Map) {
      throw const BadBackupRow('payload');
    }

    return <String, Object?>{
      for (final MapEntry<Object?, Object?> entry in decoded.entries)
        if (entry.key case final String key) key: entry.value,
    };
  }

  List<Map<String, Object?>> _rowsOf(
    BackupContents contents,
    BackupTable table,
  ) => contents.tables[table] ?? const <Map<String, Object?>>[];
}

/// Mutable per-table counters, converted into the immutable report at the end.
final class _Counter {
  int inserted = 0;
  int updated = 0;
  int skipped = 0;

  BackupTableOutcome get outcome => BackupTableOutcome(
    inserted: inserted,
    updated: updated,
    skipped: skipped,
  );
}
