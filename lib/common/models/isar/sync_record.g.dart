// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_record.dart';

// **************************************************************************
// _IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, invalid_use_of_protected_member, lines_longer_than_80_chars, constant_identifier_names, avoid_js_rounded_ints, no_leading_underscores_for_local_identifiers, require_trailing_commas, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_in_if_null_operators, library_private_types_in_public_api, prefer_const_constructors
// ignore_for_file: type=lint

extension GetSyncRecordCollection on Isar {
  IsarCollection<int, SyncRecord> get syncRecords => this.collection();
}

const SyncRecordSchema = IsarGeneratedSchema(
  schema: IsarSchema(
    name: 'SyncRecord',
    idName: 'isarId',
    embedded: false,
    properties: [
      IsarPropertySchema(
        name: 'syncId',
        type: IsarType.string,
      ),
      IsarPropertySchema(
        name: 'diaryId',
        type: IsarType.string,
      ),
      IsarPropertySchema(
        name: 'diaryJson',
        type: IsarType.string,
      ),
      IsarPropertySchema(
        name: 'time',
        type: IsarType.dateTime,
      ),
      IsarPropertySchema(
        name: 'syncType',
        type: IsarType.byte,
        enumMap: {"upload": 0, "download": 1, "update": 2, "delete": 3},
      ),
    ],
    indexes: [],
  ),
  converter: IsarObjectConverter<int, SyncRecord>(
    serialize: serializeSyncRecord,
    deserialize: deserializeSyncRecord,
    deserializeProperty: deserializeSyncRecordProp,
  ),
  embeddedSchemas: [],
);

@isarProtected
int serializeSyncRecord(IsarWriter writer, SyncRecord object) {
  IsarCore.writeString(writer, 1, object.syncId);
  IsarCore.writeString(writer, 2, object.diaryId);
  IsarCore.writeString(writer, 3, object.diaryJson);
  IsarCore.writeLong(writer, 4, object.time.toUtc().microsecondsSinceEpoch);
  IsarCore.writeByte(writer, 5, object.syncType.index);
  return object.isarId;
}

@isarProtected
SyncRecord deserializeSyncRecord(IsarReader reader) {
  final object = SyncRecord();
  object.syncId = IsarCore.readString(reader, 1) ?? '';
  object.diaryId = IsarCore.readString(reader, 2) ?? '';
  object.diaryJson = IsarCore.readString(reader, 3) ?? '';
  {
    final value = IsarCore.readLong(reader, 4);
    if (value == -9223372036854775808) {
      object.time =
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal();
    } else {
      object.time =
          DateTime.fromMicrosecondsSinceEpoch(value, isUtc: true).toLocal();
    }
  }
  {
    if (IsarCore.readNull(reader, 5)) {
      object.syncType = SyncType.upload;
    } else {
      object.syncType =
          _syncRecordSyncType[IsarCore.readByte(reader, 5)] ?? SyncType.upload;
    }
  }
  return object;
}

@isarProtected
dynamic deserializeSyncRecordProp(IsarReader reader, int property) {
  switch (property) {
    case 1:
      return IsarCore.readString(reader, 1) ?? '';
    case 2:
      return IsarCore.readString(reader, 2) ?? '';
    case 3:
      return IsarCore.readString(reader, 3) ?? '';
    case 4:
      {
        final value = IsarCore.readLong(reader, 4);
        if (value == -9223372036854775808) {
          return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal();
        } else {
          return DateTime.fromMicrosecondsSinceEpoch(value, isUtc: true)
              .toLocal();
        }
      }
    case 5:
      {
        if (IsarCore.readNull(reader, 5)) {
          return SyncType.upload;
        } else {
          return _syncRecordSyncType[IsarCore.readByte(reader, 5)] ??
              SyncType.upload;
        }
      }
    case 0:
      return IsarCore.readId(reader);
    default:
      throw ArgumentError('Unknown property: $property');
  }
}

sealed class _SyncRecordUpdate {
  bool call({
    required int isarId,
    String? syncId,
    String? diaryId,
    String? diaryJson,
    DateTime? time,
    SyncType? syncType,
  });
}

