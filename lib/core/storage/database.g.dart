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
  static const VerificationMeta _scopeKeyMeta = const VerificationMeta(
    'scopeKey',
  );
  @override
  late final GeneratedColumn<String> scopeKey = GeneratedColumn<String>(
    'scope_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceKeyMeta = const VerificationMeta(
    'sourceKey',
  );
  @override
  late final GeneratedColumn<String> sourceKey = GeneratedColumn<String>(
    'source_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    cacheKey,
    payload,
    expiresAt,
    scopeKey,
    sourceKey,
  ];
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
    if (data.containsKey('scope_key')) {
      context.handle(
        _scopeKeyMeta,
        scopeKey.isAcceptableOrUnknown(data['scope_key']!, _scopeKeyMeta),
      );
    }
    if (data.containsKey('source_key')) {
      context.handle(
        _sourceKeyMeta,
        sourceKey.isAcceptableOrUnknown(data['source_key']!, _sourceKeyMeta),
      );
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
      scopeKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope_key'],
      ),
      sourceKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_key'],
      ),
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

  /// Digest of the book identity the entry belongs to, or `null` for older rows.
  ///
  /// Takes no part in the lookup key; it only supports per-book cache views.
  final String? scopeKey;

  /// Digest of the book source the entry came from (`ADR-0072 §决策 1`).
  ///
  /// Like [scopeKey] it is a view column, not part of the key: the per-source cache page counts and
  /// clears by it. `null` only for rows written before v10 — the migration drops those, so the
  /// page never shows a count it cannot justify.
  final String? sourceKey;
  const CacheEntry({
    required this.cacheKey,
    required this.payload,
    required this.expiresAt,
    this.scopeKey,
    this.sourceKey,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['cache_key'] = Variable<String>(cacheKey);
    map['payload'] = Variable<String>(payload);
    map['expires_at'] = Variable<DateTime>(expiresAt);
    if (!nullToAbsent || scopeKey != null) {
      map['scope_key'] = Variable<String>(scopeKey);
    }
    if (!nullToAbsent || sourceKey != null) {
      map['source_key'] = Variable<String>(sourceKey);
    }
    return map;
  }

  CacheEntriesCompanion toCompanion(bool nullToAbsent) {
    return CacheEntriesCompanion(
      cacheKey: Value(cacheKey),
      payload: Value(payload),
      expiresAt: Value(expiresAt),
      scopeKey: scopeKey == null && nullToAbsent
          ? const Value.absent()
          : Value(scopeKey),
      sourceKey: sourceKey == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceKey),
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
      scopeKey: serializer.fromJson<String?>(json['scopeKey']),
      sourceKey: serializer.fromJson<String?>(json['sourceKey']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cacheKey': serializer.toJson<String>(cacheKey),
      'payload': serializer.toJson<String>(payload),
      'expiresAt': serializer.toJson<DateTime>(expiresAt),
      'scopeKey': serializer.toJson<String?>(scopeKey),
      'sourceKey': serializer.toJson<String?>(sourceKey),
    };
  }

  CacheEntry copyWith({
    String? cacheKey,
    String? payload,
    DateTime? expiresAt,
    Value<String?> scopeKey = const Value.absent(),
    Value<String?> sourceKey = const Value.absent(),
  }) => CacheEntry(
    cacheKey: cacheKey ?? this.cacheKey,
    payload: payload ?? this.payload,
    expiresAt: expiresAt ?? this.expiresAt,
    scopeKey: scopeKey.present ? scopeKey.value : this.scopeKey,
    sourceKey: sourceKey.present ? sourceKey.value : this.sourceKey,
  );
  CacheEntry copyWithCompanion(CacheEntriesCompanion data) {
    return CacheEntry(
      cacheKey: data.cacheKey.present ? data.cacheKey.value : this.cacheKey,
      payload: data.payload.present ? data.payload.value : this.payload,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      scopeKey: data.scopeKey.present ? data.scopeKey.value : this.scopeKey,
      sourceKey: data.sourceKey.present ? data.sourceKey.value : this.sourceKey,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CacheEntry(')
          ..write('cacheKey: $cacheKey, ')
          ..write('payload: $payload, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('scopeKey: $scopeKey, ')
          ..write('sourceKey: $sourceKey')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(cacheKey, payload, expiresAt, scopeKey, sourceKey);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CacheEntry &&
          other.cacheKey == this.cacheKey &&
          other.payload == this.payload &&
          other.expiresAt == this.expiresAt &&
          other.scopeKey == this.scopeKey &&
          other.sourceKey == this.sourceKey);
}

class CacheEntriesCompanion extends UpdateCompanion<CacheEntry> {
  final Value<String> cacheKey;
  final Value<String> payload;
  final Value<DateTime> expiresAt;
  final Value<String?> scopeKey;
  final Value<String?> sourceKey;
  final Value<int> rowid;
  const CacheEntriesCompanion({
    this.cacheKey = const Value.absent(),
    this.payload = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.scopeKey = const Value.absent(),
    this.sourceKey = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CacheEntriesCompanion.insert({
    required String cacheKey,
    required String payload,
    required DateTime expiresAt,
    this.scopeKey = const Value.absent(),
    this.sourceKey = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : cacheKey = Value(cacheKey),
       payload = Value(payload),
       expiresAt = Value(expiresAt);
  static Insertable<CacheEntry> custom({
    Expression<String>? cacheKey,
    Expression<String>? payload,
    Expression<DateTime>? expiresAt,
    Expression<String>? scopeKey,
    Expression<String>? sourceKey,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cacheKey != null) 'cache_key': cacheKey,
      if (payload != null) 'payload': payload,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (scopeKey != null) 'scope_key': scopeKey,
      if (sourceKey != null) 'source_key': sourceKey,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CacheEntriesCompanion copyWith({
    Value<String>? cacheKey,
    Value<String>? payload,
    Value<DateTime>? expiresAt,
    Value<String?>? scopeKey,
    Value<String?>? sourceKey,
    Value<int>? rowid,
  }) {
    return CacheEntriesCompanion(
      cacheKey: cacheKey ?? this.cacheKey,
      payload: payload ?? this.payload,
      expiresAt: expiresAt ?? this.expiresAt,
      scopeKey: scopeKey ?? this.scopeKey,
      sourceKey: sourceKey ?? this.sourceKey,
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
    if (scopeKey.present) {
      map['scope_key'] = Variable<String>(scopeKey.value);
    }
    if (sourceKey.present) {
      map['source_key'] = Variable<String>(sourceKey.value);
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
          ..write('scopeKey: $scopeKey, ')
          ..write('sourceKey: $sourceKey, ')
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
  static const VerificationMeta _isExploreEnabledMeta = const VerificationMeta(
    'isExploreEnabled',
  );
  @override
  late final GeneratedColumn<bool> isExploreEnabled = GeneratedColumn<bool>(
    'is_explore_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_explore_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
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
  static const VerificationMeta _loginInfoMeta = const VerificationMeta(
    'loginInfo',
  );
  @override
  late final GeneratedColumn<String> loginInfo = GeneratedColumn<String>(
    'login_info',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _loginHeaderMeta = const VerificationMeta(
    'loginHeader',
  );
  @override
  late final GeneratedColumn<String> loginHeader = GeneratedColumn<String>(
    'login_header',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
    isExploreEnabled,
    weight,
    lastUpdateTime,
    respondTime,
    loginInfo,
    loginHeader,
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
    if (data.containsKey('is_explore_enabled')) {
      context.handle(
        _isExploreEnabledMeta,
        isExploreEnabled.isAcceptableOrUnknown(
          data['is_explore_enabled']!,
          _isExploreEnabledMeta,
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
    if (data.containsKey('login_info')) {
      context.handle(
        _loginInfoMeta,
        loginInfo.isAcceptableOrUnknown(data['login_info']!, _loginInfoMeta),
      );
    }
    if (data.containsKey('login_header')) {
      context.handle(
        _loginHeaderMeta,
        loginHeader.isAcceptableOrUnknown(
          data['login_header']!,
          _loginHeaderMeta,
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
      isExploreEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_explore_enabled'],
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
      loginInfo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}login_info'],
      ),
      loginHeader: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}login_header'],
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
  /// Synthetic primary key; `AUTOINCREMENT` stops SQLite from reusing a deleted id.
  final int id;

  /// `bookSourceUrl` — upstream's natural identifier.
  final String url;

  /// sha256 of the behaviour fields' canonical JSON.
  final String fingerprint;

  /// The entry exactly as imported; unknown keys survive here byte-for-byte.
  final String payload;

  /// `bookSourceName`, projected for the list.
  final String name;

  /// `bookSourceGroup`, projected for the list.
  final String? groupName;

  /// `bookSourceComment`, rewritten by the batch check; not part of [payload].
  final String? comment;

  /// `bookSourceType`, projected for the list.
  final int sourceType;

  /// User state: whether the source takes part in search / explore.
  final bool isEnabled;

  /// User state: the manual sort order.
  final int customOrder;

  /// User state: whether the source's discover page is offered.
  final bool isExploreEnabled;

  /// `weight`, projected for sorting.
  final int weight;

  /// `lastUpdateTime`, projected for display.
  final int? lastUpdateTime;

  /// `respondTime`, projected for display.
  final int? respondTime;

  /// The `loginUi` form's values, as a JSON object, or `null` when the source was never signed in
  /// (`docs/dev/roadmap.md` M22, ADR-0072 §决策 3).
  ///
  /// User state like [isEnabled]: an import never overwrites it, and it is stored in cleartext —
  /// the same level as the cookie jar (registered in `roadmap.md` §3.7).
  final String? loginInfo;

  /// The header map `source.putLoginHeader` stored, as JSON, or `null` when the source never
  /// signed in (M25/S3b).
  ///
  /// Upstream keeps it in `CacheManager` under `loginHeader_<url>`, i.e. keyed by source URL, which
  /// is what the engine has when a rule writes it; several rows may share one URL and then share
  /// this value. User state like [loginInfo]: an import never overwrites it, and the engine merges
  /// it over the source's own `header` on every request (`BaseSource.getHeaderMap`).
  final String? loginHeader;

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
    required this.isExploreEnabled,
    required this.weight,
    this.lastUpdateTime,
    this.respondTime,
    this.loginInfo,
    this.loginHeader,
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
    map['is_explore_enabled'] = Variable<bool>(isExploreEnabled);
    map['weight'] = Variable<int>(weight);
    if (!nullToAbsent || lastUpdateTime != null) {
      map['last_update_time'] = Variable<int>(lastUpdateTime);
    }
    if (!nullToAbsent || respondTime != null) {
      map['respond_time'] = Variable<int>(respondTime);
    }
    if (!nullToAbsent || loginInfo != null) {
      map['login_info'] = Variable<String>(loginInfo);
    }
    if (!nullToAbsent || loginHeader != null) {
      map['login_header'] = Variable<String>(loginHeader);
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
      isExploreEnabled: Value(isExploreEnabled),
      weight: Value(weight),
      lastUpdateTime: lastUpdateTime == null && nullToAbsent
          ? const Value.absent()
          : Value(lastUpdateTime),
      respondTime: respondTime == null && nullToAbsent
          ? const Value.absent()
          : Value(respondTime),
      loginInfo: loginInfo == null && nullToAbsent
          ? const Value.absent()
          : Value(loginInfo),
      loginHeader: loginHeader == null && nullToAbsent
          ? const Value.absent()
          : Value(loginHeader),
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
      isExploreEnabled: serializer.fromJson<bool>(json['isExploreEnabled']),
      weight: serializer.fromJson<int>(json['weight']),
      lastUpdateTime: serializer.fromJson<int?>(json['lastUpdateTime']),
      respondTime: serializer.fromJson<int?>(json['respondTime']),
      loginInfo: serializer.fromJson<String?>(json['loginInfo']),
      loginHeader: serializer.fromJson<String?>(json['loginHeader']),
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
      'isExploreEnabled': serializer.toJson<bool>(isExploreEnabled),
      'weight': serializer.toJson<int>(weight),
      'lastUpdateTime': serializer.toJson<int?>(lastUpdateTime),
      'respondTime': serializer.toJson<int?>(respondTime),
      'loginInfo': serializer.toJson<String?>(loginInfo),
      'loginHeader': serializer.toJson<String?>(loginHeader),
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
    bool? isExploreEnabled,
    int? weight,
    Value<int?> lastUpdateTime = const Value.absent(),
    Value<int?> respondTime = const Value.absent(),
    Value<String?> loginInfo = const Value.absent(),
    Value<String?> loginHeader = const Value.absent(),
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
    isExploreEnabled: isExploreEnabled ?? this.isExploreEnabled,
    weight: weight ?? this.weight,
    lastUpdateTime: lastUpdateTime.present
        ? lastUpdateTime.value
        : this.lastUpdateTime,
    respondTime: respondTime.present ? respondTime.value : this.respondTime,
    loginInfo: loginInfo.present ? loginInfo.value : this.loginInfo,
    loginHeader: loginHeader.present ? loginHeader.value : this.loginHeader,
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
      isExploreEnabled: data.isExploreEnabled.present
          ? data.isExploreEnabled.value
          : this.isExploreEnabled,
      weight: data.weight.present ? data.weight.value : this.weight,
      lastUpdateTime: data.lastUpdateTime.present
          ? data.lastUpdateTime.value
          : this.lastUpdateTime,
      respondTime: data.respondTime.present
          ? data.respondTime.value
          : this.respondTime,
      loginInfo: data.loginInfo.present ? data.loginInfo.value : this.loginInfo,
      loginHeader: data.loginHeader.present
          ? data.loginHeader.value
          : this.loginHeader,
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
          ..write('isExploreEnabled: $isExploreEnabled, ')
          ..write('weight: $weight, ')
          ..write('lastUpdateTime: $lastUpdateTime, ')
          ..write('respondTime: $respondTime, ')
          ..write('loginInfo: $loginInfo, ')
          ..write('loginHeader: $loginHeader, ')
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
    isExploreEnabled,
    weight,
    lastUpdateTime,
    respondTime,
    loginInfo,
    loginHeader,
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
          other.isExploreEnabled == this.isExploreEnabled &&
          other.weight == this.weight &&
          other.lastUpdateTime == this.lastUpdateTime &&
          other.respondTime == this.respondTime &&
          other.loginInfo == this.loginInfo &&
          other.loginHeader == this.loginHeader &&
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
  final Value<bool> isExploreEnabled;
  final Value<int> weight;
  final Value<int?> lastUpdateTime;
  final Value<int?> respondTime;
  final Value<String?> loginInfo;
  final Value<String?> loginHeader;
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
    this.isExploreEnabled = const Value.absent(),
    this.weight = const Value.absent(),
    this.lastUpdateTime = const Value.absent(),
    this.respondTime = const Value.absent(),
    this.loginInfo = const Value.absent(),
    this.loginHeader = const Value.absent(),
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
    this.isExploreEnabled = const Value.absent(),
    this.weight = const Value.absent(),
    this.lastUpdateTime = const Value.absent(),
    this.respondTime = const Value.absent(),
    this.loginInfo = const Value.absent(),
    this.loginHeader = const Value.absent(),
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
    Expression<bool>? isExploreEnabled,
    Expression<int>? weight,
    Expression<int>? lastUpdateTime,
    Expression<int>? respondTime,
    Expression<String>? loginInfo,
    Expression<String>? loginHeader,
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
      if (isExploreEnabled != null) 'is_explore_enabled': isExploreEnabled,
      if (weight != null) 'weight': weight,
      if (lastUpdateTime != null) 'last_update_time': lastUpdateTime,
      if (respondTime != null) 'respond_time': respondTime,
      if (loginInfo != null) 'login_info': loginInfo,
      if (loginHeader != null) 'login_header': loginHeader,
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
    Value<bool>? isExploreEnabled,
    Value<int>? weight,
    Value<int?>? lastUpdateTime,
    Value<int?>? respondTime,
    Value<String?>? loginInfo,
    Value<String?>? loginHeader,
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
      isExploreEnabled: isExploreEnabled ?? this.isExploreEnabled,
      weight: weight ?? this.weight,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
      respondTime: respondTime ?? this.respondTime,
      loginInfo: loginInfo ?? this.loginInfo,
      loginHeader: loginHeader ?? this.loginHeader,
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
    if (isExploreEnabled.present) {
      map['is_explore_enabled'] = Variable<bool>(isExploreEnabled.value);
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
    if (loginInfo.present) {
      map['login_info'] = Variable<String>(loginInfo.value);
    }
    if (loginHeader.present) {
      map['login_header'] = Variable<String>(loginHeader.value);
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
          ..write('isExploreEnabled: $isExploreEnabled, ')
          ..write('weight: $weight, ')
          ..write('lastUpdateTime: $lastUpdateTime, ')
          ..write('respondTime: $respondTime, ')
          ..write('loginInfo: $loginInfo, ')
          ..write('loginHeader: $loginHeader, ')
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
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<int> groupId = GeneratedColumn<int>(
    'group_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _customCoverPathMeta = const VerificationMeta(
    'customCoverPath',
  );
  @override
  late final GeneratedColumn<String> customCoverPath = GeneratedColumn<String>(
    'custom_cover_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    groupId,
    customCoverPath,
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
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    }
    if (data.containsKey('custom_cover_path')) {
      context.handle(
        _customCoverPathMeta,
        customCoverPath.isAcceptableOrUnknown(
          data['custom_cover_path']!,
          _customCoverPathMeta,
        ),
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
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}group_id'],
      ),
      customCoverPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}custom_cover_path'],
      ),
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

  /// The table-of-contents URL resolved from the detail page.
  ///
  /// A source may keep chapters elsewhere; opening the reader falls back to [bookUrl].
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

  /// User state: 0 = tracking, 1 = finished; the UI owns it.
  final int status;

  /// User state: whether the entry is pinned to the top of the shelf.
  final bool isPinned;

  /// The shelf group, or `null` for 「未分组」.
  ///
  /// No foreign key: the delete path clears this column explicitly in a transaction.
  final int? groupId;

  /// Absolute path of a cover the user picked; `null` falls back to [coverUrl].
  final String? customCoverPath;

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
    this.groupId,
    this.customCoverPath,
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
    if (!nullToAbsent || groupId != null) {
      map['group_id'] = Variable<int>(groupId);
    }
    if (!nullToAbsent || customCoverPath != null) {
      map['custom_cover_path'] = Variable<String>(customCoverPath);
    }
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
      groupId: groupId == null && nullToAbsent
          ? const Value.absent()
          : Value(groupId),
      customCoverPath: customCoverPath == null && nullToAbsent
          ? const Value.absent()
          : Value(customCoverPath),
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
      groupId: serializer.fromJson<int?>(json['groupId']),
      customCoverPath: serializer.fromJson<String?>(json['customCoverPath']),
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
      'groupId': serializer.toJson<int?>(groupId),
      'customCoverPath': serializer.toJson<String?>(customCoverPath),
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
    Value<int?> groupId = const Value.absent(),
    Value<String?> customCoverPath = const Value.absent(),
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
    groupId: groupId.present ? groupId.value : this.groupId,
    customCoverPath: customCoverPath.present
        ? customCoverPath.value
        : this.customCoverPath,
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
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      customCoverPath: data.customCoverPath.present
          ? data.customCoverPath.value
          : this.customCoverPath,
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
          ..write('groupId: $groupId, ')
          ..write('customCoverPath: $customCoverPath, ')
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
    groupId,
    customCoverPath,
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
          other.groupId == this.groupId &&
          other.customCoverPath == this.customCoverPath &&
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
  final Value<int?> groupId;
  final Value<String?> customCoverPath;
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
    this.groupId = const Value.absent(),
    this.customCoverPath = const Value.absent(),
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
    this.groupId = const Value.absent(),
    this.customCoverPath = const Value.absent(),
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
    Expression<int>? groupId,
    Expression<String>? customCoverPath,
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
      if (groupId != null) 'group_id': groupId,
      if (customCoverPath != null) 'custom_cover_path': customCoverPath,
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
    Value<int?>? groupId,
    Value<String?>? customCoverPath,
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
      groupId: groupId ?? this.groupId,
      customCoverPath: customCoverPath ?? this.customCoverPath,
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
    if (groupId.present) {
      map['group_id'] = Variable<int>(groupId.value);
    }
    if (customCoverPath.present) {
      map['custom_cover_path'] = Variable<String>(customCoverPath.value);
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
          ..write('groupId: $groupId, ')
          ..write('customCoverPath: $customCoverPath, ')
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

class $SourceChecksTable extends SourceChecks
    with TableInfo<$SourceChecksTable, SourceCheckRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SourceChecksTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<int> sourceId = GeneratedColumn<int>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _checkedAtMeta = const VerificationMeta(
    'checkedAt',
  );
  @override
  late final GeneratedColumn<DateTime> checkedAt = GeneratedColumn<DateTime>(
    'checked_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _invalidGroupsMeta = const VerificationMeta(
    'invalidGroups',
  );
  @override
  late final GeneratedColumn<String> invalidGroups = GeneratedColumn<String>(
    'invalid_groups',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorCommentMeta = const VerificationMeta(
    'errorComment',
  );
  @override
  late final GeneratedColumn<String> errorComment = GeneratedColumn<String>(
    'error_comment',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _elapsedMillisMeta = const VerificationMeta(
    'elapsedMillis',
  );
  @override
  late final GeneratedColumn<int> elapsedMillis = GeneratedColumn<int>(
    'elapsed_millis',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourceId,
    checkedAt,
    status,
    invalidGroups,
    errorComment,
    elapsedMillis,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'source_checks';
  @override
  VerificationContext validateIntegrity(
    Insertable<SourceCheckRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('checked_at')) {
      context.handle(
        _checkedAtMeta,
        checkedAt.isAcceptableOrUnknown(data['checked_at']!, _checkedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_checkedAtMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('invalid_groups')) {
      context.handle(
        _invalidGroupsMeta,
        invalidGroups.isAcceptableOrUnknown(
          data['invalid_groups']!,
          _invalidGroupsMeta,
        ),
      );
    }
    if (data.containsKey('error_comment')) {
      context.handle(
        _errorCommentMeta,
        errorComment.isAcceptableOrUnknown(
          data['error_comment']!,
          _errorCommentMeta,
        ),
      );
    }
    if (data.containsKey('elapsed_millis')) {
      context.handle(
        _elapsedMillisMeta,
        elapsedMillis.isAcceptableOrUnknown(
          data['elapsed_millis']!,
          _elapsedMillisMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_elapsedMillisMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SourceCheckRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SourceCheckRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_id'],
      )!,
      checkedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}checked_at'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      invalidGroups: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}invalid_groups'],
      ),
      errorComment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_comment'],
      ),
      elapsedMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}elapsed_millis'],
      )!,
    );
  }

  @override
  $SourceChecksTable createAlias(String alias) {
    return $SourceChecksTable(attachedDatabase, alias);
  }
}

class SourceCheckRow extends DataClass implements Insertable<SourceCheckRow> {
  /// Synthetic primary key; the history is append-only.
  final int id;

  /// The `book_sources.id` this run belongs to.
  ///
  /// No foreign key: the delete paths remove the history in one transaction.
  final int sourceId;

  /// When the run finished, from the injected `Clock`.
  final DateTime checkedAt;

  /// `succeeded` / `failed` / `cancelled` — the domain enum's name.
  final String status;

  /// The failure group tokens this run wrote, joined, or `null` when healthy.
  final String? invalidGroups;

  /// The note this run wrote into `bookSourceComment`, or `null` when healthy.
  final String? errorComment;

  /// How long the run took, which is also what `respondTime` stores.
  final int elapsedMillis;
  const SourceCheckRow({
    required this.id,
    required this.sourceId,
    required this.checkedAt,
    required this.status,
    this.invalidGroups,
    this.errorComment,
    required this.elapsedMillis,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['source_id'] = Variable<int>(sourceId);
    map['checked_at'] = Variable<DateTime>(checkedAt);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || invalidGroups != null) {
      map['invalid_groups'] = Variable<String>(invalidGroups);
    }
    if (!nullToAbsent || errorComment != null) {
      map['error_comment'] = Variable<String>(errorComment);
    }
    map['elapsed_millis'] = Variable<int>(elapsedMillis);
    return map;
  }

  SourceChecksCompanion toCompanion(bool nullToAbsent) {
    return SourceChecksCompanion(
      id: Value(id),
      sourceId: Value(sourceId),
      checkedAt: Value(checkedAt),
      status: Value(status),
      invalidGroups: invalidGroups == null && nullToAbsent
          ? const Value.absent()
          : Value(invalidGroups),
      errorComment: errorComment == null && nullToAbsent
          ? const Value.absent()
          : Value(errorComment),
      elapsedMillis: Value(elapsedMillis),
    );
  }

  factory SourceCheckRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SourceCheckRow(
      id: serializer.fromJson<int>(json['id']),
      sourceId: serializer.fromJson<int>(json['sourceId']),
      checkedAt: serializer.fromJson<DateTime>(json['checkedAt']),
      status: serializer.fromJson<String>(json['status']),
      invalidGroups: serializer.fromJson<String?>(json['invalidGroups']),
      errorComment: serializer.fromJson<String?>(json['errorComment']),
      elapsedMillis: serializer.fromJson<int>(json['elapsedMillis']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sourceId': serializer.toJson<int>(sourceId),
      'checkedAt': serializer.toJson<DateTime>(checkedAt),
      'status': serializer.toJson<String>(status),
      'invalidGroups': serializer.toJson<String?>(invalidGroups),
      'errorComment': serializer.toJson<String?>(errorComment),
      'elapsedMillis': serializer.toJson<int>(elapsedMillis),
    };
  }

  SourceCheckRow copyWith({
    int? id,
    int? sourceId,
    DateTime? checkedAt,
    String? status,
    Value<String?> invalidGroups = const Value.absent(),
    Value<String?> errorComment = const Value.absent(),
    int? elapsedMillis,
  }) => SourceCheckRow(
    id: id ?? this.id,
    sourceId: sourceId ?? this.sourceId,
    checkedAt: checkedAt ?? this.checkedAt,
    status: status ?? this.status,
    invalidGroups: invalidGroups.present
        ? invalidGroups.value
        : this.invalidGroups,
    errorComment: errorComment.present ? errorComment.value : this.errorComment,
    elapsedMillis: elapsedMillis ?? this.elapsedMillis,
  );
  SourceCheckRow copyWithCompanion(SourceChecksCompanion data) {
    return SourceCheckRow(
      id: data.id.present ? data.id.value : this.id,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      checkedAt: data.checkedAt.present ? data.checkedAt.value : this.checkedAt,
      status: data.status.present ? data.status.value : this.status,
      invalidGroups: data.invalidGroups.present
          ? data.invalidGroups.value
          : this.invalidGroups,
      errorComment: data.errorComment.present
          ? data.errorComment.value
          : this.errorComment,
      elapsedMillis: data.elapsedMillis.present
          ? data.elapsedMillis.value
          : this.elapsedMillis,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SourceCheckRow(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('checkedAt: $checkedAt, ')
          ..write('status: $status, ')
          ..write('invalidGroups: $invalidGroups, ')
          ..write('errorComment: $errorComment, ')
          ..write('elapsedMillis: $elapsedMillis')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sourceId,
    checkedAt,
    status,
    invalidGroups,
    errorComment,
    elapsedMillis,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SourceCheckRow &&
          other.id == this.id &&
          other.sourceId == this.sourceId &&
          other.checkedAt == this.checkedAt &&
          other.status == this.status &&
          other.invalidGroups == this.invalidGroups &&
          other.errorComment == this.errorComment &&
          other.elapsedMillis == this.elapsedMillis);
}

class SourceChecksCompanion extends UpdateCompanion<SourceCheckRow> {
  final Value<int> id;
  final Value<int> sourceId;
  final Value<DateTime> checkedAt;
  final Value<String> status;
  final Value<String?> invalidGroups;
  final Value<String?> errorComment;
  final Value<int> elapsedMillis;
  const SourceChecksCompanion({
    this.id = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.checkedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.invalidGroups = const Value.absent(),
    this.errorComment = const Value.absent(),
    this.elapsedMillis = const Value.absent(),
  });
  SourceChecksCompanion.insert({
    this.id = const Value.absent(),
    required int sourceId,
    required DateTime checkedAt,
    required String status,
    this.invalidGroups = const Value.absent(),
    this.errorComment = const Value.absent(),
    required int elapsedMillis,
  }) : sourceId = Value(sourceId),
       checkedAt = Value(checkedAt),
       status = Value(status),
       elapsedMillis = Value(elapsedMillis);
  static Insertable<SourceCheckRow> custom({
    Expression<int>? id,
    Expression<int>? sourceId,
    Expression<DateTime>? checkedAt,
    Expression<String>? status,
    Expression<String>? invalidGroups,
    Expression<String>? errorComment,
    Expression<int>? elapsedMillis,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceId != null) 'source_id': sourceId,
      if (checkedAt != null) 'checked_at': checkedAt,
      if (status != null) 'status': status,
      if (invalidGroups != null) 'invalid_groups': invalidGroups,
      if (errorComment != null) 'error_comment': errorComment,
      if (elapsedMillis != null) 'elapsed_millis': elapsedMillis,
    });
  }

  SourceChecksCompanion copyWith({
    Value<int>? id,
    Value<int>? sourceId,
    Value<DateTime>? checkedAt,
    Value<String>? status,
    Value<String?>? invalidGroups,
    Value<String?>? errorComment,
    Value<int>? elapsedMillis,
  }) {
    return SourceChecksCompanion(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      checkedAt: checkedAt ?? this.checkedAt,
      status: status ?? this.status,
      invalidGroups: invalidGroups ?? this.invalidGroups,
      errorComment: errorComment ?? this.errorComment,
      elapsedMillis: elapsedMillis ?? this.elapsedMillis,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<int>(sourceId.value);
    }
    if (checkedAt.present) {
      map['checked_at'] = Variable<DateTime>(checkedAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (invalidGroups.present) {
      map['invalid_groups'] = Variable<String>(invalidGroups.value);
    }
    if (errorComment.present) {
      map['error_comment'] = Variable<String>(errorComment.value);
    }
    if (elapsedMillis.present) {
      map['elapsed_millis'] = Variable<int>(elapsedMillis.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SourceChecksCompanion(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('checkedAt: $checkedAt, ')
          ..write('status: $status, ')
          ..write('invalidGroups: $invalidGroups, ')
          ..write('errorComment: $errorComment, ')
          ..write('elapsedMillis: $elapsedMillis')
          ..write(')'))
        .toString();
  }
}

class $BookGroupsTable extends BookGroups
    with TableInfo<$BookGroupsTable, BookGroupRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookGroupsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, sortOrder, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'book_groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookGroupRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {name},
  ];
  @override
  BookGroupRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookGroupRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $BookGroupsTable createAlias(String alias) {
    return $BookGroupsTable(attachedDatabase, alias);
  }
}

class BookGroupRow extends DataClass implements Insertable<BookGroupRow> {
  /// Synthetic primary key.
  final int id;

  /// The name shown in the filter chips and the management page; unique.
  final String name;

  /// Normalized `0..n-1` position written by the management page's reordering.
  final int sortOrder;

  /// When the group was created.
  final DateTime createdAt;
  const BookGroupRow({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  BookGroupsCompanion toCompanion(bool nullToAbsent) {
    return BookGroupsCompanion(
      id: Value(id),
      name: Value(name),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
    );
  }

  factory BookGroupRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookGroupRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  BookGroupRow copyWith({
    int? id,
    String? name,
    int? sortOrder,
    DateTime? createdAt,
  }) => BookGroupRow(
    id: id ?? this.id,
    name: name ?? this.name,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
  );
  BookGroupRow copyWithCompanion(BookGroupsCompanion data) {
    return BookGroupRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookGroupRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, sortOrder, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookGroupRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt);
}

class BookGroupsCompanion extends UpdateCompanion<BookGroupRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  const BookGroupsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  BookGroupsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.sortOrder = const Value.absent(),
    required DateTime createdAt,
  }) : name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<BookGroupRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  BookGroupsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
  }) {
    return BookGroupsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookGroupsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $BookmarksTable extends Bookmarks
    with TableInfo<$BookmarksTable, BookmarkRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookmarksTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _bookNameMeta = const VerificationMeta(
    'bookName',
  );
  @override
  late final GeneratedColumn<String> bookName = GeneratedColumn<String>(
    'book_name',
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
  static const VerificationMeta _chapterIndexMeta = const VerificationMeta(
    'chapterIndex',
  );
  @override
  late final GeneratedColumn<int> chapterIndex = GeneratedColumn<int>(
    'chapter_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
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
  static const VerificationMeta _excerptMeta = const VerificationMeta(
    'excerpt',
  );
  @override
  late final GeneratedColumn<String> excerpt = GeneratedColumn<String>(
    'excerpt',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
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
    bookName,
    tocUrl,
    chapterUrl,
    chapterName,
    chapterIndex,
    charOffset,
    excerpt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bookmarks';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookmarkRow> instance, {
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
    if (data.containsKey('book_name')) {
      context.handle(
        _bookNameMeta,
        bookName.isAcceptableOrUnknown(data['book_name']!, _bookNameMeta),
      );
    } else if (isInserting) {
      context.missing(_bookNameMeta);
    }
    if (data.containsKey('toc_url')) {
      context.handle(
        _tocUrlMeta,
        tocUrl.isAcceptableOrUnknown(data['toc_url']!, _tocUrlMeta),
      );
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
    if (data.containsKey('chapter_index')) {
      context.handle(
        _chapterIndexMeta,
        chapterIndex.isAcceptableOrUnknown(
          data['chapter_index']!,
          _chapterIndexMeta,
        ),
      );
    }
    if (data.containsKey('char_offset')) {
      context.handle(
        _charOffsetMeta,
        charOffset.isAcceptableOrUnknown(data['char_offset']!, _charOffsetMeta),
      );
    }
    if (data.containsKey('excerpt')) {
      context.handle(
        _excerptMeta,
        excerpt.isAcceptableOrUnknown(data['excerpt']!, _excerptMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {sourceUrl, bookUrl, chapterUrl, charOffset},
  ];
  @override
  BookmarkRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookmarkRow(
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
      bookName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_name'],
      )!,
      tocUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}toc_url'],
      ),
      chapterUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapter_url'],
      )!,
      chapterName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapter_name'],
      ),
      chapterIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chapter_index'],
      )!,
      charOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}char_offset'],
      )!,
      excerpt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}excerpt'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $BookmarksTable createAlias(String alias) {
    return $BookmarksTable(attachedDatabase, alias);
  }
}

class BookmarkRow extends DataClass implements Insertable<BookmarkRow> {
  /// Synthetic primary key.
  final int id;

  /// `bookSourceUrl` of the source the book came from.
  final String sourceUrl;

  /// The book's detail page URL — the book's identity inside one source.
  final String bookUrl;

  /// The book title as it was when the mark was made.
  final String bookName;

  /// The table-of-contents URL the reader was opened with, when it had one.
  final String? tocUrl;

  /// The chapter the mark points into.
  final String chapterUrl;

  /// The chapter title as it was when the mark was made, when the list knew it.
  final String? chapterName;

  /// Index of the chapter in the table of contents at the time of the write.
  ///
  /// Stale after renumbering; opening a mark falls back to it after [chapterUrl].
  final int chapterIndex;

  /// Character offset inside the chapter body.
  final int charOffset;

  /// Up to 80 characters of the body around the position, for the list.
  final String? excerpt;

  /// When the mark was made.
  final DateTime createdAt;
  const BookmarkRow({
    required this.id,
    required this.sourceUrl,
    required this.bookUrl,
    required this.bookName,
    this.tocUrl,
    required this.chapterUrl,
    this.chapterName,
    required this.chapterIndex,
    required this.charOffset,
    this.excerpt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['source_url'] = Variable<String>(sourceUrl);
    map['book_url'] = Variable<String>(bookUrl);
    map['book_name'] = Variable<String>(bookName);
    if (!nullToAbsent || tocUrl != null) {
      map['toc_url'] = Variable<String>(tocUrl);
    }
    map['chapter_url'] = Variable<String>(chapterUrl);
    if (!nullToAbsent || chapterName != null) {
      map['chapter_name'] = Variable<String>(chapterName);
    }
    map['chapter_index'] = Variable<int>(chapterIndex);
    map['char_offset'] = Variable<int>(charOffset);
    if (!nullToAbsent || excerpt != null) {
      map['excerpt'] = Variable<String>(excerpt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  BookmarksCompanion toCompanion(bool nullToAbsent) {
    return BookmarksCompanion(
      id: Value(id),
      sourceUrl: Value(sourceUrl),
      bookUrl: Value(bookUrl),
      bookName: Value(bookName),
      tocUrl: tocUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(tocUrl),
      chapterUrl: Value(chapterUrl),
      chapterName: chapterName == null && nullToAbsent
          ? const Value.absent()
          : Value(chapterName),
      chapterIndex: Value(chapterIndex),
      charOffset: Value(charOffset),
      excerpt: excerpt == null && nullToAbsent
          ? const Value.absent()
          : Value(excerpt),
      createdAt: Value(createdAt),
    );
  }

  factory BookmarkRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookmarkRow(
      id: serializer.fromJson<int>(json['id']),
      sourceUrl: serializer.fromJson<String>(json['sourceUrl']),
      bookUrl: serializer.fromJson<String>(json['bookUrl']),
      bookName: serializer.fromJson<String>(json['bookName']),
      tocUrl: serializer.fromJson<String?>(json['tocUrl']),
      chapterUrl: serializer.fromJson<String>(json['chapterUrl']),
      chapterName: serializer.fromJson<String?>(json['chapterName']),
      chapterIndex: serializer.fromJson<int>(json['chapterIndex']),
      charOffset: serializer.fromJson<int>(json['charOffset']),
      excerpt: serializer.fromJson<String?>(json['excerpt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sourceUrl': serializer.toJson<String>(sourceUrl),
      'bookUrl': serializer.toJson<String>(bookUrl),
      'bookName': serializer.toJson<String>(bookName),
      'tocUrl': serializer.toJson<String?>(tocUrl),
      'chapterUrl': serializer.toJson<String>(chapterUrl),
      'chapterName': serializer.toJson<String?>(chapterName),
      'chapterIndex': serializer.toJson<int>(chapterIndex),
      'charOffset': serializer.toJson<int>(charOffset),
      'excerpt': serializer.toJson<String?>(excerpt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  BookmarkRow copyWith({
    int? id,
    String? sourceUrl,
    String? bookUrl,
    String? bookName,
    Value<String?> tocUrl = const Value.absent(),
    String? chapterUrl,
    Value<String?> chapterName = const Value.absent(),
    int? chapterIndex,
    int? charOffset,
    Value<String?> excerpt = const Value.absent(),
    DateTime? createdAt,
  }) => BookmarkRow(
    id: id ?? this.id,
    sourceUrl: sourceUrl ?? this.sourceUrl,
    bookUrl: bookUrl ?? this.bookUrl,
    bookName: bookName ?? this.bookName,
    tocUrl: tocUrl.present ? tocUrl.value : this.tocUrl,
    chapterUrl: chapterUrl ?? this.chapterUrl,
    chapterName: chapterName.present ? chapterName.value : this.chapterName,
    chapterIndex: chapterIndex ?? this.chapterIndex,
    charOffset: charOffset ?? this.charOffset,
    excerpt: excerpt.present ? excerpt.value : this.excerpt,
    createdAt: createdAt ?? this.createdAt,
  );
  BookmarkRow copyWithCompanion(BookmarksCompanion data) {
    return BookmarkRow(
      id: data.id.present ? data.id.value : this.id,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      bookUrl: data.bookUrl.present ? data.bookUrl.value : this.bookUrl,
      bookName: data.bookName.present ? data.bookName.value : this.bookName,
      tocUrl: data.tocUrl.present ? data.tocUrl.value : this.tocUrl,
      chapterUrl: data.chapterUrl.present
          ? data.chapterUrl.value
          : this.chapterUrl,
      chapterName: data.chapterName.present
          ? data.chapterName.value
          : this.chapterName,
      chapterIndex: data.chapterIndex.present
          ? data.chapterIndex.value
          : this.chapterIndex,
      charOffset: data.charOffset.present
          ? data.charOffset.value
          : this.charOffset,
      excerpt: data.excerpt.present ? data.excerpt.value : this.excerpt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookmarkRow(')
          ..write('id: $id, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('bookUrl: $bookUrl, ')
          ..write('bookName: $bookName, ')
          ..write('tocUrl: $tocUrl, ')
          ..write('chapterUrl: $chapterUrl, ')
          ..write('chapterName: $chapterName, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('charOffset: $charOffset, ')
          ..write('excerpt: $excerpt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sourceUrl,
    bookUrl,
    bookName,
    tocUrl,
    chapterUrl,
    chapterName,
    chapterIndex,
    charOffset,
    excerpt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookmarkRow &&
          other.id == this.id &&
          other.sourceUrl == this.sourceUrl &&
          other.bookUrl == this.bookUrl &&
          other.bookName == this.bookName &&
          other.tocUrl == this.tocUrl &&
          other.chapterUrl == this.chapterUrl &&
          other.chapterName == this.chapterName &&
          other.chapterIndex == this.chapterIndex &&
          other.charOffset == this.charOffset &&
          other.excerpt == this.excerpt &&
          other.createdAt == this.createdAt);
}

class BookmarksCompanion extends UpdateCompanion<BookmarkRow> {
  final Value<int> id;
  final Value<String> sourceUrl;
  final Value<String> bookUrl;
  final Value<String> bookName;
  final Value<String?> tocUrl;
  final Value<String> chapterUrl;
  final Value<String?> chapterName;
  final Value<int> chapterIndex;
  final Value<int> charOffset;
  final Value<String?> excerpt;
  final Value<DateTime> createdAt;
  const BookmarksCompanion({
    this.id = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.bookUrl = const Value.absent(),
    this.bookName = const Value.absent(),
    this.tocUrl = const Value.absent(),
    this.chapterUrl = const Value.absent(),
    this.chapterName = const Value.absent(),
    this.chapterIndex = const Value.absent(),
    this.charOffset = const Value.absent(),
    this.excerpt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  BookmarksCompanion.insert({
    this.id = const Value.absent(),
    required String sourceUrl,
    required String bookUrl,
    required String bookName,
    this.tocUrl = const Value.absent(),
    required String chapterUrl,
    this.chapterName = const Value.absent(),
    this.chapterIndex = const Value.absent(),
    this.charOffset = const Value.absent(),
    this.excerpt = const Value.absent(),
    required DateTime createdAt,
  }) : sourceUrl = Value(sourceUrl),
       bookUrl = Value(bookUrl),
       bookName = Value(bookName),
       chapterUrl = Value(chapterUrl),
       createdAt = Value(createdAt);
  static Insertable<BookmarkRow> custom({
    Expression<int>? id,
    Expression<String>? sourceUrl,
    Expression<String>? bookUrl,
    Expression<String>? bookName,
    Expression<String>? tocUrl,
    Expression<String>? chapterUrl,
    Expression<String>? chapterName,
    Expression<int>? chapterIndex,
    Expression<int>? charOffset,
    Expression<String>? excerpt,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (bookUrl != null) 'book_url': bookUrl,
      if (bookName != null) 'book_name': bookName,
      if (tocUrl != null) 'toc_url': tocUrl,
      if (chapterUrl != null) 'chapter_url': chapterUrl,
      if (chapterName != null) 'chapter_name': chapterName,
      if (chapterIndex != null) 'chapter_index': chapterIndex,
      if (charOffset != null) 'char_offset': charOffset,
      if (excerpt != null) 'excerpt': excerpt,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  BookmarksCompanion copyWith({
    Value<int>? id,
    Value<String>? sourceUrl,
    Value<String>? bookUrl,
    Value<String>? bookName,
    Value<String?>? tocUrl,
    Value<String>? chapterUrl,
    Value<String?>? chapterName,
    Value<int>? chapterIndex,
    Value<int>? charOffset,
    Value<String?>? excerpt,
    Value<DateTime>? createdAt,
  }) {
    return BookmarksCompanion(
      id: id ?? this.id,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      bookUrl: bookUrl ?? this.bookUrl,
      bookName: bookName ?? this.bookName,
      tocUrl: tocUrl ?? this.tocUrl,
      chapterUrl: chapterUrl ?? this.chapterUrl,
      chapterName: chapterName ?? this.chapterName,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      charOffset: charOffset ?? this.charOffset,
      excerpt: excerpt ?? this.excerpt,
      createdAt: createdAt ?? this.createdAt,
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
    if (bookName.present) {
      map['book_name'] = Variable<String>(bookName.value);
    }
    if (tocUrl.present) {
      map['toc_url'] = Variable<String>(tocUrl.value);
    }
    if (chapterUrl.present) {
      map['chapter_url'] = Variable<String>(chapterUrl.value);
    }
    if (chapterName.present) {
      map['chapter_name'] = Variable<String>(chapterName.value);
    }
    if (chapterIndex.present) {
      map['chapter_index'] = Variable<int>(chapterIndex.value);
    }
    if (charOffset.present) {
      map['char_offset'] = Variable<int>(charOffset.value);
    }
    if (excerpt.present) {
      map['excerpt'] = Variable<String>(excerpt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookmarksCompanion(')
          ..write('id: $id, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('bookUrl: $bookUrl, ')
          ..write('bookName: $bookName, ')
          ..write('tocUrl: $tocUrl, ')
          ..write('chapterUrl: $chapterUrl, ')
          ..write('chapterName: $chapterName, ')
          ..write('chapterIndex: $chapterIndex, ')
          ..write('charOffset: $charOffset, ')
          ..write('excerpt: $excerpt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $ReadRecordsTable extends ReadRecords
    with TableInfo<$ReadRecordsTable, ReadRecordRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadRecordsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _bookNameMeta = const VerificationMeta(
    'bookName',
  );
  @override
  late final GeneratedColumn<String> bookName = GeneratedColumn<String>(
    'book_name',
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
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourceUrl,
    bookUrl,
    bookName,
    chapterUrl,
    chapterName,
    startedAt,
    endedAt,
    durationSeconds,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'read_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReadRecordRow> instance, {
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
    if (data.containsKey('book_name')) {
      context.handle(
        _bookNameMeta,
        bookName.isAcceptableOrUnknown(data['book_name']!, _bookNameMeta),
      );
    } else if (isInserting) {
      context.missing(_bookNameMeta);
    }
    if (data.containsKey('chapter_url')) {
      context.handle(
        _chapterUrlMeta,
        chapterUrl.isAcceptableOrUnknown(data['chapter_url']!, _chapterUrlMeta),
      );
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
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_endedAtMeta);
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_durationSecondsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReadRecordRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadRecordRow(
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
      bookName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_name'],
      )!,
      chapterUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapter_url'],
      ),
      chapterName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapter_name'],
      ),
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      )!,
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_seconds'],
      )!,
    );
  }

  @override
  $ReadRecordsTable createAlias(String alias) {
    return $ReadRecordsTable(attachedDatabase, alias);
  }
}

class ReadRecordRow extends DataClass implements Insertable<ReadRecordRow> {
  /// Synthetic primary key; the history is append-only.
  final int id;

  /// `bookSourceUrl` of the source the book came from.
  final String sourceUrl;

  /// The book's detail page URL.
  final String bookUrl;

  /// The book title as it was when the session ended.
  final String bookName;

  /// The chapter the session ended on; `null` when the list never loaded.
  final String? chapterUrl;

  /// The chapter title the session ended on, when known.
  final String? chapterName;

  /// When the reader was opened.
  final DateTime startedAt;

  /// When the reader was closed; the day view groups by this instant's local date.
  final DateTime endedAt;

  /// Wall-clock length of the session, which is what the day view sums.
  final int durationSeconds;
  const ReadRecordRow({
    required this.id,
    required this.sourceUrl,
    required this.bookUrl,
    required this.bookName,
    this.chapterUrl,
    this.chapterName,
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['source_url'] = Variable<String>(sourceUrl);
    map['book_url'] = Variable<String>(bookUrl);
    map['book_name'] = Variable<String>(bookName);
    if (!nullToAbsent || chapterUrl != null) {
      map['chapter_url'] = Variable<String>(chapterUrl);
    }
    if (!nullToAbsent || chapterName != null) {
      map['chapter_name'] = Variable<String>(chapterName);
    }
    map['started_at'] = Variable<DateTime>(startedAt);
    map['ended_at'] = Variable<DateTime>(endedAt);
    map['duration_seconds'] = Variable<int>(durationSeconds);
    return map;
  }

  ReadRecordsCompanion toCompanion(bool nullToAbsent) {
    return ReadRecordsCompanion(
      id: Value(id),
      sourceUrl: Value(sourceUrl),
      bookUrl: Value(bookUrl),
      bookName: Value(bookName),
      chapterUrl: chapterUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(chapterUrl),
      chapterName: chapterName == null && nullToAbsent
          ? const Value.absent()
          : Value(chapterName),
      startedAt: Value(startedAt),
      endedAt: Value(endedAt),
      durationSeconds: Value(durationSeconds),
    );
  }

  factory ReadRecordRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadRecordRow(
      id: serializer.fromJson<int>(json['id']),
      sourceUrl: serializer.fromJson<String>(json['sourceUrl']),
      bookUrl: serializer.fromJson<String>(json['bookUrl']),
      bookName: serializer.fromJson<String>(json['bookName']),
      chapterUrl: serializer.fromJson<String?>(json['chapterUrl']),
      chapterName: serializer.fromJson<String?>(json['chapterName']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime>(json['endedAt']),
      durationSeconds: serializer.fromJson<int>(json['durationSeconds']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sourceUrl': serializer.toJson<String>(sourceUrl),
      'bookUrl': serializer.toJson<String>(bookUrl),
      'bookName': serializer.toJson<String>(bookName),
      'chapterUrl': serializer.toJson<String?>(chapterUrl),
      'chapterName': serializer.toJson<String?>(chapterName),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime>(endedAt),
      'durationSeconds': serializer.toJson<int>(durationSeconds),
    };
  }

  ReadRecordRow copyWith({
    int? id,
    String? sourceUrl,
    String? bookUrl,
    String? bookName,
    Value<String?> chapterUrl = const Value.absent(),
    Value<String?> chapterName = const Value.absent(),
    DateTime? startedAt,
    DateTime? endedAt,
    int? durationSeconds,
  }) => ReadRecordRow(
    id: id ?? this.id,
    sourceUrl: sourceUrl ?? this.sourceUrl,
    bookUrl: bookUrl ?? this.bookUrl,
    bookName: bookName ?? this.bookName,
    chapterUrl: chapterUrl.present ? chapterUrl.value : this.chapterUrl,
    chapterName: chapterName.present ? chapterName.value : this.chapterName,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt ?? this.endedAt,
    durationSeconds: durationSeconds ?? this.durationSeconds,
  );
  ReadRecordRow copyWithCompanion(ReadRecordsCompanion data) {
    return ReadRecordRow(
      id: data.id.present ? data.id.value : this.id,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      bookUrl: data.bookUrl.present ? data.bookUrl.value : this.bookUrl,
      bookName: data.bookName.present ? data.bookName.value : this.bookName,
      chapterUrl: data.chapterUrl.present
          ? data.chapterUrl.value
          : this.chapterUrl,
      chapterName: data.chapterName.present
          ? data.chapterName.value
          : this.chapterName,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadRecordRow(')
          ..write('id: $id, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('bookUrl: $bookUrl, ')
          ..write('bookName: $bookName, ')
          ..write('chapterUrl: $chapterUrl, ')
          ..write('chapterName: $chapterName, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('durationSeconds: $durationSeconds')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sourceUrl,
    bookUrl,
    bookName,
    chapterUrl,
    chapterName,
    startedAt,
    endedAt,
    durationSeconds,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadRecordRow &&
          other.id == this.id &&
          other.sourceUrl == this.sourceUrl &&
          other.bookUrl == this.bookUrl &&
          other.bookName == this.bookName &&
          other.chapterUrl == this.chapterUrl &&
          other.chapterName == this.chapterName &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.durationSeconds == this.durationSeconds);
}

class ReadRecordsCompanion extends UpdateCompanion<ReadRecordRow> {
  final Value<int> id;
  final Value<String> sourceUrl;
  final Value<String> bookUrl;
  final Value<String> bookName;
  final Value<String?> chapterUrl;
  final Value<String?> chapterName;
  final Value<DateTime> startedAt;
  final Value<DateTime> endedAt;
  final Value<int> durationSeconds;
  const ReadRecordsCompanion({
    this.id = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.bookUrl = const Value.absent(),
    this.bookName = const Value.absent(),
    this.chapterUrl = const Value.absent(),
    this.chapterName = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.durationSeconds = const Value.absent(),
  });
  ReadRecordsCompanion.insert({
    this.id = const Value.absent(),
    required String sourceUrl,
    required String bookUrl,
    required String bookName,
    this.chapterUrl = const Value.absent(),
    this.chapterName = const Value.absent(),
    required DateTime startedAt,
    required DateTime endedAt,
    required int durationSeconds,
  }) : sourceUrl = Value(sourceUrl),
       bookUrl = Value(bookUrl),
       bookName = Value(bookName),
       startedAt = Value(startedAt),
       endedAt = Value(endedAt),
       durationSeconds = Value(durationSeconds);
  static Insertable<ReadRecordRow> custom({
    Expression<int>? id,
    Expression<String>? sourceUrl,
    Expression<String>? bookUrl,
    Expression<String>? bookName,
    Expression<String>? chapterUrl,
    Expression<String>? chapterName,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<int>? durationSeconds,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (bookUrl != null) 'book_url': bookUrl,
      if (bookName != null) 'book_name': bookName,
      if (chapterUrl != null) 'chapter_url': chapterUrl,
      if (chapterName != null) 'chapter_name': chapterName,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
    });
  }

  ReadRecordsCompanion copyWith({
    Value<int>? id,
    Value<String>? sourceUrl,
    Value<String>? bookUrl,
    Value<String>? bookName,
    Value<String?>? chapterUrl,
    Value<String?>? chapterName,
    Value<DateTime>? startedAt,
    Value<DateTime>? endedAt,
    Value<int>? durationSeconds,
  }) {
    return ReadRecordsCompanion(
      id: id ?? this.id,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      bookUrl: bookUrl ?? this.bookUrl,
      bookName: bookName ?? this.bookName,
      chapterUrl: chapterUrl ?? this.chapterUrl,
      chapterName: chapterName ?? this.chapterName,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
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
    if (bookName.present) {
      map['book_name'] = Variable<String>(bookName.value);
    }
    if (chapterUrl.present) {
      map['chapter_url'] = Variable<String>(chapterUrl.value);
    }
    if (chapterName.present) {
      map['chapter_name'] = Variable<String>(chapterName.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadRecordsCompanion(')
          ..write('id: $id, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('bookUrl: $bookUrl, ')
          ..write('bookName: $bookName, ')
          ..write('chapterUrl: $chapterUrl, ')
          ..write('chapterName: $chapterName, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('durationSeconds: $durationSeconds')
          ..write(')'))
        .toString();
  }
}

class $CookiesTable extends Cookies with TableInfo<$CookiesTable, CookieRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CookiesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _domainMeta = const VerificationMeta('domain');
  @override
  late final GeneratedColumn<String> domain = GeneratedColumn<String>(
    'domain',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
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
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isSecureMeta = const VerificationMeta(
    'isSecure',
  );
  @override
  late final GeneratedColumn<bool> isSecure = GeneratedColumn<bool>(
    'is_secure',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_secure" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    domain,
    path,
    name,
    value,
    isSecure,
    expiresAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cookies';
  @override
  VerificationContext validateIntegrity(
    Insertable<CookieRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('domain')) {
      context.handle(
        _domainMeta,
        domain.isAcceptableOrUnknown(data['domain']!, _domainMeta),
      );
    } else if (isInserting) {
      context.missing(_domainMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('is_secure')) {
      context.handle(
        _isSecureMeta,
        isSecure.isAcceptableOrUnknown(data['is_secure']!, _isSecureMeta),
      );
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {domain, path, name},
  ];
  @override
  CookieRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CookieRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      domain: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}domain'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      isSecure: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_secure'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $CookiesTable createAlias(String alias) {
    return $CookiesTable(attachedDatabase, alias);
  }
}

class CookieRow extends DataClass implements Insertable<CookieRow> {
  /// Synthetic primary key.
  final int id;

  /// Cookie domain (no leading dot), as RFC 6265 normalizes it.
  final String domain;

  /// Cookie path, `/` when the server said nothing.
  final String path;

  /// Cookie name.
  final String name;

  /// Cookie value.
  final String value;

  /// Whether the cookie may only travel over HTTPS.
  final bool isSecure;

  /// When the cookie stops being valid, or `null` for a session cookie.
  final DateTime? expiresAt;

  /// When the row was written; a diagnostic column, not a cookie attribute.
  final DateTime createdAt;
  const CookieRow({
    required this.id,
    required this.domain,
    required this.path,
    required this.name,
    required this.value,
    required this.isSecure,
    this.expiresAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['domain'] = Variable<String>(domain);
    map['path'] = Variable<String>(path);
    map['name'] = Variable<String>(name);
    map['value'] = Variable<String>(value);
    map['is_secure'] = Variable<bool>(isSecure);
    if (!nullToAbsent || expiresAt != null) {
      map['expires_at'] = Variable<DateTime>(expiresAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CookiesCompanion toCompanion(bool nullToAbsent) {
    return CookiesCompanion(
      id: Value(id),
      domain: Value(domain),
      path: Value(path),
      name: Value(name),
      value: Value(value),
      isSecure: Value(isSecure),
      expiresAt: expiresAt == null && nullToAbsent
          ? const Value.absent()
          : Value(expiresAt),
      createdAt: Value(createdAt),
    );
  }

  factory CookieRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CookieRow(
      id: serializer.fromJson<int>(json['id']),
      domain: serializer.fromJson<String>(json['domain']),
      path: serializer.fromJson<String>(json['path']),
      name: serializer.fromJson<String>(json['name']),
      value: serializer.fromJson<String>(json['value']),
      isSecure: serializer.fromJson<bool>(json['isSecure']),
      expiresAt: serializer.fromJson<DateTime?>(json['expiresAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'domain': serializer.toJson<String>(domain),
      'path': serializer.toJson<String>(path),
      'name': serializer.toJson<String>(name),
      'value': serializer.toJson<String>(value),
      'isSecure': serializer.toJson<bool>(isSecure),
      'expiresAt': serializer.toJson<DateTime?>(expiresAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  CookieRow copyWith({
    int? id,
    String? domain,
    String? path,
    String? name,
    String? value,
    bool? isSecure,
    Value<DateTime?> expiresAt = const Value.absent(),
    DateTime? createdAt,
  }) => CookieRow(
    id: id ?? this.id,
    domain: domain ?? this.domain,
    path: path ?? this.path,
    name: name ?? this.name,
    value: value ?? this.value,
    isSecure: isSecure ?? this.isSecure,
    expiresAt: expiresAt.present ? expiresAt.value : this.expiresAt,
    createdAt: createdAt ?? this.createdAt,
  );
  CookieRow copyWithCompanion(CookiesCompanion data) {
    return CookieRow(
      id: data.id.present ? data.id.value : this.id,
      domain: data.domain.present ? data.domain.value : this.domain,
      path: data.path.present ? data.path.value : this.path,
      name: data.name.present ? data.name.value : this.name,
      value: data.value.present ? data.value.value : this.value,
      isSecure: data.isSecure.present ? data.isSecure.value : this.isSecure,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CookieRow(')
          ..write('id: $id, ')
          ..write('domain: $domain, ')
          ..write('path: $path, ')
          ..write('name: $name, ')
          ..write('value: $value, ')
          ..write('isSecure: $isSecure, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    domain,
    path,
    name,
    value,
    isSecure,
    expiresAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CookieRow &&
          other.id == this.id &&
          other.domain == this.domain &&
          other.path == this.path &&
          other.name == this.name &&
          other.value == this.value &&
          other.isSecure == this.isSecure &&
          other.expiresAt == this.expiresAt &&
          other.createdAt == this.createdAt);
}

class CookiesCompanion extends UpdateCompanion<CookieRow> {
  final Value<int> id;
  final Value<String> domain;
  final Value<String> path;
  final Value<String> name;
  final Value<String> value;
  final Value<bool> isSecure;
  final Value<DateTime?> expiresAt;
  final Value<DateTime> createdAt;
  const CookiesCompanion({
    this.id = const Value.absent(),
    this.domain = const Value.absent(),
    this.path = const Value.absent(),
    this.name = const Value.absent(),
    this.value = const Value.absent(),
    this.isSecure = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  CookiesCompanion.insert({
    this.id = const Value.absent(),
    required String domain,
    required String path,
    required String name,
    required String value,
    this.isSecure = const Value.absent(),
    this.expiresAt = const Value.absent(),
    required DateTime createdAt,
  }) : domain = Value(domain),
       path = Value(path),
       name = Value(name),
       value = Value(value),
       createdAt = Value(createdAt);
  static Insertable<CookieRow> custom({
    Expression<int>? id,
    Expression<String>? domain,
    Expression<String>? path,
    Expression<String>? name,
    Expression<String>? value,
    Expression<bool>? isSecure,
    Expression<DateTime>? expiresAt,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (domain != null) 'domain': domain,
      if (path != null) 'path': path,
      if (name != null) 'name': name,
      if (value != null) 'value': value,
      if (isSecure != null) 'is_secure': isSecure,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  CookiesCompanion copyWith({
    Value<int>? id,
    Value<String>? domain,
    Value<String>? path,
    Value<String>? name,
    Value<String>? value,
    Value<bool>? isSecure,
    Value<DateTime?>? expiresAt,
    Value<DateTime>? createdAt,
  }) {
    return CookiesCompanion(
      id: id ?? this.id,
      domain: domain ?? this.domain,
      path: path ?? this.path,
      name: name ?? this.name,
      value: value ?? this.value,
      isSecure: isSecure ?? this.isSecure,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (domain.present) {
      map['domain'] = Variable<String>(domain.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (isSecure.present) {
      map['is_secure'] = Variable<bool>(isSecure.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CookiesCompanion(')
          ..write('id: $id, ')
          ..write('domain: $domain, ')
          ..write('path: $path, ')
          ..write('name: $name, ')
          ..write('value: $value, ')
          ..write('isSecure: $isSecure, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $RulesTable extends Rules with TableInfo<$RulesTable, RuleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RulesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
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
  static const VerificationMeta _isBuiltInMeta = const VerificationMeta(
    'isBuiltIn',
  );
  @override
  late final GeneratedColumn<bool> isBuiltIn = GeneratedColumn<bool>(
    'is_built_in',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_built_in" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    name,
    payload,
    isEnabled,
    isBuiltIn,
    sortOrder,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rules';
  @override
  VerificationContext validateIntegrity(
    Insertable<RuleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('is_enabled')) {
      context.handle(
        _isEnabledMeta,
        isEnabled.isAcceptableOrUnknown(data['is_enabled']!, _isEnabledMeta),
      );
    }
    if (data.containsKey('is_built_in')) {
      context.handle(
        _isBuiltInMeta,
        isBuiltIn.isAcceptableOrUnknown(data['is_built_in']!, _isBuiltInMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RuleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RuleRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      isEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_enabled'],
      )!,
      isBuiltIn: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_built_in'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $RulesTable createAlias(String alias) {
    return $RulesTable(attachedDatabase, alias);
  }
}

class RuleRow extends DataClass implements Insertable<RuleRow> {
  /// Synthetic primary key.
  final int id;

  /// Which feature owns the row: `replace` / `toc` / `dict` / `highlight`.
  final String kind;

  /// The display name (a purge rule's name, a dictionary's name, a tag's name).
  final String name;

  /// The kind-specific fields as JSON (see ADR-0070 §决策 1 for each kind's keys).
  final String payload;

  /// Whether the rule takes effect.
  final bool isEnabled;

  /// Whether the row came with the app; it is still editable and deletable.
  final bool isBuiltIn;

  /// Manual order inside one [kind]; smaller runs first.
  final int sortOrder;

  /// When the row was created (used to keep inserts in a stable order).
  final DateTime createdAt;
  const RuleRow({
    required this.id,
    required this.kind,
    required this.name,
    required this.payload,
    required this.isEnabled,
    required this.isBuiltIn,
    required this.sortOrder,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['kind'] = Variable<String>(kind);
    map['name'] = Variable<String>(name);
    map['payload'] = Variable<String>(payload);
    map['is_enabled'] = Variable<bool>(isEnabled);
    map['is_built_in'] = Variable<bool>(isBuiltIn);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  RulesCompanion toCompanion(bool nullToAbsent) {
    return RulesCompanion(
      id: Value(id),
      kind: Value(kind),
      name: Value(name),
      payload: Value(payload),
      isEnabled: Value(isEnabled),
      isBuiltIn: Value(isBuiltIn),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
    );
  }

  factory RuleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RuleRow(
      id: serializer.fromJson<int>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      name: serializer.fromJson<String>(json['name']),
      payload: serializer.fromJson<String>(json['payload']),
      isEnabled: serializer.fromJson<bool>(json['isEnabled']),
      isBuiltIn: serializer.fromJson<bool>(json['isBuiltIn']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'kind': serializer.toJson<String>(kind),
      'name': serializer.toJson<String>(name),
      'payload': serializer.toJson<String>(payload),
      'isEnabled': serializer.toJson<bool>(isEnabled),
      'isBuiltIn': serializer.toJson<bool>(isBuiltIn),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  RuleRow copyWith({
    int? id,
    String? kind,
    String? name,
    String? payload,
    bool? isEnabled,
    bool? isBuiltIn,
    int? sortOrder,
    DateTime? createdAt,
  }) => RuleRow(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    name: name ?? this.name,
    payload: payload ?? this.payload,
    isEnabled: isEnabled ?? this.isEnabled,
    isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
  );
  RuleRow copyWithCompanion(RulesCompanion data) {
    return RuleRow(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      name: data.name.present ? data.name.value : this.name,
      payload: data.payload.present ? data.payload.value : this.payload,
      isEnabled: data.isEnabled.present ? data.isEnabled.value : this.isEnabled,
      isBuiltIn: data.isBuiltIn.present ? data.isBuiltIn.value : this.isBuiltIn,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RuleRow(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('payload: $payload, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('isBuiltIn: $isBuiltIn, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    name,
    payload,
    isEnabled,
    isBuiltIn,
    sortOrder,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RuleRow &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.name == this.name &&
          other.payload == this.payload &&
          other.isEnabled == this.isEnabled &&
          other.isBuiltIn == this.isBuiltIn &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt);
}

class RulesCompanion extends UpdateCompanion<RuleRow> {
  final Value<int> id;
  final Value<String> kind;
  final Value<String> name;
  final Value<String> payload;
  final Value<bool> isEnabled;
  final Value<bool> isBuiltIn;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  const RulesCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.name = const Value.absent(),
    this.payload = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.isBuiltIn = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  RulesCompanion.insert({
    this.id = const Value.absent(),
    required String kind,
    required String name,
    required String payload,
    this.isEnabled = const Value.absent(),
    this.isBuiltIn = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required DateTime createdAt,
  }) : kind = Value(kind),
       name = Value(name),
       payload = Value(payload),
       createdAt = Value(createdAt);
  static Insertable<RuleRow> custom({
    Expression<int>? id,
    Expression<String>? kind,
    Expression<String>? name,
    Expression<String>? payload,
    Expression<bool>? isEnabled,
    Expression<bool>? isBuiltIn,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (name != null) 'name': name,
      if (payload != null) 'payload': payload,
      if (isEnabled != null) 'is_enabled': isEnabled,
      if (isBuiltIn != null) 'is_built_in': isBuiltIn,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  RulesCompanion copyWith({
    Value<int>? id,
    Value<String>? kind,
    Value<String>? name,
    Value<String>? payload,
    Value<bool>? isEnabled,
    Value<bool>? isBuiltIn,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
  }) {
    return RulesCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      payload: payload ?? this.payload,
      isEnabled: isEnabled ?? this.isEnabled,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (isEnabled.present) {
      map['is_enabled'] = Variable<bool>(isEnabled.value);
    }
    if (isBuiltIn.present) {
      map['is_built_in'] = Variable<bool>(isBuiltIn.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RulesCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('payload: $payload, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('isBuiltIn: $isBuiltIn, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $SourceVariablesTable extends SourceVariables
    with TableInfo<$SourceVariablesTable, SourceVariableRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SourceVariablesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
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
  List<GeneratedColumn> get $columns => [sourceUrl, name, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'source_variables';
  @override
  VerificationContext validateIntegrity(
    Insertable<SourceVariableRow> instance, {
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
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
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
  Set<GeneratedColumn> get $primaryKey => {sourceUrl, name};
  @override
  SourceVariableRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SourceVariableRow(
      sourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_url'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SourceVariablesTable createAlias(String alias) {
    return $SourceVariablesTable(attachedDatabase, alias);
  }
}

class SourceVariableRow extends DataClass
    implements Insertable<SourceVariableRow> {
  /// `bookSourceUrl` of the source the variable belongs to.
  final String sourceUrl;

  /// The variable's name.
  final String name;

  /// The variable's value; upstream's map holds strings only.
  final String value;

  /// When the row was last written; a diagnostic column, not part of the value.
  final DateTime updatedAt;
  const SourceVariableRow({
    required this.sourceUrl,
    required this.name,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['source_url'] = Variable<String>(sourceUrl);
    map['name'] = Variable<String>(name);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SourceVariablesCompanion toCompanion(bool nullToAbsent) {
    return SourceVariablesCompanion(
      sourceUrl: Value(sourceUrl),
      name: Value(name),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory SourceVariableRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SourceVariableRow(
      sourceUrl: serializer.fromJson<String>(json['sourceUrl']),
      name: serializer.fromJson<String>(json['name']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sourceUrl': serializer.toJson<String>(sourceUrl),
      'name': serializer.toJson<String>(name),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SourceVariableRow copyWith({
    String? sourceUrl,
    String? name,
    String? value,
    DateTime? updatedAt,
  }) => SourceVariableRow(
    sourceUrl: sourceUrl ?? this.sourceUrl,
    name: name ?? this.name,
    value: value ?? this.value,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SourceVariableRow copyWithCompanion(SourceVariablesCompanion data) {
    return SourceVariableRow(
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      name: data.name.present ? data.name.value : this.name,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SourceVariableRow(')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('name: $name, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(sourceUrl, name, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SourceVariableRow &&
          other.sourceUrl == this.sourceUrl &&
          other.name == this.name &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class SourceVariablesCompanion extends UpdateCompanion<SourceVariableRow> {
  final Value<String> sourceUrl;
  final Value<String> name;
  final Value<String> value;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SourceVariablesCompanion({
    this.sourceUrl = const Value.absent(),
    this.name = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SourceVariablesCompanion.insert({
    required String sourceUrl,
    required String name,
    required String value,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : sourceUrl = Value(sourceUrl),
       name = Value(name),
       value = Value(value),
       updatedAt = Value(updatedAt);
  static Insertable<SourceVariableRow> custom({
    Expression<String>? sourceUrl,
    Expression<String>? name,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (name != null) 'name': name,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SourceVariablesCompanion copyWith({
    Value<String>? sourceUrl,
    Value<String>? name,
    Value<String>? value,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SourceVariablesCompanion(
      sourceUrl: sourceUrl ?? this.sourceUrl,
      name: name ?? this.name,
      value: value ?? this.value,
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
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
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
    return (StringBuffer('SourceVariablesCompanion(')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('name: $name, ')
          ..write('value: $value, ')
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
  late final $SourceChecksTable sourceChecks = $SourceChecksTable(this);
  late final $BookGroupsTable bookGroups = $BookGroupsTable(this);
  late final $BookmarksTable bookmarks = $BookmarksTable(this);
  late final $ReadRecordsTable readRecords = $ReadRecordsTable(this);
  late final $CookiesTable cookies = $CookiesTable(this);
  late final $RulesTable rules = $RulesTable(this);
  late final $SourceVariablesTable sourceVariables = $SourceVariablesTable(
    this,
  );
  late final Index cacheEntriesSource = Index(
    'cache_entries_source',
    'CREATE INDEX cache_entries_source ON cache_entries (source_key)',
  );
  late final Index sourceChecksSourceChecked = Index(
    'source_checks_source_checked',
    'CREATE INDEX source_checks_source_checked ON source_checks (source_id, checked_at)',
  );
  late final Index bookmarksBook = Index(
    'bookmarks_book',
    'CREATE INDEX bookmarks_book ON bookmarks (book_url)',
  );
  late final Index readRecordsBook = Index(
    'read_records_book',
    'CREATE INDEX read_records_book ON read_records (book_url, ended_at)',
  );
  late final Index readRecordsEnded = Index(
    'read_records_ended',
    'CREATE INDEX read_records_ended ON read_records (ended_at)',
  );
  late final Index cookiesDomain = Index(
    'cookies_domain',
    'CREATE INDEX cookies_domain ON cookies (domain)',
  );
  late final Index rulesKindOrder = Index(
    'rules_kind_order',
    'CREATE INDEX rules_kind_order ON rules (kind, sort_order)',
  );
  late final Index sourceVariablesSource = Index(
    'source_variables_source',
    'CREATE INDEX source_variables_source ON source_variables (source_url)',
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
    sourceChecks,
    bookGroups,
    bookmarks,
    readRecords,
    cookies,
    rules,
    sourceVariables,
    cacheEntriesSource,
    sourceChecksSourceChecked,
    bookmarksBook,
    readRecordsBook,
    readRecordsEnded,
    cookiesDomain,
    rulesKindOrder,
    sourceVariablesSource,
  ];
}

typedef $$CacheEntriesTableCreateCompanionBuilder =
    CacheEntriesCompanion Function({
      required String cacheKey,
      required String payload,
      required DateTime expiresAt,
      Value<String?> scopeKey,
      Value<String?> sourceKey,
      Value<int> rowid,
    });
typedef $$CacheEntriesTableUpdateCompanionBuilder =
    CacheEntriesCompanion Function({
      Value<String> cacheKey,
      Value<String> payload,
      Value<DateTime> expiresAt,
      Value<String?> scopeKey,
      Value<String?> sourceKey,
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

  ColumnFilters<String> get scopeKey => $composableBuilder(
    column: $table.scopeKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceKey => $composableBuilder(
    column: $table.sourceKey,
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

  ColumnOrderings<String> get scopeKey => $composableBuilder(
    column: $table.scopeKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceKey => $composableBuilder(
    column: $table.sourceKey,
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

  GeneratedColumn<String> get scopeKey =>
      $composableBuilder(column: $table.scopeKey, builder: (column) => column);

  GeneratedColumn<String> get sourceKey =>
      $composableBuilder(column: $table.sourceKey, builder: (column) => column);
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
                Value<String?> scopeKey = const Value.absent(),
                Value<String?> sourceKey = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CacheEntriesCompanion(
                cacheKey: cacheKey,
                payload: payload,
                expiresAt: expiresAt,
                scopeKey: scopeKey,
                sourceKey: sourceKey,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String cacheKey,
                required String payload,
                required DateTime expiresAt,
                Value<String?> scopeKey = const Value.absent(),
                Value<String?> sourceKey = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CacheEntriesCompanion.insert(
                cacheKey: cacheKey,
                payload: payload,
                expiresAt: expiresAt,
                scopeKey: scopeKey,
                sourceKey: sourceKey,
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
      Value<bool> isExploreEnabled,
      Value<int> weight,
      Value<int?> lastUpdateTime,
      Value<int?> respondTime,
      Value<String?> loginInfo,
      Value<String?> loginHeader,
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
      Value<bool> isExploreEnabled,
      Value<int> weight,
      Value<int?> lastUpdateTime,
      Value<int?> respondTime,
      Value<String?> loginInfo,
      Value<String?> loginHeader,
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

  ColumnFilters<bool> get isExploreEnabled => $composableBuilder(
    column: $table.isExploreEnabled,
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

  ColumnFilters<String> get loginInfo => $composableBuilder(
    column: $table.loginInfo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get loginHeader => $composableBuilder(
    column: $table.loginHeader,
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

  ColumnOrderings<bool> get isExploreEnabled => $composableBuilder(
    column: $table.isExploreEnabled,
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

  ColumnOrderings<String> get loginInfo => $composableBuilder(
    column: $table.loginInfo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get loginHeader => $composableBuilder(
    column: $table.loginHeader,
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

  GeneratedColumn<bool> get isExploreEnabled => $composableBuilder(
    column: $table.isExploreEnabled,
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

  GeneratedColumn<String> get loginInfo =>
      $composableBuilder(column: $table.loginInfo, builder: (column) => column);

  GeneratedColumn<String> get loginHeader => $composableBuilder(
    column: $table.loginHeader,
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
                Value<bool> isExploreEnabled = const Value.absent(),
                Value<int> weight = const Value.absent(),
                Value<int?> lastUpdateTime = const Value.absent(),
                Value<int?> respondTime = const Value.absent(),
                Value<String?> loginInfo = const Value.absent(),
                Value<String?> loginHeader = const Value.absent(),
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
                isExploreEnabled: isExploreEnabled,
                weight: weight,
                lastUpdateTime: lastUpdateTime,
                respondTime: respondTime,
                loginInfo: loginInfo,
                loginHeader: loginHeader,
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
                Value<bool> isExploreEnabled = const Value.absent(),
                Value<int> weight = const Value.absent(),
                Value<int?> lastUpdateTime = const Value.absent(),
                Value<int?> respondTime = const Value.absent(),
                Value<String?> loginInfo = const Value.absent(),
                Value<String?> loginHeader = const Value.absent(),
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
                isExploreEnabled: isExploreEnabled,
                weight: weight,
                lastUpdateTime: lastUpdateTime,
                respondTime: respondTime,
                loginInfo: loginInfo,
                loginHeader: loginHeader,
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
  Value<int?> groupId,
  Value<String?> customCoverPath,
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
  Value<int?> groupId,
  Value<String?> customCoverPath,
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

  ColumnFilters<int> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customCoverPath => $composableBuilder(
    column: $table.customCoverPath,
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

  ColumnOrderings<int> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customCoverPath => $composableBuilder(
    column: $table.customCoverPath,
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

  GeneratedColumn<int> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get customCoverPath => $composableBuilder(
    column: $table.customCoverPath,
    builder: (column) => column,
  );

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
                Value<int?> groupId = const Value.absent(),
                Value<String?> customCoverPath = const Value.absent(),
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
                groupId: groupId,
                customCoverPath: customCoverPath,
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
                Value<int?> groupId = const Value.absent(),
                Value<String?> customCoverPath = const Value.absent(),
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
                groupId: groupId,
                customCoverPath: customCoverPath,
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
typedef $$SourceChecksTableCreateCompanionBuilder =
    SourceChecksCompanion Function({
      Value<int> id,
      required int sourceId,
      required DateTime checkedAt,
      required String status,
      Value<String?> invalidGroups,
      Value<String?> errorComment,
      required int elapsedMillis,
    });
typedef $$SourceChecksTableUpdateCompanionBuilder =
    SourceChecksCompanion Function({
      Value<int> id,
      Value<int> sourceId,
      Value<DateTime> checkedAt,
      Value<String> status,
      Value<String?> invalidGroups,
      Value<String?> errorComment,
      Value<int> elapsedMillis,
    });

class $$SourceChecksTableFilterComposer
    extends Composer<_$ReaderDatabase, $SourceChecksTable> {
  $$SourceChecksTableFilterComposer({
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

  ColumnFilters<int> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get checkedAt => $composableBuilder(
    column: $table.checkedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get invalidGroups => $composableBuilder(
    column: $table.invalidGroups,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorComment => $composableBuilder(
    column: $table.errorComment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get elapsedMillis => $composableBuilder(
    column: $table.elapsedMillis,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SourceChecksTableOrderingComposer
    extends Composer<_$ReaderDatabase, $SourceChecksTable> {
  $$SourceChecksTableOrderingComposer({
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

  ColumnOrderings<int> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get checkedAt => $composableBuilder(
    column: $table.checkedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get invalidGroups => $composableBuilder(
    column: $table.invalidGroups,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorComment => $composableBuilder(
    column: $table.errorComment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get elapsedMillis => $composableBuilder(
    column: $table.elapsedMillis,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SourceChecksTableAnnotationComposer
    extends Composer<_$ReaderDatabase, $SourceChecksTable> {
  $$SourceChecksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<DateTime> get checkedAt =>
      $composableBuilder(column: $table.checkedAt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get invalidGroups => $composableBuilder(
    column: $table.invalidGroups,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorComment => $composableBuilder(
    column: $table.errorComment,
    builder: (column) => column,
  );

  GeneratedColumn<int> get elapsedMillis => $composableBuilder(
    column: $table.elapsedMillis,
    builder: (column) => column,
  );
}

class $$SourceChecksTableTableManager
    extends
        RootTableManager<
          _$ReaderDatabase,
          $SourceChecksTable,
          SourceCheckRow,
          $$SourceChecksTableFilterComposer,
          $$SourceChecksTableOrderingComposer,
          $$SourceChecksTableAnnotationComposer,
          $$SourceChecksTableCreateCompanionBuilder,
          $$SourceChecksTableUpdateCompanionBuilder,
          (
            SourceCheckRow,
            BaseReferences<
              _$ReaderDatabase,
              $SourceChecksTable,
              SourceCheckRow
            >,
          ),
          SourceCheckRow,
          PrefetchHooks Function()
        > {
  $$SourceChecksTableTableManager(_$ReaderDatabase db, $SourceChecksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SourceChecksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SourceChecksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SourceChecksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> sourceId = const Value.absent(),
                Value<DateTime> checkedAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> invalidGroups = const Value.absent(),
                Value<String?> errorComment = const Value.absent(),
                Value<int> elapsedMillis = const Value.absent(),
              }) => SourceChecksCompanion(
                id: id,
                sourceId: sourceId,
                checkedAt: checkedAt,
                status: status,
                invalidGroups: invalidGroups,
                errorComment: errorComment,
                elapsedMillis: elapsedMillis,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int sourceId,
                required DateTime checkedAt,
                required String status,
                Value<String?> invalidGroups = const Value.absent(),
                Value<String?> errorComment = const Value.absent(),
                required int elapsedMillis,
              }) => SourceChecksCompanion.insert(
                id: id,
                sourceId: sourceId,
                checkedAt: checkedAt,
                status: status,
                invalidGroups: invalidGroups,
                errorComment: errorComment,
                elapsedMillis: elapsedMillis,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SourceChecksTable, SourceCheckRow>(table),
                  BaseReferences<
                    _$ReaderDatabase,
                    $SourceChecksTable,
                    SourceCheckRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SourceChecksTableProcessedTableManager =
    ProcessedTableManager<
      _$ReaderDatabase,
      $SourceChecksTable,
      SourceCheckRow,
      $$SourceChecksTableFilterComposer,
      $$SourceChecksTableOrderingComposer,
      $$SourceChecksTableAnnotationComposer,
      $$SourceChecksTableCreateCompanionBuilder,
      $$SourceChecksTableUpdateCompanionBuilder,
      (
        SourceCheckRow,
        BaseReferences<_$ReaderDatabase, $SourceChecksTable, SourceCheckRow>,
      ),
      SourceCheckRow,
      PrefetchHooks Function()
    >;
typedef $$BookGroupsTableCreateCompanionBuilder = BookGroupsCompanion Function({
  Value<int> id,
  required String name,
  Value<int> sortOrder,
  required DateTime createdAt,
});
typedef $$BookGroupsTableUpdateCompanionBuilder = BookGroupsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<int> sortOrder,
  Value<DateTime> createdAt,
});

class $$BookGroupsTableFilterComposer
    extends Composer<_$ReaderDatabase, $BookGroupsTable> {
  $$BookGroupsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BookGroupsTableOrderingComposer
    extends Composer<_$ReaderDatabase, $BookGroupsTable> {
  $$BookGroupsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BookGroupsTableAnnotationComposer
    extends Composer<_$ReaderDatabase, $BookGroupsTable> {
  $$BookGroupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$BookGroupsTableTableManager
    extends
        RootTableManager<
          _$ReaderDatabase,
          $BookGroupsTable,
          BookGroupRow,
          $$BookGroupsTableFilterComposer,
          $$BookGroupsTableOrderingComposer,
          $$BookGroupsTableAnnotationComposer,
          $$BookGroupsTableCreateCompanionBuilder,
          $$BookGroupsTableUpdateCompanionBuilder,
          (
            BookGroupRow,
            BaseReferences<_$ReaderDatabase, $BookGroupsTable, BookGroupRow>,
          ),
          BookGroupRow,
          PrefetchHooks Function()
        > {
  $$BookGroupsTableTableManager(_$ReaderDatabase db, $BookGroupsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookGroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookGroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookGroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => BookGroupsCompanion(
                id: id,
                name: name,
                sortOrder: sortOrder,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<int> sortOrder = const Value.absent(),
                required DateTime createdAt,
              }) => BookGroupsCompanion.insert(
                id: id,
                name: name,
                sortOrder: sortOrder,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BookGroupsTable, BookGroupRow>(table),
                  BaseReferences<
                    _$ReaderDatabase,
                    $BookGroupsTable,
                    BookGroupRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BookGroupsTableProcessedTableManager =
    ProcessedTableManager<
      _$ReaderDatabase,
      $BookGroupsTable,
      BookGroupRow,
      $$BookGroupsTableFilterComposer,
      $$BookGroupsTableOrderingComposer,
      $$BookGroupsTableAnnotationComposer,
      $$BookGroupsTableCreateCompanionBuilder,
      $$BookGroupsTableUpdateCompanionBuilder,
      (
        BookGroupRow,
        BaseReferences<_$ReaderDatabase, $BookGroupsTable, BookGroupRow>,
      ),
      BookGroupRow,
      PrefetchHooks Function()
    >;
typedef $$BookmarksTableCreateCompanionBuilder = BookmarksCompanion Function({
  Value<int> id,
  required String sourceUrl,
  required String bookUrl,
  required String bookName,
  Value<String?> tocUrl,
  required String chapterUrl,
  Value<String?> chapterName,
  Value<int> chapterIndex,
  Value<int> charOffset,
  Value<String?> excerpt,
  required DateTime createdAt,
});
typedef $$BookmarksTableUpdateCompanionBuilder = BookmarksCompanion Function({
  Value<int> id,
  Value<String> sourceUrl,
  Value<String> bookUrl,
  Value<String> bookName,
  Value<String?> tocUrl,
  Value<String> chapterUrl,
  Value<String?> chapterName,
  Value<int> chapterIndex,
  Value<int> charOffset,
  Value<String?> excerpt,
  Value<DateTime> createdAt,
});

class $$BookmarksTableFilterComposer
    extends Composer<_$ReaderDatabase, $BookmarksTable> {
  $$BookmarksTableFilterComposer({
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

  ColumnFilters<String> get bookName => $composableBuilder(
    column: $table.bookName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tocUrl => $composableBuilder(
    column: $table.tocUrl,
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

  ColumnFilters<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get charOffset => $composableBuilder(
    column: $table.charOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get excerpt => $composableBuilder(
    column: $table.excerpt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BookmarksTableOrderingComposer
    extends Composer<_$ReaderDatabase, $BookmarksTable> {
  $$BookmarksTableOrderingComposer({
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

  ColumnOrderings<String> get bookName => $composableBuilder(
    column: $table.bookName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tocUrl => $composableBuilder(
    column: $table.tocUrl,
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

  ColumnOrderings<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get charOffset => $composableBuilder(
    column: $table.charOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get excerpt => $composableBuilder(
    column: $table.excerpt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BookmarksTableAnnotationComposer
    extends Composer<_$ReaderDatabase, $BookmarksTable> {
  $$BookmarksTableAnnotationComposer({
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

  GeneratedColumn<String> get bookName =>
      $composableBuilder(column: $table.bookName, builder: (column) => column);

  GeneratedColumn<String> get tocUrl =>
      $composableBuilder(column: $table.tocUrl, builder: (column) => column);

  GeneratedColumn<String> get chapterUrl => $composableBuilder(
    column: $table.chapterUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get chapterName => $composableBuilder(
    column: $table.chapterName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get chapterIndex => $composableBuilder(
    column: $table.chapterIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get charOffset => $composableBuilder(
    column: $table.charOffset,
    builder: (column) => column,
  );

  GeneratedColumn<String> get excerpt =>
      $composableBuilder(column: $table.excerpt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$BookmarksTableTableManager
    extends
        RootTableManager<
          _$ReaderDatabase,
          $BookmarksTable,
          BookmarkRow,
          $$BookmarksTableFilterComposer,
          $$BookmarksTableOrderingComposer,
          $$BookmarksTableAnnotationComposer,
          $$BookmarksTableCreateCompanionBuilder,
          $$BookmarksTableUpdateCompanionBuilder,
          (
            BookmarkRow,
            BaseReferences<_$ReaderDatabase, $BookmarksTable, BookmarkRow>,
          ),
          BookmarkRow,
          PrefetchHooks Function()
        > {
  $$BookmarksTableTableManager(_$ReaderDatabase db, $BookmarksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookmarksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookmarksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookmarksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> sourceUrl = const Value.absent(),
                Value<String> bookUrl = const Value.absent(),
                Value<String> bookName = const Value.absent(),
                Value<String?> tocUrl = const Value.absent(),
                Value<String> chapterUrl = const Value.absent(),
                Value<String?> chapterName = const Value.absent(),
                Value<int> chapterIndex = const Value.absent(),
                Value<int> charOffset = const Value.absent(),
                Value<String?> excerpt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => BookmarksCompanion(
                id: id,
                sourceUrl: sourceUrl,
                bookUrl: bookUrl,
                bookName: bookName,
                tocUrl: tocUrl,
                chapterUrl: chapterUrl,
                chapterName: chapterName,
                chapterIndex: chapterIndex,
                charOffset: charOffset,
                excerpt: excerpt,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String sourceUrl,
                required String bookUrl,
                required String bookName,
                Value<String?> tocUrl = const Value.absent(),
                required String chapterUrl,
                Value<String?> chapterName = const Value.absent(),
                Value<int> chapterIndex = const Value.absent(),
                Value<int> charOffset = const Value.absent(),
                Value<String?> excerpt = const Value.absent(),
                required DateTime createdAt,
              }) => BookmarksCompanion.insert(
                id: id,
                sourceUrl: sourceUrl,
                bookUrl: bookUrl,
                bookName: bookName,
                tocUrl: tocUrl,
                chapterUrl: chapterUrl,
                chapterName: chapterName,
                chapterIndex: chapterIndex,
                charOffset: charOffset,
                excerpt: excerpt,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BookmarksTable, BookmarkRow>(table),
                  BaseReferences<
                    _$ReaderDatabase,
                    $BookmarksTable,
                    BookmarkRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BookmarksTableProcessedTableManager =
    ProcessedTableManager<
      _$ReaderDatabase,
      $BookmarksTable,
      BookmarkRow,
      $$BookmarksTableFilterComposer,
      $$BookmarksTableOrderingComposer,
      $$BookmarksTableAnnotationComposer,
      $$BookmarksTableCreateCompanionBuilder,
      $$BookmarksTableUpdateCompanionBuilder,
      (
        BookmarkRow,
        BaseReferences<_$ReaderDatabase, $BookmarksTable, BookmarkRow>,
      ),
      BookmarkRow,
      PrefetchHooks Function()
    >;
typedef $$ReadRecordsTableCreateCompanionBuilder =
    ReadRecordsCompanion Function({
      Value<int> id,
      required String sourceUrl,
      required String bookUrl,
      required String bookName,
      Value<String?> chapterUrl,
      Value<String?> chapterName,
      required DateTime startedAt,
      required DateTime endedAt,
      required int durationSeconds,
    });
typedef $$ReadRecordsTableUpdateCompanionBuilder =
    ReadRecordsCompanion Function({
      Value<int> id,
      Value<String> sourceUrl,
      Value<String> bookUrl,
      Value<String> bookName,
      Value<String?> chapterUrl,
      Value<String?> chapterName,
      Value<DateTime> startedAt,
      Value<DateTime> endedAt,
      Value<int> durationSeconds,
    });

class $$ReadRecordsTableFilterComposer
    extends Composer<_$ReaderDatabase, $ReadRecordsTable> {
  $$ReadRecordsTableFilterComposer({
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

  ColumnFilters<String> get bookName => $composableBuilder(
    column: $table.bookName,
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

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReadRecordsTableOrderingComposer
    extends Composer<_$ReaderDatabase, $ReadRecordsTable> {
  $$ReadRecordsTableOrderingComposer({
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

  ColumnOrderings<String> get bookName => $composableBuilder(
    column: $table.bookName,
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

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReadRecordsTableAnnotationComposer
    extends Composer<_$ReaderDatabase, $ReadRecordsTable> {
  $$ReadRecordsTableAnnotationComposer({
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

  GeneratedColumn<String> get bookName =>
      $composableBuilder(column: $table.bookName, builder: (column) => column);

  GeneratedColumn<String> get chapterUrl => $composableBuilder(
    column: $table.chapterUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get chapterName => $composableBuilder(
    column: $table.chapterName,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );
}

class $$ReadRecordsTableTableManager
    extends
        RootTableManager<
          _$ReaderDatabase,
          $ReadRecordsTable,
          ReadRecordRow,
          $$ReadRecordsTableFilterComposer,
          $$ReadRecordsTableOrderingComposer,
          $$ReadRecordsTableAnnotationComposer,
          $$ReadRecordsTableCreateCompanionBuilder,
          $$ReadRecordsTableUpdateCompanionBuilder,
          (
            ReadRecordRow,
            BaseReferences<_$ReaderDatabase, $ReadRecordsTable, ReadRecordRow>,
          ),
          ReadRecordRow,
          PrefetchHooks Function()
        > {
  $$ReadRecordsTableTableManager(_$ReaderDatabase db, $ReadRecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReadRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReadRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> sourceUrl = const Value.absent(),
                Value<String> bookUrl = const Value.absent(),
                Value<String> bookName = const Value.absent(),
                Value<String?> chapterUrl = const Value.absent(),
                Value<String?> chapterName = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime> endedAt = const Value.absent(),
                Value<int> durationSeconds = const Value.absent(),
              }) => ReadRecordsCompanion(
                id: id,
                sourceUrl: sourceUrl,
                bookUrl: bookUrl,
                bookName: bookName,
                chapterUrl: chapterUrl,
                chapterName: chapterName,
                startedAt: startedAt,
                endedAt: endedAt,
                durationSeconds: durationSeconds,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String sourceUrl,
                required String bookUrl,
                required String bookName,
                Value<String?> chapterUrl = const Value.absent(),
                Value<String?> chapterName = const Value.absent(),
                required DateTime startedAt,
                required DateTime endedAt,
                required int durationSeconds,
              }) => ReadRecordsCompanion.insert(
                id: id,
                sourceUrl: sourceUrl,
                bookUrl: bookUrl,
                bookName: bookName,
                chapterUrl: chapterUrl,
                chapterName: chapterName,
                startedAt: startedAt,
                endedAt: endedAt,
                durationSeconds: durationSeconds,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReadRecordsTable, ReadRecordRow>(table),
                  BaseReferences<
                    _$ReaderDatabase,
                    $ReadRecordsTable,
                    ReadRecordRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReadRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$ReaderDatabase,
      $ReadRecordsTable,
      ReadRecordRow,
      $$ReadRecordsTableFilterComposer,
      $$ReadRecordsTableOrderingComposer,
      $$ReadRecordsTableAnnotationComposer,
      $$ReadRecordsTableCreateCompanionBuilder,
      $$ReadRecordsTableUpdateCompanionBuilder,
      (
        ReadRecordRow,
        BaseReferences<_$ReaderDatabase, $ReadRecordsTable, ReadRecordRow>,
      ),
      ReadRecordRow,
      PrefetchHooks Function()
    >;
typedef $$CookiesTableCreateCompanionBuilder = CookiesCompanion Function({
  Value<int> id,
  required String domain,
  required String path,
  required String name,
  required String value,
  Value<bool> isSecure,
  Value<DateTime?> expiresAt,
  required DateTime createdAt,
});
typedef $$CookiesTableUpdateCompanionBuilder = CookiesCompanion Function({
  Value<int> id,
  Value<String> domain,
  Value<String> path,
  Value<String> name,
  Value<String> value,
  Value<bool> isSecure,
  Value<DateTime?> expiresAt,
  Value<DateTime> createdAt,
});

class $$CookiesTableFilterComposer
    extends Composer<_$ReaderDatabase, $CookiesTable> {
  $$CookiesTableFilterComposer({
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

  ColumnFilters<String> get domain => $composableBuilder(
    column: $table.domain,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSecure => $composableBuilder(
    column: $table.isSecure,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CookiesTableOrderingComposer
    extends Composer<_$ReaderDatabase, $CookiesTable> {
  $$CookiesTableOrderingComposer({
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

  ColumnOrderings<String> get domain => $composableBuilder(
    column: $table.domain,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSecure => $composableBuilder(
    column: $table.isSecure,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CookiesTableAnnotationComposer
    extends Composer<_$ReaderDatabase, $CookiesTable> {
  $$CookiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get domain =>
      $composableBuilder(column: $table.domain, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<bool> get isSecure =>
      $composableBuilder(column: $table.isSecure, builder: (column) => column);

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$CookiesTableTableManager
    extends
        RootTableManager<
          _$ReaderDatabase,
          $CookiesTable,
          CookieRow,
          $$CookiesTableFilterComposer,
          $$CookiesTableOrderingComposer,
          $$CookiesTableAnnotationComposer,
          $$CookiesTableCreateCompanionBuilder,
          $$CookiesTableUpdateCompanionBuilder,
          (
            CookieRow,
            BaseReferences<_$ReaderDatabase, $CookiesTable, CookieRow>,
          ),
          CookieRow,
          PrefetchHooks Function()
        > {
  $$CookiesTableTableManager(_$ReaderDatabase db, $CookiesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CookiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CookiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CookiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> domain = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<bool> isSecure = const Value.absent(),
                Value<DateTime?> expiresAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => CookiesCompanion(
                id: id,
                domain: domain,
                path: path,
                name: name,
                value: value,
                isSecure: isSecure,
                expiresAt: expiresAt,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String domain,
                required String path,
                required String name,
                required String value,
                Value<bool> isSecure = const Value.absent(),
                Value<DateTime?> expiresAt = const Value.absent(),
                required DateTime createdAt,
              }) => CookiesCompanion.insert(
                id: id,
                domain: domain,
                path: path,
                name: name,
                value: value,
                isSecure: isSecure,
                expiresAt: expiresAt,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CookiesTable, CookieRow>(table),
                  BaseReferences<_$ReaderDatabase, $CookiesTable, CookieRow>(
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

typedef $$CookiesTableProcessedTableManager =
    ProcessedTableManager<
      _$ReaderDatabase,
      $CookiesTable,
      CookieRow,
      $$CookiesTableFilterComposer,
      $$CookiesTableOrderingComposer,
      $$CookiesTableAnnotationComposer,
      $$CookiesTableCreateCompanionBuilder,
      $$CookiesTableUpdateCompanionBuilder,
      (CookieRow, BaseReferences<_$ReaderDatabase, $CookiesTable, CookieRow>),
      CookieRow,
      PrefetchHooks Function()
    >;
typedef $$RulesTableCreateCompanionBuilder = RulesCompanion Function({
  Value<int> id,
  required String kind,
  required String name,
  required String payload,
  Value<bool> isEnabled,
  Value<bool> isBuiltIn,
  Value<int> sortOrder,
  required DateTime createdAt,
});
typedef $$RulesTableUpdateCompanionBuilder = RulesCompanion Function({
  Value<int> id,
  Value<String> kind,
  Value<String> name,
  Value<String> payload,
  Value<bool> isEnabled,
  Value<bool> isBuiltIn,
  Value<int> sortOrder,
  Value<DateTime> createdAt,
});

class $$RulesTableFilterComposer
    extends Composer<_$ReaderDatabase, $RulesTable> {
  $$RulesTableFilterComposer({
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

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isBuiltIn => $composableBuilder(
    column: $table.isBuiltIn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RulesTableOrderingComposer
    extends Composer<_$ReaderDatabase, $RulesTable> {
  $$RulesTableOrderingComposer({
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

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isBuiltIn => $composableBuilder(
    column: $table.isBuiltIn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RulesTableAnnotationComposer
    extends Composer<_$ReaderDatabase, $RulesTable> {
  $$RulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<bool> get isEnabled =>
      $composableBuilder(column: $table.isEnabled, builder: (column) => column);

  GeneratedColumn<bool> get isBuiltIn =>
      $composableBuilder(column: $table.isBuiltIn, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$RulesTableTableManager
    extends
        RootTableManager<
          _$ReaderDatabase,
          $RulesTable,
          RuleRow,
          $$RulesTableFilterComposer,
          $$RulesTableOrderingComposer,
          $$RulesTableAnnotationComposer,
          $$RulesTableCreateCompanionBuilder,
          $$RulesTableUpdateCompanionBuilder,
          (RuleRow, BaseReferences<_$ReaderDatabase, $RulesTable, RuleRow>),
          RuleRow,
          PrefetchHooks Function()
        > {
  $$RulesTableTableManager(_$ReaderDatabase db, $RulesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<bool> isBuiltIn = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => RulesCompanion(
                id: id,
                kind: kind,
                name: name,
                payload: payload,
                isEnabled: isEnabled,
                isBuiltIn: isBuiltIn,
                sortOrder: sortOrder,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String kind,
                required String name,
                required String payload,
                Value<bool> isEnabled = const Value.absent(),
                Value<bool> isBuiltIn = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                required DateTime createdAt,
              }) => RulesCompanion.insert(
                id: id,
                kind: kind,
                name: name,
                payload: payload,
                isEnabled: isEnabled,
                isBuiltIn: isBuiltIn,
                sortOrder: sortOrder,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RulesTable, RuleRow>(table),
                  BaseReferences<_$ReaderDatabase, $RulesTable, RuleRow>(
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

typedef $$RulesTableProcessedTableManager =
    ProcessedTableManager<
      _$ReaderDatabase,
      $RulesTable,
      RuleRow,
      $$RulesTableFilterComposer,
      $$RulesTableOrderingComposer,
      $$RulesTableAnnotationComposer,
      $$RulesTableCreateCompanionBuilder,
      $$RulesTableUpdateCompanionBuilder,
      (RuleRow, BaseReferences<_$ReaderDatabase, $RulesTable, RuleRow>),
      RuleRow,
      PrefetchHooks Function()
    >;
typedef $$SourceVariablesTableCreateCompanionBuilder =
    SourceVariablesCompanion Function({
      required String sourceUrl,
      required String name,
      required String value,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$SourceVariablesTableUpdateCompanionBuilder =
    SourceVariablesCompanion Function({
      Value<String> sourceUrl,
      Value<String> name,
      Value<String> value,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$SourceVariablesTableFilterComposer
    extends Composer<_$ReaderDatabase, $SourceVariablesTable> {
  $$SourceVariablesTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SourceVariablesTableOrderingComposer
    extends Composer<_$ReaderDatabase, $SourceVariablesTable> {
  $$SourceVariablesTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SourceVariablesTableAnnotationComposer
    extends Composer<_$ReaderDatabase, $SourceVariablesTable> {
  $$SourceVariablesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SourceVariablesTableTableManager
    extends
        RootTableManager<
          _$ReaderDatabase,
          $SourceVariablesTable,
          SourceVariableRow,
          $$SourceVariablesTableFilterComposer,
          $$SourceVariablesTableOrderingComposer,
          $$SourceVariablesTableAnnotationComposer,
          $$SourceVariablesTableCreateCompanionBuilder,
          $$SourceVariablesTableUpdateCompanionBuilder,
          (
            SourceVariableRow,
            BaseReferences<
              _$ReaderDatabase,
              $SourceVariablesTable,
              SourceVariableRow
            >,
          ),
          SourceVariableRow,
          PrefetchHooks Function()
        > {
  $$SourceVariablesTableTableManager(
    _$ReaderDatabase db,
    $SourceVariablesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SourceVariablesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SourceVariablesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SourceVariablesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sourceUrl = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SourceVariablesCompanion(
                sourceUrl: sourceUrl,
                name: name,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sourceUrl,
                required String name,
                required String value,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SourceVariablesCompanion.insert(
                sourceUrl: sourceUrl,
                name: name,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SourceVariablesTable, SourceVariableRow>(table),
                  BaseReferences<
                    _$ReaderDatabase,
                    $SourceVariablesTable,
                    SourceVariableRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SourceVariablesTableProcessedTableManager =
    ProcessedTableManager<
      _$ReaderDatabase,
      $SourceVariablesTable,
      SourceVariableRow,
      $$SourceVariablesTableFilterComposer,
      $$SourceVariablesTableOrderingComposer,
      $$SourceVariablesTableAnnotationComposer,
      $$SourceVariablesTableCreateCompanionBuilder,
      $$SourceVariablesTableUpdateCompanionBuilder,
      (
        SourceVariableRow,
        BaseReferences<
          _$ReaderDatabase,
          $SourceVariablesTable,
          SourceVariableRow
        >,
      ),
      SourceVariableRow,
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
  $$SourceChecksTableTableManager get sourceChecks =>
      $$SourceChecksTableTableManager(_db, _db.sourceChecks);
  $$BookGroupsTableTableManager get bookGroups =>
      $$BookGroupsTableTableManager(_db, _db.bookGroups);
  $$BookmarksTableTableManager get bookmarks =>
      $$BookmarksTableTableManager(_db, _db.bookmarks);
  $$ReadRecordsTableTableManager get readRecords =>
      $$ReadRecordsTableTableManager(_db, _db.readRecords);
  $$CookiesTableTableManager get cookies =>
      $$CookiesTableTableManager(_db, _db.cookies);
  $$RulesTableTableManager get rules =>
      $$RulesTableTableManager(_db, _db.rules);
  $$SourceVariablesTableTableManager get sourceVariables =>
      $$SourceVariablesTableTableManager(_db, _db.sourceVariables);
}
