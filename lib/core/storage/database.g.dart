// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $CacheEntriesTable extends CacheEntries
    with TableInfo<$CacheEntriesTable, CacheEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CacheEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cacheKeyMeta = const VerificationMeta(
    'cacheKey',
  );
  @override
  late final GeneratedColumn<String> cacheKey = GeneratedColumn<String>(
    'cache_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [cacheKey, payload, expiresAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cache_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<CacheEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('cache_key')) {
      context.handle(
        _cacheKeyMeta,
        cacheKey.isAcceptableOrUnknown(data['cache_key']!, _cacheKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_cacheKeyMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cacheKey};
  @override
  CacheEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CacheEntry(
      cacheKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cache_key'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      )!,
    );
  }

  @override
  $CacheEntriesTable createAlias(String alias) {
    return $CacheEntriesTable(attachedDatabase, alias);
  }
}

class CacheEntry extends DataClass implements Insertable<CacheEntry> {
  /// Stable digest of「书源 ID + 规则字段 + URL + 页码」.
  final String cacheKey;

  /// The cached payload, for example a decoded page body.
  final String payload;

  /// Instant after which the entry must be ignored and purged.
  final DateTime expiresAt;
  const CacheEntry({
    required this.cacheKey,
    required this.payload,
    required this.expiresAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['cache_key'] = Variable<String>(cacheKey);
    map['payload'] = Variable<String>(payload);
    map['expires_at'] = Variable<DateTime>(expiresAt);
    return map;
  }

  CacheEntriesCompanion toCompanion(bool nullToAbsent) {
    return CacheEntriesCompanion(
      cacheKey: Value(cacheKey),
      payload: Value(payload),
      expiresAt: Value(expiresAt),
    );
  }

  factory CacheEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CacheEntry(
      cacheKey: serializer.fromJson<String>(json['cacheKey']),
      payload: serializer.fromJson<String>(json['payload']),
      expiresAt: serializer.fromJson<DateTime>(json['expiresAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cacheKey': serializer.toJson<String>(cacheKey),
      'payload': serializer.toJson<String>(payload),
      'expiresAt': serializer.toJson<DateTime>(expiresAt),
    };
  }

  CacheEntry copyWith({
    String? cacheKey,
    String? payload,
    DateTime? expiresAt,
  }) => CacheEntry(
    cacheKey: cacheKey ?? this.cacheKey,
    payload: payload ?? this.payload,
    expiresAt: expiresAt ?? this.expiresAt,
  );
  CacheEntry copyWithCompanion(CacheEntriesCompanion data) {
    return CacheEntry(
      cacheKey: data.cacheKey.present ? data.cacheKey.value : this.cacheKey,
      payload: data.payload.present ? data.payload.value : this.payload,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CacheEntry(')
          ..write('cacheKey: $cacheKey, ')
          ..write('payload: $payload, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(cacheKey, payload, expiresAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CacheEntry &&
          other.cacheKey == this.cacheKey &&
          other.payload == this.payload &&
          other.expiresAt == this.expiresAt);
}

class CacheEntriesCompanion extends UpdateCompanion<CacheEntry> {
  final Value<String> cacheKey;
  final Value<String> payload;
  final Value<DateTime> expiresAt;
  final Value<int> rowid;
  const CacheEntriesCompanion({
    this.cacheKey = const Value.absent(),
    this.payload = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CacheEntriesCompanion.insert({
    required String cacheKey,
    required String payload,
    required DateTime expiresAt,
    this.rowid = const Value.absent(),
  }) : cacheKey = Value(cacheKey),
       payload = Value(payload),
       expiresAt = Value(expiresAt);
  static Insertable<CacheEntry> custom({
    Expression<String>? cacheKey,
    Expression<String>? payload,
    Expression<DateTime>? expiresAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cacheKey != null) 'cache_key': cacheKey,
      if (payload != null) 'payload': payload,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CacheEntriesCompanion copyWith({
    Value<String>? cacheKey,
    Value<String>? payload,
    Value<DateTime>? expiresAt,
    Value<int>? rowid,
  }) {
    return CacheEntriesCompanion(
      cacheKey: cacheKey ?? this.cacheKey,
      payload: payload ?? this.payload,
      expiresAt: expiresAt ?? this.expiresAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cacheKey.present) {
      map['cache_key'] = Variable<String>(cacheKey.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CacheEntriesCompanion(')
          ..write('cacheKey: $cacheKey, ')
          ..write('payload: $payload, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BookSourcesTable extends BookSources
    with TableInfo<$BookSourcesTable, BookSourceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookSourcesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fingerprintMeta = const VerificationMeta(
    'fingerprint',
  );
  @override
  late final GeneratedColumn<String> fingerprint = GeneratedColumn<String>(
    'fingerprint',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupNameMeta = const VerificationMeta(
    'groupName',
  );
  @override
  late final GeneratedColumn<String> groupName = GeneratedColumn<String>(
    'group_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _commentMeta = const VerificationMeta(
    'comment',
  );
  @override
  late final GeneratedColumn<String> comment = GeneratedColumn<String>(
    'comment',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceTypeMeta = const VerificationMeta(
    'sourceType',
  );
  @override
  late final GeneratedColumn<int> sourceType = GeneratedColumn<int>(
    'source_type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isEnabledMeta = const VerificationMeta(
    'isEnabled',
  );
  @override
  late final GeneratedColumn<bool> isEnabled = GeneratedColumn<bool>(
    'is_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _customOrderMeta = const VerificationMeta(
    'customOrder',
  );
  @override
  late final GeneratedColumn<int> customOrder = GeneratedColumn<int>(
    'custom_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _weightMeta = const VerificationMeta('weight');
  @override
  late final GeneratedColumn<int> weight = GeneratedColumn<int>(
    'weight',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastUpdateTimeMeta = const VerificationMeta(
    'lastUpdateTime',
  );
  @override
  late final GeneratedColumn<int> lastUpdateTime = GeneratedColumn<int>(
    'last_update_time',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _respondTimeMeta = const VerificationMeta(
    'respondTime',
  );
  @override
  late final GeneratedColumn<int> respondTime = GeneratedColumn<int>(
    'respond_time',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _importedAtMeta = const VerificationMeta(
    'importedAt',
  );
  @override
  late final GeneratedColumn<DateTime> importedAt = GeneratedColumn<DateTime>(
    'imported_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    url,
    fingerprint,
    payload,
    name,
    groupName,
    comment,
    sourceType,
    isEnabled,
    customOrder,
    weight,
    lastUpdateTime,
    respondTime,
    importedAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'book_sources';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookSourceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('url')) {
      context.handle(
        _urlMeta,
        url.isAcceptableOrUnknown(data['url']!, _urlMeta),
      );
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('fingerprint')) {
      context.handle(
        _fingerprintMeta,
        fingerprint.isAcceptableOrUnknown(
          data['fingerprint']!,
          _fingerprintMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fingerprintMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('group_name')) {
      context.handle(
        _groupNameMeta,
        groupName.isAcceptableOrUnknown(data['group_name']!, _groupNameMeta),
      );
    }
    if (data.containsKey('comment')) {
      context.handle(
        _commentMeta,
        comment.isAcceptableOrUnknown(data['comment']!, _commentMeta),
      );
    }
    if (data.containsKey('source_type')) {
      context.handle(
        _sourceTypeMeta,
        sourceType.isAcceptableOrUnknown(data['source_type']!, _sourceTypeMeta),
      );
    }
    if (data.containsKey('is_enabled')) {
      context.handle(
        _isEnabledMeta,
        isEnabled.isAcceptableOrUnknown(data['is_enabled']!, _isEnabledMeta),
      );
    }
    if (data.containsKey('custom_order')) {
      context.handle(
        _customOrderMeta,
        customOrder.isAcceptableOrUnknown(
          data['custom_order']!,
          _customOrderMeta,
        ),
      );
    }
    if (data.containsKey('weight')) {
      context.handle(
        _weightMeta,
        weight.isAcceptableOrUnknown(data['weight']!, _weightMeta),
      );
    }
    if (data.containsKey('last_update_time')) {
      context.handle(
        _lastUpdateTimeMeta,
        lastUpdateTime.isAcceptableOrUnknown(
          data['last_update_time']!,
          _lastUpdateTimeMeta,
        ),
      );
    }
    if (data.containsKey('respond_time')) {
      context.handle(
        _respondTimeMeta,
        respondTime.isAcceptableOrUnknown(
          data['respond_time']!,
          _respondTimeMeta,
        ),
      );
    }
    if (data.containsKey('imported_at')) {
      context.handle(
        _importedAtMeta,
        importedAt.isAcceptableOrUnknown(data['imported_at']!, _importedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_importedAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {url, fingerprint},
  ];
  @override
  BookSourceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookSourceRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      url: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}url'],
      )!,
      fingerprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fingerprint'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      groupName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_name'],
      ),
      comment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}comment'],
      ),
      sourceType: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_type'],
      )!,
      isEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_enabled'],
      )!,
      customOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}custom_order'],
      )!,
      weight: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}weight'],
      )!,
      lastUpdateTime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_update_time'],
      ),
      respondTime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}respond_time'],
      ),
      importedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}imported_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $BookSourcesTable createAlias(String alias) {
    return $BookSourcesTable(attachedDatabase, alias);
  }
}

class BookSourceRow extends DataClass implements Insertable<BookSourceRow> {
  /// Synthetic primary key; never the URL, so a row keeps its identity across re-imports.
  ///
  /// `AUTOINCREMENT` is deliberate rather than a plain `INTEGER PRIMARY KEY`: without it SQLite
  /// may hand a deleted row's id out again, and a stale "current source" reference would then
  /// silently point at **another** source (ADR-0040 §决策 1). Monotonic ids make reuse
  /// impossible, and with a few thousand rows the extra bookkeeping costs nothing.
  final int id;

  /// `bookSourceUrl` — upstream's natural identifier (`book-source.md` §2).
  final String url;

  /// sha256 of the behaviour fields' canonical JSON (`bookSourceFingerprint`).
  final String fingerprint;

  /// The entry exactly as imported, re-encoded from the raw JSON map (ADR-0040 §决策 4).
  ///
  /// It is the export source of `docs/dev/roadmap.md` 5.8 and the only place unknown keys survive
  /// byte-for-byte; the projection columns below exist for listing and sorting only.
  final String payload;

  /// `bookSourceName`, projected for the list.
  final String name;

  /// `bookSourceGroup`, projected for the list.
  final String? groupName;

  /// `bookSourceComment`, the note the batch check writes back (`docs/dev/roadmap.md` §5.10).
  ///
  /// It is a **projection column like [groupName]**, not part of [payload]: the check rewrites it on
  /// every run (the previous `// Error: ` block is cleared first), and ADR-0040 §决策 4 keeps
  /// [payload] byte-for-byte so `docs/dev/roadmap.md` 5.8 can export what was imported (ADR-0043 §决策 1).
  final String? comment;

  /// `bookSourceType`, projected for the list.
  final int sourceType;

  /// User state: whether the source takes part in search / explore (`docs/dev/roadmap.md` 5.1).
  ///
  /// Import initialises it for a new row and **never** touches it afterwards
  /// (ADR-0040 §决策 3).
  final bool isEnabled;

  /// User state: the manual sort order (`docs/dev/roadmap.md` 5.5); import never touches it either.
  final int customOrder;

  /// `weight`, projected for sorting in `docs/dev/roadmap.md` 5.5.
  final int weight;

  /// `lastUpdateTime`, projected for display in `docs/dev/roadmap.md` 5.5.
  final int? lastUpdateTime;

  /// `respondTime`, projected for display in `docs/dev/roadmap.md` 5.5.
  final int? respondTime;

  /// When the row was created.
  final DateTime importedAt;

  /// When the stored payload was last refreshed.
  final DateTime updatedAt;
  const BookSourceRow({
    required this.id,
    required this.url,
    required this.fingerprint,
    required this.payload,
    required this.name,
    this.groupName,
    this.comment,
    required this.sourceType,
    required this.isEnabled,
    required this.customOrder,
    required this.weight,
    this.lastUpdateTime,
    this.respondTime,
    required this.importedAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['url'] = Variable<String>(url);
    map['fingerprint'] = Variable<String>(fingerprint);
    map['payload'] = Variable<String>(payload);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || groupName != null) {
      map['group_name'] = Variable<String>(groupName);
    }
    if (!nullToAbsent || comment != null) {
      map['comment'] = Variable<String>(comment);
    }
    map['source_type'] = Variable<int>(sourceType);
    map['is_enabled'] = Variable<bool>(isEnabled);
    map['custom_order'] = Variable<int>(customOrder);
    map['weight'] = Variable<int>(weight);
    if (!nullToAbsent || lastUpdateTime != null) {
      map['last_update_time'] = Variable<int>(lastUpdateTime);
    }
    if (!nullToAbsent || respondTime != null) {
      map['respond_time'] = Variable<int>(respondTime);
    }
    map['imported_at'] = Variable<DateTime>(importedAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  BookSourcesCompanion toCompanion(bool nullToAbsent) {
    return BookSourcesCompanion(
      id: Value(id),
      url: Value(url),
      fingerprint: Value(fingerprint),
      payload: Value(payload),
      name: Value(name),
      groupName: groupName == null && nullToAbsent
          ? const Value.absent()
          : Value(groupName),
      comment: comment == null && nullToAbsent
          ? const Value.absent()
          : Value(comment),
      sourceType: Value(sourceType),
      isEnabled: Value(isEnabled),
      customOrder: Value(customOrder),
      weight: Value(weight),
      lastUpdateTime: lastUpdateTime == null && nullToAbsent
          ? const Value.absent()
          : Value(lastUpdateTime),
      respondTime: respondTime == null && nullToAbsent
          ? const Value.absent()
          : Value(respondTime),
      importedAt: Value(importedAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory BookSourceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookSourceRow(
      id: serializer.fromJson<int>(json['id']),
      url: serializer.fromJson<String>(json['url']),
      fingerprint: serializer.fromJson<String>(json['fingerprint']),
      payload: serializer.fromJson<String>(json['payload']),
      name: serializer.fromJson<String>(json['name']),
      groupName: serializer.fromJson<String?>(json['groupName']),
      comment: serializer.fromJson<String?>(json['comment']),
      sourceType: serializer.fromJson<int>(json['sourceType']),
      isEnabled: serializer.fromJson<bool>(json['isEnabled']),
      customOrder: serializer.fromJson<int>(json['customOrder']),
      weight: serializer.fromJson<int>(json['weight']),
      lastUpdateTime: serializer.fromJson<int?>(json['lastUpdateTime']),
      respondTime: serializer.fromJson<int?>(json['respondTime']),
      importedAt: serializer.fromJson<DateTime>(json['importedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'url': serializer.toJson<String>(url),
      'fingerprint': serializer.toJson<String>(fingerprint),
      'payload': serializer.toJson<String>(payload),
      'name': serializer.toJson<String>(name),
      'groupName': serializer.toJson<String?>(groupName),
      'comment': serializer.toJson<String?>(comment),
      'sourceType': serializer.toJson<int>(sourceType),
      'isEnabled': serializer.toJson<bool>(isEnabled),
      'customOrder': serializer.toJson<int>(customOrder),
      'weight': serializer.toJson<int>(weight),
      'lastUpdateTime': serializer.toJson<int?>(lastUpdateTime),
      'respondTime': serializer.toJson<int?>(respondTime),
      'importedAt': serializer.toJson<DateTime>(importedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  BookSourceRow copyWith({
    int? id,
    String? url,
    String? fingerprint,
    String? payload,
    String? name,
    Value<String?> groupName = const Value.absent(),
    Value<String?> comment = const Value.absent(),
    int? sourceType,
    bool? isEnabled,
    int? customOrder,
    int? weight,
    Value<int?> lastUpdateTime = const Value.absent(),
    Value<int?> respondTime = const Value.absent(),
    DateTime? importedAt,
    DateTime? updatedAt,
  }) => BookSourceRow(
    id: id ?? this.id,
    url: url ?? this.url,
    fingerprint: fingerprint ?? this.fingerprint,
    payload: payload ?? this.payload,
    name: name ?? this.name,
    groupName: groupName.present ? groupName.value : this.groupName,
    comment: comment.present ? comment.value : this.comment,
    sourceType: sourceType ?? this.sourceType,
    isEnabled: isEnabled ?? this.isEnabled,
    customOrder: customOrder ?? this.customOrder,
    weight: weight ?? this.weight,
    lastUpdateTime: lastUpdateTime.present
        ? lastUpdateTime.value
        : this.lastUpdateTime,
    respondTime: respondTime.present ? respondTime.value : this.respondTime,
    importedAt: importedAt ?? this.importedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  BookSourceRow copyWithCompanion(BookSourcesCompanion data) {
    return BookSourceRow(
      id: data.id.present ? data.id.value : this.id,
      url: data.url.present ? data.url.value : this.url,
      fingerprint: data.fingerprint.present
          ? data.fingerprint.value
          : this.fingerprint,
      payload: data.payload.present ? data.payload.value : this.payload,
      name: data.name.present ? data.name.value : this.name,
      groupName: data.groupName.present ? data.groupName.value : this.groupName,
      comment: data.comment.present ? data.comment.value : this.comment,
      sourceType: data.sourceType.present
          ? data.sourceType.value
          : this.sourceType,
      isEnabled: data.isEnabled.present ? data.isEnabled.value : this.isEnabled,
      customOrder: data.customOrder.present
          ? data.customOrder.value
          : this.customOrder,
      weight: data.weight.present ? data.weight.value : this.weight,
      lastUpdateTime: data.lastUpdateTime.present
          ? data.lastUpdateTime.value
          : this.lastUpdateTime,
      respondTime: data.respondTime.present
          ? data.respondTime.value
          : this.respondTime,
      importedAt: data.importedAt.present
          ? data.importedAt.value
          : this.importedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookSourceRow(')
          ..write('id: $id, ')
          ..write('url: $url, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('payload: $payload, ')
          ..write('name: $name, ')
          ..write('groupName: $groupName, ')
          ..write('comment: $comment, ')
          ..write('sourceType: $sourceType, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('customOrder: $customOrder, ')
          ..write('weight: $weight, ')
          ..write('lastUpdateTime: $lastUpdateTime, ')
          ..write('respondTime: $respondTime, ')
          ..write('importedAt: $importedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    url,
    fingerprint,
    payload,
    name,
    groupName,
    comment,
    sourceType,
    isEnabled,
    customOrder,
    weight,
    lastUpdateTime,
    respondTime,
    importedAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookSourceRow &&
          other.id == this.id &&
          other.url == this.url &&
          other.fingerprint == this.fingerprint &&
          other.payload == this.payload &&
          other.name == this.name &&
          other.groupName == this.groupName &&
          other.comment == this.comment &&
          other.sourceType == this.sourceType &&
          other.isEnabled == this.isEnabled &&
          other.customOrder == this.customOrder &&
          other.weight == this.weight &&
          other.lastUpdateTime == this.lastUpdateTime &&
          other.respondTime == this.respondTime &&
          other.importedAt == this.importedAt &&
          other.updatedAt == this.updatedAt);
}

class BookSourcesCompanion extends UpdateCompanion<BookSourceRow> {
  final Value<int> id;
  final Value<String> url;
  final Value<String> fingerprint;
  final Value<String> payload;
  final Value<String> name;
  final Value<String?> groupName;
  final Value<String?> comment;
  final Value<int> sourceType;
  final Value<bool> isEnabled;
  final Value<int> customOrder;
  final Value<int> weight;
  final Value<int?> lastUpdateTime;
  final Value<int?> respondTime;
  final Value<DateTime> importedAt;
  final Value<DateTime> updatedAt;
  const BookSourcesCompanion({
    this.id = const Value.absent(),
    this.url = const Value.absent(),
    this.fingerprint = const Value.absent(),
    this.payload = const Value.absent(),
    this.name = const Value.absent(),
    this.groupName = const Value.absent(),
    this.comment = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.customOrder = const Value.absent(),
    this.weight = const Value.absent(),
    this.lastUpdateTime = const Value.absent(),
    this.respondTime = const Value.absent(),
    this.importedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  BookSourcesCompanion.insert({
    this.id = const Value.absent(),
    required String url,
    required String fingerprint,
    required String payload,
    required String name,
    this.groupName = const Value.absent(),
    this.comment = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.customOrder = const Value.absent(),
    this.weight = const Value.absent(),
    this.lastUpdateTime = const Value.absent(),
    this.respondTime = const Value.absent(),
    required DateTime importedAt,
    required DateTime updatedAt,
  }) : url = Value(url),
       fingerprint = Value(fingerprint),
       payload = Value(payload),
       name = Value(name),
       importedAt = Value(importedAt),
       updatedAt = Value(updatedAt);
  static Insertable<BookSourceRow> custom({
    Expression<int>? id,
    Expression<String>? url,
    Expression<String>? fingerprint,
    Expression<String>? payload,
    Expression<String>? name,
    Expression<String>? groupName,
    Expression<String>? comment,
    Expression<int>? sourceType,
    Expression<bool>? isEnabled,
    Expression<int>? customOrder,
    Expression<int>? weight,
    Expression<int>? lastUpdateTime,
    Expression<int>? respondTime,
    Expression<DateTime>? importedAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (url != null) 'url': url,
      if (fingerprint != null) 'fingerprint': fingerprint,
      if (payload != null) 'payload': payload,
      if (name != null) 'name': name,
      if (groupName != null) 'group_name': groupName,
      if (comment != null) 'comment': comment,
      if (sourceType != null) 'source_type': sourceType,
      if (isEnabled != null) 'is_enabled': isEnabled,
      if (customOrder != null) 'custom_order': customOrder,
      if (weight != null) 'weight': weight,
      if (lastUpdateTime != null) 'last_update_time': lastUpdateTime,
      if (respondTime != null) 'respond_time': respondTime,
      if (importedAt != null) 'imported_at': importedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  BookSourcesCompanion copyWith({
    Value<int>? id,
    Value<String>? url,
    Value<String>? fingerprint,
    Value<String>? payload,
    Value<String>? name,
    Value<String?>? groupName,
    Value<String?>? comment,
    Value<int>? sourceType,
    Value<bool>? isEnabled,
    Value<int>? customOrder,
    Value<int>? weight,
    Value<int?>? lastUpdateTime,
    Value<int?>? respondTime,
    Value<DateTime>? importedAt,
    Value<DateTime>? updatedAt,
  }) {
    return BookSourcesCompanion(
      id: id ?? this.id,
      url: url ?? this.url,
      fingerprint: fingerprint ?? this.fingerprint,
      payload: payload ?? this.payload,
      name: name ?? this.name,
      groupName: groupName ?? this.groupName,
      comment: comment ?? this.comment,
      sourceType: sourceType ?? this.sourceType,
      isEnabled: isEnabled ?? this.isEnabled,
      customOrder: customOrder ?? this.customOrder,
      weight: weight ?? this.weight,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
      respondTime: respondTime ?? this.respondTime,
      importedAt: importedAt ?? this.importedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (fingerprint.present) {
      map['fingerprint'] = Variable<String>(fingerprint.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (groupName.present) {
      map['group_name'] = Variable<String>(groupName.value);
    }
    if (comment.present) {
      map['comment'] = Variable<String>(comment.value);
    }
    if (sourceType.present) {
      map['source_type'] = Variable<int>(sourceType.value);
    }
    if (isEnabled.present) {
      map['is_enabled'] = Variable<bool>(isEnabled.value);
    }
    if (customOrder.present) {
      map['custom_order'] = Variable<int>(customOrder.value);
    }
    if (weight.present) {
      map['weight'] = Variable<int>(weight.value);
    }
    if (lastUpdateTime.present) {
      map['last_update_time'] = Variable<int>(lastUpdateTime.value);
    }
    if (respondTime.present) {
      map['respond_time'] = Variable<int>(respondTime.value);
    }
    if (importedAt.present) {
      map['imported_at'] = Variable<DateTime>(importedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookSourcesCompanion(')
          ..write('id: $id, ')
          ..write('url: $url, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('payload: $payload, ')
          ..write('name: $name, ')
          ..write('groupName: $groupName, ')
          ..write('comment: $comment, ')
          ..write('sourceType: $sourceType, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('customOrder: $customOrder, ')
          ..write('weight: $weight, ')
          ..write('lastUpdateTime: $lastUpdateTime, ')
          ..write('respondTime: $respondTime, ')
          ..write('importedAt: $importedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $BooksTable extends Books with TableInfo<$BooksTable, BookRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BooksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sourceUrlMeta = const VerificationMeta(
    'sourceUrl',
  );
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
    'source_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookUrlMeta = const VerificationMeta(
    'bookUrl',
  );
  @override
  late final GeneratedColumn<String> bookUrl = GeneratedColumn<String>(
    'book_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tocUrlMeta = const VerificationMeta('tocUrl');
  @override
  late final GeneratedColumn<String> tocUrl = GeneratedColumn<String>(
    'toc_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverUrlMeta = const VerificationMeta(
    'coverUrl',
  );
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
    'cover_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _introMeta = const VerificationMeta('intro');
  @override
  late final GeneratedColumn<String> intro = GeneratedColumn<String>(
    'intro',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastChapterMeta = const VerificationMeta(
    'lastChapter',
  );
  @override
  late final GeneratedColumn<String> lastChapter = GeneratedColumn<String>(
    'last_chapter',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isPinnedMeta = const VerificationMeta(
    'isPinned',
  );
  @override
  late final GeneratedColumn<bool> isPinned = GeneratedColumn<bool>(
    'is_pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourceUrl,
    bookUrl,
    tocUrl,
    name,
    author,
    kind,
    coverUrl,
    intro,
    lastChapter,
    status,
    isPinned,
    addedAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'books';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('source_url')) {
      context.handle(
        _sourceUrlMeta,
        sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceUrlMeta);
    }
    if (data.containsKey('book_url')) {
      context.handle(
        _bookUrlMeta,
        bookUrl.isAcceptableOrUnknown(data['book_url']!, _bookUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_bookUrlMeta);
    }
    if (data.containsKey('toc_url')) {
      context.handle(
        _tocUrlMeta,
        tocUrl.isAcceptableOrUnknown(data['toc_url']!, _tocUrlMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('cover_url')) {
      context.handle(
        _coverUrlMeta,
        coverUrl.isAcceptableOrUnknown(data['cover_url']!, _coverUrlMeta),
      );
    }
    if (data.containsKey('intro')) {
      context.handle(
        _introMeta,
        intro.isAcceptableOrUnknown(data['intro']!, _introMeta),
      );
    }
    if (data.containsKey('last_chapter')) {
      context.handle(
        _lastChapterMeta,
        lastChapter.isAcceptableOrUnknown(
          data['last_chapter']!,
          _lastChapterMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('is_pinned')) {
      context.handle(
        _isPinnedMeta,
        isPinned.isAcceptableOrUnknown(data['is_pinned']!, _isPinnedMeta),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {sourceUrl, bookUrl},
  ];
  @override
  BookRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_url'],
      )!,
      bookUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_url'],
      )!,
      tocUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}toc_url'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      ),
      coverUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_url'],
      ),
      intro: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}intro'],
      ),
      lastChapter: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_chapter'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status'],
      )!,
      isPinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_pinned'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $BooksTable createAlias(String alias) {
    return $BooksTable(attachedDatabase, alias);
  }
}

class BookRow extends DataClass implements Insertable<BookRow> {
  /// Synthetic primary key.
  final int id;

  /// `bookSourceUrl` of the source this entry came from.
  final String sourceUrl;

  /// The detail page URL — the book's identity inside one source.
  final String bookUrl;

  /// The table-of-contents URL the detail page resolved (`ruleBookInfo.tocUrl`, 5.3).
  ///
  /// It is a **nullable** column rather than something the reader can derive: a source may keep its
  /// chapters on a page of their own, and the book page is then the wrong address. Opening the
  /// reader from the shelf falls back to [bookUrl] when the row predates this column (ADR-0044 §决策 3).
  final String? tocUrl;

  /// The title shown on the shelf.
  final String name;

  /// The author as the search hit spelled it, when the rule matched.
  final String? author;

  /// The category as the source spelled it, when the rule matched.
  final String? kind;

  /// The cover URL, when the source declared one.
  final String? coverUrl;

  /// The introduction, when the source declared one.
  final String? intro;

  /// The latest chapter as shown at the time the book was added.
  final String? lastChapter;

  /// User state: 0 = tracking, 1 = finished (`ShelfStatus`); the UI owns it.
  final int status;

  /// User state: whether the entry is pinned to the top of the shelf.
  final bool isPinned;

  /// When the book was put on the shelf.
  final DateTime addedAt;

  /// When this row was last written; the shelf's fallback order uses it.
  final DateTime updatedAt;
  const BookRow({
    required this.id,
    required this.sourceUrl,
    required this.bookUrl,
    this.tocUrl,
    required this.name,
    this.author,
    this.kind,
    this.coverUrl,
    this.intro,
    this.lastChapter,
    required this.status,
    required this.isPinned,
    required this.addedAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['source_url'] = Variable<String>(sourceUrl);
    map['book_url'] = Variable<String>(bookUrl);
    if (!nullToAbsent || tocUrl != null) {
      map['toc_url'] = Variable<String>(tocUrl);
    }
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || author != null) {
      map['author'] = Variable<String>(author);
    }
    if (!nullToAbsent || kind != null) {
      map['kind'] = Variable<String>(kind);
    }
    if (!nullToAbsent || coverUrl != null) {
      map['cover_url'] = Variable<String>(coverUrl);
    }
    if (!nullToAbsent || intro != null) {
      map['intro'] = Variable<String>(intro);
    }
    if (!nullToAbsent || lastChapter != null) {
      map['last_chapter'] = Variable<String>(lastChapter);
    }
    map['status'] = Variable<int>(status);
    map['is_pinned'] = Variable<bool>(isPinned);
    map['added_at'] = Variable<DateTime>(addedAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  BooksCompanion toCompanion(bool nullToAbsent) {
    return BooksCompanion(
      id: Value(id),
      sourceUrl: Value(sourceUrl),
      bookUrl: Value(bookUrl),
      tocUrl: tocUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(tocUrl),
      name: Value(name),
      author: author == null && nullToAbsent
          ? const Value.absent()
          : Value(author),
      kind: kind == null && nullToAbsent ? const Value.absent() : Value(kind),
      coverUrl: coverUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(coverUrl),
      intro: intro == null && nullToAbsent
          ? const Value.absent()
          : Value(intro),
      lastChapter: lastChapter == null && nullToAbsent
          ? const Value.absent()
          : Value(lastChapter),
      status: Value(status),
      isPinned: Value(isPinned),
      addedAt: Value(addedAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory BookRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookRow(
      id: serializer.fromJson<int>(json['id']),
      sourceUrl: serializer.fromJson<String>(json['sourceUrl']),
      bookUrl: serializer.fromJson<String>(json['bookUrl']),
      tocUrl: serializer.fromJson<String?>(json['tocUrl']),
      name: serializer.fromJson<String>(json['name']),
      author: serializer.fromJson<String?>(json['author']),
      kind: serializer.fromJson<String?>(json['kind']),
      coverUrl: serializer.fromJson<String?>(json['coverUrl']),
      intro: serializer.fromJson<String?>(json['intro']),
      lastChapter: serializer.fromJson<String?>(json['lastChapter']),
      status: serializer.fromJson<int>(json['status']),
      isPinned: serializer.fromJson<bool>(json['isPinned']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sourceUrl': serializer.toJson<String>(sourceUrl),
      'bookUrl': serializer.toJson<String>(bookUrl),
      'tocUrl': serializer.toJson<String?>(tocUrl),
      'name': serializer.toJson<String>(name),
      'author': serializer.toJson<String?>(author),
      'kind': serializer.toJson<String?>(kind),
      'coverUrl': serializer.toJson<String?>(coverUrl),
      'intro': serializer.toJson<String?>(intro),
      'lastChapter': serializer.toJson<String?>(lastChapter),
      'status': serializer.toJson<int>(status),
      'isPinned': serializer.toJson<bool>(isPinned),
      'addedAt': serializer.toJson<DateTime>(addedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  BookRow copyWith({
    int? id,
    String? sourceUrl,
    String? bookUrl,
    Value<String?> tocUrl = const Value.absent(),
    String? name,
    Value<String?> author = const Value.absent(),
    Value<String?> kind = const Value.absent(),
    Value<String?> coverUrl = const Value.absent(),
    Value<String?> intro = const Value.absent(),
    Value<String?> lastChapter = const Value.absent(),
    int? status,
    bool? isPinned,
    DateTime? addedAt,
    DateTime? updatedAt,
  }) => BookRow(
    id: id ?? this.id,
    sourceUrl: sourceUrl ?? this.sourceUrl,
    bookUrl: bookUrl ?? this.bookUrl,
    tocUrl: tocUrl.present ? tocUrl.value : this.tocUrl,
    name: name ?? this.name,
    author: author.present ? author.value : this.author,
    kind: kind.present ? kind.value : this.kind,
    coverUrl: coverUrl.present ? coverUrl.value : this.coverUrl,
    intro: intro.present ? intro.value : this.intro,
    lastChapter: lastChapter.present ? lastChapter.value : this.lastChapter,
    status: status ?? this.status,
    isPinned: isPinned ?? this.isPinned,
    addedAt: addedAt ?? this.addedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  BookRow copyWithCompanion(BooksCompanion data) {
    return BookRow(
      id: data.id.present ? data.id.value : this.id,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      bookUrl: data.bookUrl.present ? data.bookUrl.value : this.bookUrl,
      tocUrl: data.tocUrl.present ? data.tocUrl.value : this.tocUrl,
      name: data.name.present ? data.name.value : this.name,
      author: data.author.present ? data.author.value : this.author,
      kind: data.kind.present ? data.kind.value : this.kind,
      coverUrl: data.coverUrl.present ? data.coverUrl.value : this.coverUrl,
      intro: data.intro.present ? data.intro.value : this.intro,
      lastChapter: data.lastChapter.present
          ? data.lastChapter.value
          : this.lastChapter,
      status: data.status.present ? data.status.value : this.status,
      isPinned: data.isPinned.present ? data.isPinned.value : this.isPinned,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookRow(')
          ..write('id: $id, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('bookUrl: $bookUrl, ')
          ..write('tocUrl: $tocUrl, ')
          ..write('name: $name, ')
          ..write('author: $author, ')
          ..write('kind: $kind, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('intro: $intro, ')
          ..write('lastChapter: $lastChapter, ')
          ..write('status: $status, ')
          ..write('isPinned: $isPinned, ')
          ..write('addedAt: $addedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sourceUrl,
    bookUrl,
    tocUrl,
    name,
    author,
    kind,
    coverUrl,
    intro,
    lastChapter,
    status,
    isPinned,
    addedAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookRow &&
          other.id == this.id &&
          other.sourceUrl == this.sourceUrl &&
          other.bookUrl == this.bookUrl &&
          other.tocUrl == this.tocUrl &&
          other.name == this.name &&
          other.author == this.author &&
          other.kind == this.kind &&
          other.coverUrl == this.coverUrl &&
          other.intro == this.intro &&
          other.lastChapter == this.lastChapter &&
          other.status == this.status &&
          other.isPinned == this.isPinned &&
          other.addedAt == this.addedAt &&
          other.updatedAt == this.updatedAt);
}

class BooksCompanion extends UpdateCompanion<BookRow> {
  final Value<int> id;
  final Value<String> sourceUrl;
  final Value<String> bookUrl;
  final Value<String?> tocUrl;
  final Value<String> name;
  final Value<String?> author;
  final Value<String?> kind;
  final Value<String?> coverUrl;
  final Value<String?> intro;
  final Value<String?> lastChapter;
  final Value<int> status;
  final Value<bool> isPinned;
  final Value<DateTime> addedAt;
  final Value<DateTime> updatedAt;
  const BooksCompanion({
    this.id = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.bookUrl = const Value.absent(),
    this.tocUrl = const Value.absent(),
    this.name = const Value.absent(),
    this.author = const Value.absent(),
    this.kind = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.intro = const Value.absent(),
    this.lastChapter = const Value.absent(),
    this.status = const Value.absent(),
    this.isPinned = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  BooksCompanion.insert({
    this.id = const Value.absent(),
    required String sourceUrl,
    required String bookUrl,
    this.tocUrl = const Value.absent(),
    required String name,
    this.author = const Value.absent(),
    this.kind = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.intro = const Value.absent(),
    this.lastChapter = const Value.absent(),
    this.status = const Value.absent(),
    this.isPinned = const Value.absent(),
    required DateTime addedAt,
    required DateTime updatedAt,
  }) : sourceUrl = Value(sourceUrl),
       bookUrl = Value(bookUrl),
       name = Value(name),
       addedAt = Value(addedAt),
       updatedAt = Value(updatedAt);
  static Insertable<BookRow> custom({
    Expression<int>? id,
    Expression<String>? sourceUrl,
    Expression<String>? bookUrl,
    Expression<String>? tocUrl,
    Expression<String>? name,
    Expression<String>? author,
    Expression<String>? kind,
    Expression<String>? coverUrl,
    Expression<String>? intro,
    Expression<String>? lastChapter,
    Expression<int>? status,
    Expression<bool>? isPinned,
    Expression<DateTime>? addedAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (bookUrl != null) 'book_url': bookUrl,
      if (tocUrl != null) 'toc_url': tocUrl,
      if (name != null) 'name': name,
      if (author != null) 'author': author,
      if (kind != null) 'kind': kind,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (intro != null) 'intro': intro,
      if (lastChapter != null) 'last_chapter': lastChapter,
      if (status != null) 'status': status,
      if (isPinned != null) 'is_pinned': isPinned,
      if (addedAt != null) 'added_at': addedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  BooksCompanion copyWith({
    Value<int>? id,
    Value<String>? sourceUrl,
    Value<String>? bookUrl,
    Value<String?>? tocUrl,
    Value<String>? name,
    Value<String?>? author,
    Value<String?>? kind,
    Value<String?>? coverUrl,
    Value<String?>? intro,
    Value<String?>? lastChapter,
    Value<int>? status,
    Value<bool>? isPinned,
    Value<DateTime>? addedAt,
    Value<DateTime>? updatedAt,
  }) {
    return BooksCompanion(
      id: id ?? this.id,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      bookUrl: bookUrl ?? this.bookUrl,
      tocUrl: tocUrl ?? this.tocUrl,
      name: name ?? this.name,
      author: author ?? this.author,
      kind: kind ?? this.kind,
      coverUrl: coverUrl ?? this.coverUrl,
      intro: intro ?? this.intro,
      lastChapter: lastChapter ?? this.lastChapter,
      status: status ?? this.status,
      isPinned: isPinned ?? this.isPinned,
      addedAt: addedAt ?? this.addedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (bookUrl.present) {
      map['book_url'] = Variable<String>(bookUrl.value);
    }
    if (tocUrl.present) {
      map['toc_url'] = Variable<String>(tocUrl.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (coverUrl.present) {
      map['cover_url'] = Variable<String>(coverUrl.value);
    }
    if (intro.present) {
      map['intro'] = Variable<String>(intro.value);
    }
    if (lastChapter.present) {
      map['last_chapter'] = Variable<String>(lastChapter.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (isPinned.present) {
      map['is_pinned'] = Variable<bool>(isPinned.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BooksCompanion(')
          ..write('id: $id, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('bookUrl: $bookUrl, ')
          ..write('tocUrl: $tocUrl, ')
          ..write('name: $name, ')
          ..write('author: $author, ')
          ..write('kind: $kind, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('intro: $intro, ')
          ..write('lastChapter: $lastChapter, ')
          ..write('status: $status, ')
          ..write('isPinned: $isPinned, ')
          ..write('addedAt: $addedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $ReadingProgressTable extends ReadingProgress
    with TableInfo<$ReadingProgressTable, ReadingProgressRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadingProgressTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sourceUrlMeta = const VerificationMeta(
    'sourceUrl',
  );
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
    'source_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookUrlMeta = const VerificationMeta(
    'bookUrl',
  );
  @override
  late final GeneratedColumn<String> bookUrl = GeneratedColumn<String>(
    'book_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterUrlMeta = const VerificationMeta(
    'chapterUrl',
  );
  @override
  late final GeneratedColumn<String> chapterUrl = GeneratedColumn<String>(
    'chapter_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chapterNameMeta = const VerificationMeta(
    'chapterName',
  );
  @override
  late final GeneratedColumn<String> chapterName = GeneratedColumn<String>(
    'chapter_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _charOffsetMeta = const VerificationMeta(
    'charOffset',
  );
  @override
  late final GeneratedColumn<int> charOffset = GeneratedColumn<int>(
    'char_offset',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sourceUrl,
    bookUrl,
    chapterUrl,
    chapterName,
    charOffset,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_progress';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReadingProgressRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('source_url')) {
      context.handle(
        _sourceUrlMeta,
        sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceUrlMeta);
    }
    if (data.containsKey('book_url')) {
      context.handle(
        _bookUrlMeta,
        bookUrl.isAcceptableOrUnknown(data['book_url']!, _bookUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_bookUrlMeta);
    }
    if (data.containsKey('chapter_url')) {
      context.handle(
        _chapterUrlMeta,
        chapterUrl.isAcceptableOrUnknown(data['chapter_url']!, _chapterUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_chapterUrlMeta);
    }
    if (data.containsKey('chapter_name')) {
      context.handle(
        _chapterNameMeta,
        chapterName.isAcceptableOrUnknown(
          data['chapter_name']!,
          _chapterNameMeta,
        ),
      );
    }
    if (data.containsKey('char_offset')) {
      context.handle(
        _charOffsetMeta,
        charOffset.isAcceptableOrUnknown(data['char_offset']!, _charOffsetMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sourceUrl, bookUrl};
  @override
  ReadingProgressRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadingProgressRow(
      sourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_url'],
      )!,
      bookUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_url'],
      )!,
      chapterUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapter_url'],
      )!,
      chapterName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapter_name'],
      ),
      charOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}char_offset'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ReadingProgressTable createAlias(String alias) {
    return $ReadingProgressTable(attachedDatabase, alias);
  }
}

class ReadingProgressRow extends DataClass
    implements Insertable<ReadingProgressRow> {
  /// `bookSourceUrl` of the source the book came from.
  final String sourceUrl;

  /// The book's detail page URL.
  final String bookUrl;

  /// The chapter the reader is on.
  final String chapterUrl;

  /// The chapter's title, kept for the shelf's subtitle (the reader may not be open).
  final String? chapterName;

  /// Character offset inside the chapter body.
  final int charOffset;

  /// When the progress was written; the shelf orders «recently read» by it.
  final DateTime updatedAt;
  const ReadingProgressRow({
    required this.sourceUrl,
    required this.bookUrl,
    required this.chapterUrl,
    this.chapterName,
    required this.charOffset,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source_url'] = Variable<String>(sourceUrl);
    map['book_url'] = Variable<String>(bookUrl);
    map['chapter_url'] = Variable<String>(chapterUrl);
    if (!nullToAbsent || chapterName != null) {
      map['chapter_name'] = Variable<String>(chapterName);
    }
    map['char_offset'] = Variable<int>(charOffset);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ReadingProgressCompanion toCompanion(bool nullToAbsent) {
    return ReadingProgressCompanion(
      sourceUrl: Value(sourceUrl),
      bookUrl: Value(bookUrl),
      chapterUrl: Value(chapterUrl),
      chapterName: chapterName == null && nullToAbsent
          ? const Value.absent()
          : Value(chapterName),
      charOffset: Value(charOffset),
      updatedAt: Value(updatedAt),
    );
  }

  factory ReadingProgressRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadingProgressRow(
      sourceUrl: serializer.fromJson<String>(json['sourceUrl']),
      bookUrl: serializer.fromJson<String>(json['bookUrl']),
      chapterUrl: serializer.fromJson<String>(json['chapterUrl']),
      chapterName: serializer.fromJson<String?>(json['chapterName']),
      charOffset: serializer.fromJson<int>(json['charOffset']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sourceUrl': serializer.toJson<String>(sourceUrl),
      'bookUrl': serializer.toJson<String>(bookUrl),
      'chapterUrl': serializer.toJson<String>(chapterUrl),
      'chapterName': serializer.toJson<String?>(chapterName),
      'charOffset': serializer.toJson<int>(charOffset),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ReadingProgressRow copyWith({
    String? sourceUrl,
    String? bookUrl,
    String? chapterUrl,
    Value<String?> chapterName = const Value.absent(),
    int? charOffset,
    DateTime? updatedAt,
  }) => ReadingProgressRow(
    sourceUrl: sourceUrl ?? this.sourceUrl,
    bookUrl: bookUrl ?? this.bookUrl,
    chapterUrl: chapterUrl ?? this.chapterUrl,
    chapterName: chapterName.present ? chapterName.value : this.chapterName,
    charOffset: charOffset ?? this.charOffset,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ReadingProgressRow copyWithCompanion(ReadingProgressCompanion data) {
    return ReadingProgressRow(
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      bookUrl: data.bookUrl.present ? data.bookUrl.value : this.bookUrl,
      chapterUrl: data.chapterUrl.present
          ? data.chapterUrl.value
          : this.chapterUrl,
      chapterName: data.chapterName.present
          ? data.chapterName.value
          : this.chapterName,
      charOffset: data.charOffset.present
          ? data.charOffset.value
          : this.charOffset,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadingProgressRow(')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('bookUrl: $bookUrl, ')
          ..write('chapterUrl: $chapterUrl, ')
          ..write('chapterName: $chapterName, ')
          ..write('charOffset: $charOffset, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sourceUrl,
    bookUrl,
    chapterUrl,
    chapterName,
    charOffset,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadingProgressRow &&
          other.sourceUrl == this.sourceUrl &&
          other.bookUrl == this.bookUrl &&
          other.chapterUrl == this.chapterUrl &&
          other.chapterName == this.chapterName &&
          other.charOffset == this.charOffset &&
          other.updatedAt == this.updatedAt);
}

class ReadingProgressCompanion extends UpdateCompanion<ReadingProgressRow> {
  final Value<String> sourceUrl;
  final Value<String> bookUrl;
  final Value<String> chapterUrl;
  final Value<String?> chapterName;
  final Value<int> charOffset;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ReadingProgressCompanion({
    this.sourceUrl = const Value.absent(),
    this.bookUrl = const Value.absent(),
    this.chapterUrl = const Value.absent(),
    this.chapterName = const Value.absent(),
    this.charOffset = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReadingProgressCompanion.insert({
    required String sourceUrl,
    required String bookUrl,
    required String chapterUrl,
    this.chapterName = const Value.absent(),
    this.charOffset = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : sourceUrl = Value(sourceUrl),
       bookUrl = Value(bookUrl),
       chapterUrl = Value(chapterUrl),
       updatedAt = Value(updatedAt);
  static Insertable<ReadingProgressRow> custom({
    Expression<String>? sourceUrl,
    Expression<String>? bookUrl,
    Expression<String>? chapterUrl,
    Expression<String>? chapterName,
    Expression<int>? charOffset,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (bookUrl != null) 'book_url': bookUrl,
      if (chapterUrl != null) 'chapter_url': chapterUrl,
      if (chapterName != null) 'chapter_name': chapterName,
      if (charOffset != null) 'char_offset': charOffset,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReadingProgressCompanion copyWith({
    Value<String>? sourceUrl,
    Value<String>? bookUrl,
    Value<String>? chapterUrl,
    Value<String?>? chapterName,
    Value<int>? charOffset,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ReadingProgressCompanion(
      sourceUrl: sourceUrl ?? this.sourceUrl,
      bookUrl: bookUrl ?? this.bookUrl,
      chapterUrl: chapterUrl ?? this.chapterUrl,
      chapterName: chapterName ?? this.chapterName,
      charOffset: charOffset ?? this.charOffset,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (bookUrl.present) {
      map['book_url'] = Variable<String>(bookUrl.value);
    }
    if (chapterUrl.present) {
      map['chapter_url'] = Variable<String>(chapterUrl.value);
    }
    if (chapterName.present) {
      map['chapter_name'] = Variable<String>(chapterName.value);
    }
    if (charOffset.present) {
      map['char_offset'] = Variable<int>(charOffset.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadingProgressCompanion(')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('bookUrl: $bookUrl, ')
          ..write('chapterUrl: $chapterUrl, ')
          ..write('chapterName: $chapterName, ')
          ..write('charOffset: $charOffset, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$ReaderDatabase extends GeneratedDatabase {
  _$ReaderDatabase(QueryExecutor e) : super(e);
  $ReaderDatabaseManager get managers => $ReaderDatabaseManager(this);
  late final $CacheEntriesTable cacheEntries = $CacheEntriesTable(this);
  late final $BookSourcesTable bookSources = $BookSourcesTable(this);
  late final $BooksTable books = $BooksTable(this);
  late final $ReadingProgressTable readingProgress = $ReadingProgressTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    cacheEntries,
    bookSources,
    books,
    readingProgress,
  ];
}

typedef $$CacheEntriesTableCreateCompanionBuilder =
    CacheEntriesCompanion Function({
      required String cacheKey,
      required String payload,
      required DateTime expiresAt,
      Value<int> rowid,
    });
typedef $$CacheEntriesTableUpdateCompanionBuilder =
    CacheEntriesCompanion Function({
      Value<String> cacheKey,
      Value<String> payload,
      Value<DateTime> expiresAt,
      Value<int> rowid,
    });

class $$CacheEntriesTableFilterComposer
    extends Composer<_$ReaderDatabase, $CacheEntriesTable> {
  $$CacheEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CacheEntriesTableOrderingComposer
    extends Composer<_$ReaderDatabase, $CacheEntriesTable> {
  $$CacheEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get cacheKey => $composableBuilder(
    column: $table.cacheKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CacheEntriesTableAnnotationComposer
    extends Composer<_$ReaderDatabase, $CacheEntriesTable> {
  $$CacheEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get cacheKey =>
      $composableBuilder(column: $table.cacheKey, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);
}

class $$CacheEntriesTableTableManager
    extends
        RootTableManager<
          _$ReaderDatabase,
          $CacheEntriesTable,
          CacheEntry,
          $$CacheEntriesTableFilterComposer,
          $$CacheEntriesTableOrderingComposer,
          $$CacheEntriesTableAnnotationComposer,
          $$CacheEntriesTableCreateCompanionBuilder,
          $$CacheEntriesTableUpdateCompanionBuilder,
          (
            CacheEntry,
            BaseReferences<_$ReaderDatabase, $CacheEntriesTable, CacheEntry>,
          ),
          CacheEntry,
          PrefetchHooks Function()
        > {
  $$CacheEntriesTableTableManager(_$ReaderDatabase db, $CacheEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CacheEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CacheEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CacheEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> cacheKey = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> expiresAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CacheEntriesCompanion(
                cacheKey: cacheKey,
                payload: payload,
                expiresAt: expiresAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String cacheKey,
                required String payload,
                required DateTime expiresAt,
                Value<int> rowid = const Value.absent(),
              }) => CacheEntriesCompanion.insert(
                cacheKey: cacheKey,
                payload: payload,
                expiresAt: expiresAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CacheEntriesTable, CacheEntry>(table),
                  BaseReferences<
                    _$ReaderDatabase,
                    $CacheEntriesTable,
                    CacheEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CacheEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$ReaderDatabase,
      $CacheEntriesTable,
      CacheEntry,
      $$CacheEntriesTableFilterComposer,
      $$CacheEntriesTableOrderingComposer,
      $$CacheEntriesTableAnnotationComposer,
      $$CacheEntriesTableCreateCompanionBuilder,
      $$CacheEntriesTableUpdateCompanionBuilder,
      (
        CacheEntry,
        BaseReferences<_$ReaderDatabase, $CacheEntriesTable, CacheEntry>,
      ),
      CacheEntry,
      PrefetchHooks Function()
    >;
typedef $$BookSourcesTableCreateCompanionBuilder =
    BookSourcesCompanion Function({
      Value<int> id,
      required String url,
      required String fingerprint,
      required String payload,
      required String name,
      Value<String?> groupName,
      Value<String?> comment,
      Value<int> sourceType,
      Value<bool> isEnabled,
      Value<int> customOrder,
      Value<int> weight,
      Value<int?> lastUpdateTime,
      Value<int?> respondTime,
      required DateTime importedAt,
      required DateTime updatedAt,
    });
typedef $$BookSourcesTableUpdateCompanionBuilder =
    BookSourcesCompanion Function({
      Value<int> id,
      Value<String> url,
      Value<String> fingerprint,
      Value<String> payload,
      Value<String> name,
      Value<String?> groupName,
      Value<String?> comment,
      Value<int> sourceType,
      Value<bool> isEnabled,
      Value<int> customOrder,
      Value<int> weight,
      Value<int?> lastUpdateTime,
      Value<int?> respondTime,
      Value<DateTime> importedAt,
      Value<DateTime> updatedAt,
    });

class $$BookSourcesTableFilterComposer
    extends Composer<_$ReaderDatabase, $BookSourcesTable> {
  $$BookSourcesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupName => $composableBuilder(
    column: $table.groupName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get comment => $composableBuilder(
    column: $table.comment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get customOrder => $composableBuilder(
    column: $table.customOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get weight => $composableBuilder(
    column: $table.weight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastUpdateTime => $composableBuilder(
    column: $table.lastUpdateTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get respondTime => $composableBuilder(
    column: $table.respondTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BookSourcesTableOrderingComposer
    extends Composer<_$ReaderDatabase, $BookSourcesTable> {
  $$BookSourcesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get url => $composableBuilder(
    column: $table.url,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupName => $composableBuilder(
    column: $table.groupName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get comment => $composableBuilder(
    column: $table.comment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get customOrder => $composableBuilder(
    column: $table.customOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get weight => $composableBuilder(
    column: $table.weight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastUpdateTime => $composableBuilder(
    column: $table.lastUpdateTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get respondTime => $composableBuilder(
    column: $table.respondTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BookSourcesTableAnnotationComposer
    extends Composer<_$ReaderDatabase, $BookSourcesTable> {
  $$BookSourcesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get groupName =>
      $composableBuilder(column: $table.groupName, builder: (column) => column);

  GeneratedColumn<String> get comment =>
      $composableBuilder(column: $table.comment, builder: (column) => column);

  GeneratedColumn<int> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isEnabled =>
      $composableBuilder(column: $table.isEnabled, builder: (column) => column);

  GeneratedColumn<int> get customOrder => $composableBuilder(
    column: $table.customOrder,
    builder: (column) => column,
  );

  GeneratedColumn<int> get weight =>
      $composableBuilder(column: $table.weight, builder: (column) => column);

  GeneratedColumn<int> get lastUpdateTime => $composableBuilder(
    column: $table.lastUpdateTime,
    builder: (column) => column,
  );

  GeneratedColumn<int> get respondTime => $composableBuilder(
    column: $table.respondTime,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$BookSourcesTableTableManager
    extends
        RootTableManager<
          _$ReaderDatabase,
          $BookSourcesTable,
          BookSourceRow,
          $$BookSourcesTableFilterComposer,
          $$BookSourcesTableOrderingComposer,
          $$BookSourcesTableAnnotationComposer,
          $$BookSourcesTableCreateCompanionBuilder,
          $$BookSourcesTableUpdateCompanionBuilder,
          (
            BookSourceRow,
            BaseReferences<_$ReaderDatabase, $BookSourcesTable, BookSourceRow>,
          ),
          BookSourceRow,
          PrefetchHooks Function()
        > {
  $$BookSourcesTableTableManager(_$ReaderDatabase db, $BookSourcesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookSourcesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookSourcesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookSourcesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String> fingerprint = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> groupName = const Value.absent(),
                Value<String?> comment = const Value.absent(),
                Value<int> sourceType = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<int> customOrder = const Value.absent(),
                Value<int> weight = const Value.absent(),
                Value<int?> lastUpdateTime = const Value.absent(),
                Value<int?> respondTime = const Value.absent(),
                Value<DateTime> importedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => BookSourcesCompanion(
                id: id,
                url: url,
                fingerprint: fingerprint,
                payload: payload,
                name: name,
                groupName: groupName,
                comment: comment,
                sourceType: sourceType,
                isEnabled: isEnabled,
                customOrder: customOrder,
                weight: weight,
                lastUpdateTime: lastUpdateTime,
                respondTime: respondTime,
                importedAt: importedAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String url,
                required String fingerprint,
                required String payload,
                required String name,
                Value<String?> groupName = const Value.absent(),
                Value<String?> comment = const Value.absent(),
                Value<int> sourceType = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<int> customOrder = const Value.absent(),
                Value<int> weight = const Value.absent(),
                Value<int?> lastUpdateTime = const Value.absent(),
                Value<int?> respondTime = const Value.absent(),
                required DateTime importedAt,
                required DateTime updatedAt,
              }) => BookSourcesCompanion.insert(
                id: id,
                url: url,
                fingerprint: fingerprint,
                payload: payload,
                name: name,
                groupName: groupName,
                comment: comment,
                sourceType: sourceType,
                isEnabled: isEnabled,
                customOrder: customOrder,
                weight: weight,
                lastUpdateTime: lastUpdateTime,
                respondTime: respondTime,
                importedAt: importedAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BookSourcesTable, BookSourceRow>(table),
                  BaseReferences<
                    _$ReaderDatabase,
                    $BookSourcesTable,
                    BookSourceRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BookSourcesTableProcessedTableManager =
    ProcessedTableManager<
      _$ReaderDatabase,
      $BookSourcesTable,
      BookSourceRow,
      $$BookSourcesTableFilterComposer,
      $$BookSourcesTableOrderingComposer,
      $$BookSourcesTableAnnotationComposer,
      $$BookSourcesTableCreateCompanionBuilder,
      $$BookSourcesTableUpdateCompanionBuilder,
      (
        BookSourceRow,
        BaseReferences<_$ReaderDatabase, $BookSourcesTable, BookSourceRow>,
      ),
      BookSourceRow,
      PrefetchHooks Function()
    >;
typedef $$BooksTableCreateCompanionBuilder = BooksCompanion Function({
  Value<int> id,
  required String sourceUrl,
  required String bookUrl,
  Value<String?> tocUrl,
  required String name,
  Value<String?> author,
  Value<String?> kind,
  Value<String?> coverUrl,
  Value<String?> intro,
  Value<String?> lastChapter,
  Value<int> status,
  Value<bool> isPinned,
  required DateTime addedAt,
  required DateTime updatedAt,
});
typedef $$BooksTableUpdateCompanionBuilder = BooksCompanion Function({
  Value<int> id,
  Value<String> sourceUrl,
  Value<String> bookUrl,
  Value<String?> tocUrl,
  Value<String> name,
  Value<String?> author,
  Value<String?> kind,
  Value<String?> coverUrl,
  Value<String?> intro,
  Value<String?> lastChapter,
  Value<int> status,
  Value<bool> isPinned,
  Value<DateTime> addedAt,
  Value<DateTime> updatedAt,
});

class $$BooksTableFilterComposer
    extends Composer<_$ReaderDatabase, $BooksTable> {
  $$BooksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookUrl => $composableBuilder(
    column: $table.bookUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tocUrl => $composableBuilder(
    column: $table.tocUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get intro => $composableBuilder(
    column: $table.intro,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastChapter => $composableBuilder(
    column: $table.lastChapter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BooksTableOrderingComposer
    extends Composer<_$ReaderDatabase, $BooksTable> {
  $$BooksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookUrl => $composableBuilder(
    column: $table.bookUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tocUrl => $composableBuilder(
    column: $table.tocUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverUrl => $composableBuilder(
    column: $table.coverUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get intro => $composableBuilder(
    column: $table.intro,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastChapter => $composableBuilder(
    column: $table.lastChapter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPinned => $composableBuilder(
    column: $table.isPinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BooksTableAnnotationComposer
    extends Composer<_$ReaderDatabase, $BooksTable> {
  $$BooksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<String> get bookUrl =>
      $composableBuilder(column: $table.bookUrl, builder: (column) => column);

  GeneratedColumn<String> get tocUrl =>
      $composableBuilder(column: $table.tocUrl, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get coverUrl =>
      $composableBuilder(column: $table.coverUrl, builder: (column) => column);

  GeneratedColumn<String> get intro =>
      $composableBuilder(column: $table.intro, builder: (column) => column);

  GeneratedColumn<String> get lastChapter => $composableBuilder(
    column: $table.lastChapter,
    builder: (column) => column,
  );

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get isPinned =>
      $composableBuilder(column: $table.isPinned, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$BooksTableTableManager
    extends
        RootTableManager<
          _$ReaderDatabase,
          $BooksTable,
          BookRow,
          $$BooksTableFilterComposer,
          $$BooksTableOrderingComposer,
          $$BooksTableAnnotationComposer,
          $$BooksTableCreateCompanionBuilder,
          $$BooksTableUpdateCompanionBuilder,
          (BookRow, BaseReferences<_$ReaderDatabase, $BooksTable, BookRow>),
          BookRow,
          PrefetchHooks Function()
        > {
  $$BooksTableTableManager(_$ReaderDatabase db, $BooksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BooksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BooksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BooksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> sourceUrl = const Value.absent(),
                Value<String> bookUrl = const Value.absent(),
                Value<String?> tocUrl = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<String?> kind = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<String?> intro = const Value.absent(),
                Value<String?> lastChapter = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => BooksCompanion(
                id: id,
                sourceUrl: sourceUrl,
                bookUrl: bookUrl,
                tocUrl: tocUrl,
                name: name,
                author: author,
                kind: kind,
                coverUrl: coverUrl,
                intro: intro,
                lastChapter: lastChapter,
                status: status,
                isPinned: isPinned,
                addedAt: addedAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String sourceUrl,
                required String bookUrl,
                Value<String?> tocUrl = const Value.absent(),
                required String name,
                Value<String?> author = const Value.absent(),
                Value<String?> kind = const Value.absent(),
                Value<String?> coverUrl = const Value.absent(),
                Value<String?> intro = const Value.absent(),
                Value<String?> lastChapter = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<bool> isPinned = const Value.absent(),
                required DateTime addedAt,
                required DateTime updatedAt,
              }) => BooksCompanion.insert(
                id: id,
                sourceUrl: sourceUrl,
                bookUrl: bookUrl,
                tocUrl: tocUrl,
                name: name,
                author: author,
                kind: kind,
                coverUrl: coverUrl,
                intro: intro,
                lastChapter: lastChapter,
                status: status,
                isPinned: isPinned,
                addedAt: addedAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BooksTable, BookRow>(table),
                  BaseReferences<_$ReaderDatabase, $BooksTable, BookRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BooksTableProcessedTableManager =
    ProcessedTableManager<
      _$ReaderDatabase,
      $BooksTable,
      BookRow,
      $$BooksTableFilterComposer,
      $$BooksTableOrderingComposer,
      $$BooksTableAnnotationComposer,
      $$BooksTableCreateCompanionBuilder,
      $$BooksTableUpdateCompanionBuilder,
      (BookRow, BaseReferences<_$ReaderDatabase, $BooksTable, BookRow>),
      BookRow,
      PrefetchHooks Function()
    >;
typedef $$ReadingProgressTableCreateCompanionBuilder =
    ReadingProgressCompanion Function({
      required String sourceUrl,
      required String bookUrl,
      required String chapterUrl,
      Value<String?> chapterName,
      Value<int> charOffset,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ReadingProgressTableUpdateCompanionBuilder =
    ReadingProgressCompanion Function({
      Value<String> sourceUrl,
      Value<String> bookUrl,
      Value<String> chapterUrl,
      Value<String?> chapterName,
      Value<int> charOffset,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ReadingProgressTableFilterComposer
    extends Composer<_$ReaderDatabase, $ReadingProgressTable> {
  $$ReadingProgressTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookUrl => $composableBuilder(
    column: $table.bookUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chapterUrl => $composableBuilder(
    column: $table.chapterUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chapterName => $composableBuilder(
    column: $table.chapterName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get charOffset => $composableBuilder(
    column: $table.charOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReadingProgressTableOrderingComposer
    extends Composer<_$ReaderDatabase, $ReadingProgressTable> {
  $$ReadingProgressTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookUrl => $composableBuilder(
    column: $table.bookUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chapterUrl => $composableBuilder(
    column: $table.chapterUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chapterName => $composableBuilder(
    column: $table.chapterName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get charOffset => $composableBuilder(
    column: $table.charOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReadingProgressTableAnnotationComposer
    extends Composer<_$ReaderDatabase, $ReadingProgressTable> {
  $$ReadingProgressTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<String> get bookUrl =>
      $composableBuilder(column: $table.bookUrl, builder: (column) => column);

  GeneratedColumn<String> get chapterUrl => $composableBuilder(
    column: $table.chapterUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get chapterName => $composableBuilder(
    column: $table.chapterName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get charOffset => $composableBuilder(
    column: $table.charOffset,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ReadingProgressTableTableManager
    extends
        RootTableManager<
          _$ReaderDatabase,
          $ReadingProgressTable,
          ReadingProgressRow,
          $$ReadingProgressTableFilterComposer,
          $$ReadingProgressTableOrderingComposer,
          $$ReadingProgressTableAnnotationComposer,
          $$ReadingProgressTableCreateCompanionBuilder,
          $$ReadingProgressTableUpdateCompanionBuilder,
          (
            ReadingProgressRow,
            BaseReferences<
              _$ReaderDatabase,
              $ReadingProgressTable,
              ReadingProgressRow
            >,
          ),
          ReadingProgressRow,
          PrefetchHooks Function()
        > {
  $$ReadingProgressTableTableManager(
    _$ReaderDatabase db,
    $ReadingProgressTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadingProgressTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReadingProgressTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReadingProgressTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sourceUrl = const Value.absent(),
                Value<String> bookUrl = const Value.absent(),
                Value<String> chapterUrl = const Value.absent(),
                Value<String?> chapterName = const Value.absent(),
                Value<int> charOffset = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReadingProgressCompanion(
                sourceUrl: sourceUrl,
                bookUrl: bookUrl,
                chapterUrl: chapterUrl,
                chapterName: chapterName,
                charOffset: charOffset,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sourceUrl,
                required String bookUrl,
                required String chapterUrl,
                Value<String?> chapterName = const Value.absent(),
                Value<int> charOffset = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ReadingProgressCompanion.insert(
                sourceUrl: sourceUrl,
                bookUrl: bookUrl,
                chapterUrl: chapterUrl,
                chapterName: chapterName,
                charOffset: charOffset,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReadingProgressTable, ReadingProgressRow>(table),
                  BaseReferences<
                    _$ReaderDatabase,
                    $ReadingProgressTable,
                    ReadingProgressRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReadingProgressTableProcessedTableManager =
    ProcessedTableManager<
      _$ReaderDatabase,
      $ReadingProgressTable,
      ReadingProgressRow,
      $$ReadingProgressTableFilterComposer,
      $$ReadingProgressTableOrderingComposer,
      $$ReadingProgressTableAnnotationComposer,
      $$ReadingProgressTableCreateCompanionBuilder,
      $$ReadingProgressTableUpdateCompanionBuilder,
      (
        ReadingProgressRow,
        BaseReferences<
          _$ReaderDatabase,
          $ReadingProgressTable,
          ReadingProgressRow
        >,
      ),
      ReadingProgressRow,
      PrefetchHooks Function()
    >;

class $ReaderDatabaseManager {
  final _$ReaderDatabase _db;
  $ReaderDatabaseManager(this._db);
  $$CacheEntriesTableTableManager get cacheEntries =>
      $$CacheEntriesTableTableManager(_db, _db.cacheEntries);
  $$BookSourcesTableTableManager get bookSources =>
      $$BookSourcesTableTableManager(_db, _db.bookSources);
  $$BooksTableTableManager get books =>
      $$BooksTableTableManager(_db, _db.books);
  $$ReadingProgressTableTableManager get readingProgress =>
      $$ReadingProgressTableTableManager(_db, _db.readingProgress);
}