class _SyncRecordUpdateImpl implements _SyncRecordUpdate {
  const _SyncRecordUpdateImpl(this.collection);

  final IsarCollection<int, SyncRecord> collection;

  @override
  bool call({
    required int isarId,
    Object? syncId = ignore,
    Object? diaryId = ignore,
    Object? diaryJson = ignore,
    Object? time = ignore,
    Object? syncType = ignore,
  }) {
    return collection.updateProperties([
          isarId
        ], {
          if (syncId != ignore) 1: syncId as String?,
          if (diaryId != ignore) 2: diaryId as String?,
          if (diaryJson != ignore) 3: diaryJson as String?,
          if (time != ignore) 4: time as DateTime?,
          if (syncType != ignore) 5: syncType as SyncType?,
        }) >
        0;
  }
}

sealed class _SyncRecordUpdateAll {
  int call({
    required List<int> isarId,
    String? syncId,
    String? diaryId,
    String? diaryJson,
    DateTime? time,
    SyncType? syncType,
  });
}

class _SyncRecordUpdateAllImpl implements _SyncRecordUpdateAll {
  const _SyncRecordUpdateAllImpl(this.collection);

  final IsarCollection<int, SyncRecord> collection;

  @override
  int call({
    required List<int> isarId,
    Object? syncId = ignore,
    Object? diaryId = ignore,
    Object? diaryJson = ignore,
    Object? time = ignore,
    Object? syncType = ignore,
  }) {
    return collection.updateProperties(isarId, {
      if (syncId != ignore) 1: syncId as String?,
      if (diaryId != ignore) 2: diaryId as String?,
      if (diaryJson != ignore) 3: diaryJson as String?,
      if (time != ignore) 4: time as DateTime?,
      if (syncType != ignore) 5: syncType as SyncType?,
    });
  }
}

extension SyncRecordUpdate on IsarCollection<int, SyncRecord> {
  _SyncRecordUpdate get update => _SyncRecordUpdateImpl(this);

  _SyncRecordUpdateAll get updateAll => _SyncRecordUpdateAllImpl(this);
}

sealed class _SyncRecordQueryUpdate {
  int call({
    String? syncId,
    String? diaryId,
    String? diaryJson,
    DateTime? time,
    SyncType? syncType,
  });
}

class _SyncRecordQueryUpdateImpl implements _SyncRecordQueryUpdate {
  const _SyncRecordQueryUpdateImpl(this.query, {this.limit});

  final IsarQuery<SyncRecord> query;
  final int? limit;

  @override
  int call({
    Object? syncId = ignore,
    Object? diaryId = ignore,
    Object? diaryJson = ignore,
    Object? time = ignore,
    Object? syncType = ignore,
  }) {
    return query.updateProperties(limit: limit, {
      if (syncId != ignore) 1: syncId as String?,
      if (diaryId != ignore) 2: diaryId as String?,
      if (diaryJson != ignore) 3: diaryJson as String?,
      if (time != ignore) 4: time as DateTime?,
      if (syncType != ignore) 5: syncType as SyncType?,
    });
  }
}

extension SyncRecordQueryUpdate on IsarQuery<SyncRecord> {
  _SyncRecordQueryUpdate get updateFirst =>
      _SyncRecordQueryUpdateImpl(this, limit: 1);

  _SyncRecordQueryUpdate get updateAll => _SyncRecordQueryUpdateImpl(this);
}

class _SyncRecordQueryBuilderUpdateImpl implements _SyncRecordQueryUpdate {
  const _SyncRecordQueryBuilderUpdateImpl(this.query, {this.limit});

  final QueryBuilder<SyncRecord, SyncRecord, QOperations> query;
  final int? limit;

  @override
  int call({
    Object? syncId = ignore,
    Object? diaryId = ignore,
    Object? diaryJson = ignore,
    Object? time = ignore,
    Object? syncType = ignore,
  }) {
    final q = query.build();
    try {
      return q.updateProperties(limit: limit, {
        if (syncId != ignore) 1: syncId as String?,
        if (diaryId != ignore) 2: diaryId as String?,
        if (diaryJson != ignore) 3: diaryJson as String?,
        if (time != ignore) 4: time as DateTime?,
        if (syncType != ignore) 5: syncType as SyncType?,
      });
    } finally {
      q.close();
    }
  }
}

extension SyncRecordQueryBuilderUpdate
    on QueryBuilder<SyncRecord, SyncRecord, QOperations> {
  _SyncRecordQueryUpdate get updateFirst =>
      _SyncRecordQueryBuilderUpdateImpl(this, limit: 1);

  _SyncRecordQueryUpdate get updateAll =>
      _SyncRecordQueryBuilderUpdateImpl(this);
}

const _syncRecordSyncType = {
  0: SyncType.upload,
  1: SyncType.download,
  2: SyncType.update,
  3: SyncType.delete,
};

extension SyncRecordQueryFilter
    on QueryBuilder<SyncRecord, SyncRecord, QFilterCondition> {
  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition> syncIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition> syncIdGreaterThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition>
      syncIdGreaterThanOrEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition> syncIdLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition>
      syncIdLessThanOrEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition> syncIdBetween(
    String lower,
    String upper, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 1,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition> syncIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition> syncIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition> syncIdContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition> syncIdMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 1,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition> syncIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(
          property: 1,
          value: '',
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition>
      syncIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(
          property: 1,
          value: '',
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition> diaryIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(
          property: 2,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition>
      diaryIdGreaterThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 2,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition>
      diaryIdGreaterThanOrEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 2,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition> diaryIdLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(
          property: 2,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition>
      diaryIdLessThanOrEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 2,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition> diaryIdBetween(
    String lower,
    String upper, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 2,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition> diaryIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 2,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition> diaryIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 2,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition> diaryIdContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 2,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition> diaryIdMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 2,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition> diaryIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(
          property: 2,
          value: '',
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition>
      diaryIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(
          property: 2,
          value: '',
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition> diaryJsonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition>
      diaryJsonGreaterThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition>
      diaryJsonGreaterThanOrEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition> diaryJsonLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition>
      diaryJsonLessThanOrEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition> diaryJsonBetween(
    String lower,
    String upper, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 3,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition>
      diaryJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition> diaryJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition> diaryJsonContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition> diaryJsonMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 3,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition>
      diaryJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(
          property: 3,
          value: '',
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition>
      diaryJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(
          property: 3,
          value: '',
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition> timeEqualTo(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(
          property: 4,
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition> timeGreaterThan(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 4,
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition>
      timeGreaterThanOrEqualTo(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 4,
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition> timeLessThan(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(
          property: 4,
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition>
      timeLessThanOrEqualTo(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 4,
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition> timeBetween(
    DateTime lower,
    DateTime upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 4,
          lower: lower,
          upper: upper,
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition> syncTypeEqualTo(
    SyncType value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(
          property: 5,
          value: value.index,
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition>
      syncTypeGreaterThan(
    SyncType value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 5,
          value: value.index,
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition>
      syncTypeGreaterThanOrEqualTo(
    SyncType value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 5,
          value: value.index,
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition> syncTypeLessThan(
    SyncType value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(
          property: 5,
          value: value.index,
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition>
      syncTypeLessThanOrEqualTo(
    SyncType value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 5,
          value: value.index,
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition> syncTypeBetween(
    SyncType lower,
    SyncType upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 5,
          lower: lower.index,
          upper: upper.index,
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition> isarIdEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(
          property: 0,
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition> isarIdGreaterThan(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 0,
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition>
      isarIdGreaterThanOrEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 0,
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition> isarIdLessThan(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(
          property: 0,
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition>
      isarIdLessThanOrEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 0,
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterFilterCondition> isarIdBetween(
    int lower,
    int upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 0,
          lower: lower,
          upper: upper,
        ),
      );
    });
  }
}

extension SyncRecordQueryObject
    on QueryBuilder<SyncRecord, SyncRecord, QFilterCondition> {}

extension SyncRecordQuerySortBy
    on QueryBuilder<SyncRecord, SyncRecord, QSortBy> {
  QueryBuilder<SyncRecord, SyncRecord, QAfterSortBy> sortBySyncId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(
        1,
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterSortBy> sortBySyncIdDesc(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(
        1,
        sort: Sort.desc,
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterSortBy> sortByDiaryId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(
        2,
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterSortBy> sortByDiaryIdDesc(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(
        2,
        sort: Sort.desc,
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterSortBy> sortByDiaryJson(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(
        3,
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterSortBy> sortByDiaryJsonDesc(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(
        3,
        sort: Sort.desc,
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterSortBy> sortByTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4);
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterSortBy> sortByTimeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, sort: Sort.desc);
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterSortBy> sortBySyncType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5);
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterSortBy> sortBySyncTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, sort: Sort.desc);
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterSortBy> sortByIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterSortBy> sortByIsarIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }
}

extension SyncRecordQuerySortThenBy
    on QueryBuilder<SyncRecord, SyncRecord, QSortThenBy> {
  QueryBuilder<SyncRecord, SyncRecord, QAfterSortBy> thenBySyncId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterSortBy> thenBySyncIdDesc(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterSortBy> thenByDiaryId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterSortBy> thenByDiaryIdDesc(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterSortBy> thenByDiaryJson(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterSortBy> thenByDiaryJsonDesc(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterSortBy> thenByTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4);
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterSortBy> thenByTimeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, sort: Sort.desc);
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterSortBy> thenBySyncType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5);
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterSortBy> thenBySyncTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, sort: Sort.desc);
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterSortBy> thenByIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterSortBy> thenByIsarIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }
}

extension SyncRecordQueryWhereDistinct
    on QueryBuilder<SyncRecord, SyncRecord, QDistinct> {
  QueryBuilder<SyncRecord, SyncRecord, QAfterDistinct> distinctBySyncId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterDistinct> distinctByDiaryId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterDistinct> distinctByDiaryJson(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterDistinct> distinctByTime() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(4);
    });
  }

  QueryBuilder<SyncRecord, SyncRecord, QAfterDistinct> distinctBySyncType() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(5);
    });
  }
}

extension SyncRecordQueryProperty1
    on QueryBuilder<SyncRecord, SyncRecord, QProperty> {
  QueryBuilder<SyncRecord, String, QAfterProperty> syncIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<SyncRecord, String, QAfterProperty> diaryIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<SyncRecord, String, QAfterProperty> diaryJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<SyncRecord, DateTime, QAfterProperty> timeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<SyncRecord, SyncType, QAfterProperty> syncTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<SyncRecord, int, QAfterProperty> isarIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }
}

extension SyncRecordQueryProperty2<R>
    on QueryBuilder<SyncRecord, R, QAfterProperty> {
  QueryBuilder<SyncRecord, (R, String), QAfterProperty> syncIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<SyncRecord, (R, String), QAfterProperty> diaryIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<SyncRecord, (R, String), QAfterProperty> diaryJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<SyncRecord, (R, DateTime), QAfterProperty> timeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<SyncRecord, (R, SyncType), QAfterProperty> syncTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<SyncRecord, (R, int), QAfterProperty> isarIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }
}

extension SyncRecordQueryProperty3<R1, R2>
    on QueryBuilder<SyncRecord, (R1, R2), QAfterProperty> {
  QueryBuilder<SyncRecord, (R1, R2, String), QOperations> syncIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<SyncRecord, (R1, R2, String), QOperations> diaryIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<SyncRecord, (R1, R2, String), QOperations> diaryJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<SyncRecord, (R1, R2, DateTime), QOperations> timeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<SyncRecord, (R1, R2, SyncType), QOperations> syncTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<SyncRecord, (R1, R2, int), QOperations> isarIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }
}
