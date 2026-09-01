// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_tombstone.dart';

// **************************************************************************
// _IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, invalid_use_of_protected_member, lines_longer_than_80_chars, constant_identifier_names, avoid_js_rounded_ints, no_leading_underscores_for_local_identifiers, require_trailing_commas, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_in_if_null_operators, library_private_types_in_public_api, prefer_const_constructors
// ignore_for_file: type=lint

extension GetSyncTombstoneCollection on Isar {
  IsarCollection<int, SyncTombstone> get syncTombstones => this.collection();
}

final SyncTombstoneSchema = IsarGeneratedSchema(
  schema: IsarSchema(
    name: 'SyncTombstone',
    idName: 'isarId',
    embedded: false,
    properties: [
      IsarPropertySchema(name: 'isDiary', type: IsarType.bool),
      IsarPropertySchema(name: 'entityId', type: IsarType.string),
      IsarPropertySchema(name: 'key', type: IsarType.string),
      IsarPropertySchema(name: 'timeMs', type: IsarType.long),
      IsarPropertySchema(name: 'pushedBackends', type: IsarType.stringList),
    ],
    indexes: [],
  ),
  converter: IsarObjectConverter<int, SyncTombstone>(
    serialize: serializeSyncTombstone,
    deserialize: deserializeSyncTombstone,
    deserializeProperty: deserializeSyncTombstoneProp,
  ),
  getEmbeddedSchemas: () => [],
);

@isarProtected
int serializeSyncTombstone(IsarWriter writer, SyncTombstone object) {
  IsarCore.writeBool(writer, 1, value: object.isDiary);
  IsarCore.writeString(writer, 2, object.entityId);
  IsarCore.writeString(writer, 3, object.key);
  IsarCore.writeLong(writer, 4, object.timeMs);
  {
    final list = object.pushedBackends;
    final listWriter = IsarCore.beginList(writer, 5, list.length);
    for (var i = 0; i < list.length; i++) {
      IsarCore.writeString(listWriter, i, list[i]);
    }
    IsarCore.endList(writer, listWriter);
  }
  return object.isarId;
}

@isarProtected
SyncTombstone deserializeSyncTombstone(IsarReader reader) {
  final String _key;
  _key = IsarCore.readString(reader, 3) ?? '';
  final int _timeMs;
  _timeMs = IsarCore.readLong(reader, 4);
  final List<String> _pushedBackends;
  {
    final length = IsarCore.readList(reader, 5, IsarCore.readerPtrPtr);
    {
      final reader = IsarCore.readerPtr;
      if (reader.isNull) {
        _pushedBackends = const <String>[];
      } else {
        final list = List<String>.filled(length, '', growable: true);
        for (var i = 0; i < length; i++) {
          list[i] = IsarCore.readString(reader, i) ?? '';
        }
        IsarCore.freeReader(reader);
        _pushedBackends = list;
      }
    }
  }
  final object = SyncTombstone(
    key: _key,
    timeMs: _timeMs,
    pushedBackends: _pushedBackends,
  );
  return object;
}

@isarProtected
dynamic deserializeSyncTombstoneProp(IsarReader reader, int property) {
  switch (property) {
    case 0:
      return IsarCore.readId(reader);
    case 1:
      return IsarCore.readBool(reader, 1);
    case 2:
      return IsarCore.readString(reader, 2) ?? '';
    case 3:
      return IsarCore.readString(reader, 3) ?? '';
    case 4:
      return IsarCore.readLong(reader, 4);
    case 5:
      {
        final length = IsarCore.readList(reader, 5, IsarCore.readerPtrPtr);
        {
          final reader = IsarCore.readerPtr;
          if (reader.isNull) {
            return const <String>[];
          } else {
            final list = List<String>.filled(length, '', growable: true);
            for (var i = 0; i < length; i++) {
              list[i] = IsarCore.readString(reader, i) ?? '';
            }
            IsarCore.freeReader(reader);
            return list;
          }
        }
      }
    default:
      throw ArgumentError('Unknown property: $property');
  }
}

sealed class _SyncTombstoneUpdate {
  bool call({
    required int isarId,
    bool? isDiary,
    String? entityId,
    String? key,
    int? timeMs,
  });
}

class _SyncTombstoneUpdateImpl implements _SyncTombstoneUpdate {
  const _SyncTombstoneUpdateImpl(this.collection);

  final IsarCollection<int, SyncTombstone> collection;

  @override
  bool call({
    required int isarId,
    Object? isDiary = ignore,
    Object? entityId = ignore,
    Object? key = ignore,
    Object? timeMs = ignore,
  }) {
    return collection.updateProperties(
          [isarId],
          {
            if (isDiary != ignore) 1: isDiary as bool?,
            if (entityId != ignore) 2: entityId as String?,
            if (key != ignore) 3: key as String?,
            if (timeMs != ignore) 4: timeMs as int?,
          },
        ) >
        0;
  }
}

sealed class _SyncTombstoneUpdateAll {
  int call({
    required List<int> isarId,
    bool? isDiary,
    String? entityId,
    String? key,
    int? timeMs,
  });
}

class _SyncTombstoneUpdateAllImpl implements _SyncTombstoneUpdateAll {
  const _SyncTombstoneUpdateAllImpl(this.collection);

  final IsarCollection<int, SyncTombstone> collection;

  @override
  int call({
    required List<int> isarId,
    Object? isDiary = ignore,
    Object? entityId = ignore,
    Object? key = ignore,
    Object? timeMs = ignore,
  }) {
    return collection.updateProperties(isarId, {
      if (isDiary != ignore) 1: isDiary as bool?,
      if (entityId != ignore) 2: entityId as String?,
      if (key != ignore) 3: key as String?,
      if (timeMs != ignore) 4: timeMs as int?,
    });
  }
}

extension SyncTombstoneUpdate on IsarCollection<int, SyncTombstone> {
  _SyncTombstoneUpdate get update => _SyncTombstoneUpdateImpl(this);

  _SyncTombstoneUpdateAll get updateAll => _SyncTombstoneUpdateAllImpl(this);
}

sealed class _SyncTombstoneQueryUpdate {
  int call({bool? isDiary, String? entityId, String? key, int? timeMs});
}

class _SyncTombstoneQueryUpdateImpl implements _SyncTombstoneQueryUpdate {
  const _SyncTombstoneQueryUpdateImpl(this.query, {this.limit});

  final IsarQuery<SyncTombstone> query;
  final int? limit;

  @override
  int call({
    Object? isDiary = ignore,
    Object? entityId = ignore,
    Object? key = ignore,
    Object? timeMs = ignore,
  }) {
    return query.updateProperties(limit: limit, {
      if (isDiary != ignore) 1: isDiary as bool?,
      if (entityId != ignore) 2: entityId as String?,
      if (key != ignore) 3: key as String?,
      if (timeMs != ignore) 4: timeMs as int?,
    });
  }
}

extension SyncTombstoneQueryUpdate on IsarQuery<SyncTombstone> {
  _SyncTombstoneQueryUpdate get updateFirst =>
      _SyncTombstoneQueryUpdateImpl(this, limit: 1);

  _SyncTombstoneQueryUpdate get updateAll =>
      _SyncTombstoneQueryUpdateImpl(this);
}

class _SyncTombstoneQueryBuilderUpdateImpl
    implements _SyncTombstoneQueryUpdate {
  const _SyncTombstoneQueryBuilderUpdateImpl(this.query, {this.limit});

  final QueryBuilder<SyncTombstone, SyncTombstone, QOperations> query;
  final int? limit;

  @override
  int call({
    Object? isDiary = ignore,
    Object? entityId = ignore,
    Object? key = ignore,
    Object? timeMs = ignore,
  }) {
    final q = query.build();
    try {
      return q.updateProperties(limit: limit, {
        if (isDiary != ignore) 1: isDiary as bool?,
        if (entityId != ignore) 2: entityId as String?,
        if (key != ignore) 3: key as String?,
        if (timeMs != ignore) 4: timeMs as int?,
      });
    } finally {
      q.close();
    }
  }
}

extension SyncTombstoneQueryBuilderUpdate
    on QueryBuilder<SyncTombstone, SyncTombstone, QOperations> {
  _SyncTombstoneQueryUpdate get updateFirst =>
      _SyncTombstoneQueryBuilderUpdateImpl(this, limit: 1);

  _SyncTombstoneQueryUpdate get updateAll =>
      _SyncTombstoneQueryBuilderUpdateImpl(this);
}

extension SyncTombstoneQueryFilter
    on QueryBuilder<SyncTombstone, SyncTombstone, QFilterCondition> {
  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition>
  isarIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition>
  isarIdGreaterThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition>
  isarIdGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition>
  isarIdLessThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 0, value: value));
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition>
  isarIdLessThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition>
  isarIdBetween(int lower, int upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 0, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition>
  isDiaryEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 1, value: value),
      );
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition>
  entityIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 2, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition>
  entityIdGreaterThan(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition>
  entityIdGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition>
  entityIdLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 2, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition>
  entityIdLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition>
  entityIdBetween(String lower, String upper, {bool caseSensitive = true}) {
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

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition>
  entityIdStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition>
  entityIdEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition>
  entityIdContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition>
  entityIdMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition>
  entityIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 2, value: ''),
      );
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition>
  entityIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 2, value: ''),
      );
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition> keyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 3, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition>
  keyGreaterThan(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition>
  keyGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition> keyLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 3, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition>
  keyLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition> keyBetween(
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

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition>
  keyStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition> keyEndsWith(
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

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition> keyContains(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition> keyMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition>
  keyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 3, value: ''),
      );
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition>
  keyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 3, value: ''),
      );
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition>
  timeMsEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 4, value: value),
      );
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition>
  timeMsGreaterThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 4, value: value),
      );
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition>
  timeMsGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 4, value: value),
      );
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition>
  timeMsLessThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 4, value: value));
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition>
  timeMsLessThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 4, value: value),
      );
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition>
  timeMsBetween(int lower, int upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 4, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition>
  pushedBackendsElementEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 5, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition>
  pushedBackendsElementGreaterThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 5,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition>
  pushedBackendsElementGreaterThanOrEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 5,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition>
  pushedBackendsElementLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 5, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition>
  pushedBackendsElementLessThanOrEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 5,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition>
  pushedBackendsElementBetween(
    String lower,
    String upper, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 5,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition>
  pushedBackendsElementStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 5,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition>
  pushedBackendsElementEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 5,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition>
  pushedBackendsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 5,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition>
  pushedBackendsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 5,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition>
  pushedBackendsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 5, value: ''),
      );
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition>
  pushedBackendsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 5, value: ''),
      );
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition>
  pushedBackendsIsEmpty() {
    return not().pushedBackendsIsNotEmpty();
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterFilterCondition>
  pushedBackendsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterOrEqualCondition(property: 5, value: null),
      );
    });
  }
}

extension SyncTombstoneQueryObject
    on QueryBuilder<SyncTombstone, SyncTombstone, QFilterCondition> {}

extension SyncTombstoneQuerySortBy
    on QueryBuilder<SyncTombstone, SyncTombstone, QSortBy> {
  QueryBuilder<SyncTombstone, SyncTombstone, QAfterSortBy> sortByIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterSortBy> sortByIsarIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterSortBy> sortByIsDiary() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1);
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterSortBy> sortByIsDiaryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc);
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterSortBy> sortByEntityId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterSortBy> sortByEntityIdDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterSortBy> sortByKey({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterSortBy> sortByKeyDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterSortBy> sortByTimeMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4);
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterSortBy> sortByTimeMsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, sort: Sort.desc);
    });
  }
}

extension SyncTombstoneQuerySortThenBy
    on QueryBuilder<SyncTombstone, SyncTombstone, QSortThenBy> {
  QueryBuilder<SyncTombstone, SyncTombstone, QAfterSortBy> thenByIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterSortBy> thenByIsarIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterSortBy> thenByIsDiary() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1);
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterSortBy> thenByIsDiaryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc);
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterSortBy> thenByEntityId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterSortBy> thenByEntityIdDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterSortBy> thenByKey({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterSortBy> thenByKeyDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterSortBy> thenByTimeMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4);
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterSortBy> thenByTimeMsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, sort: Sort.desc);
    });
  }
}

extension SyncTombstoneQueryWhereDistinct
    on QueryBuilder<SyncTombstone, SyncTombstone, QDistinct> {
  QueryBuilder<SyncTombstone, SyncTombstone, QAfterDistinct>
  distinctByIsDiary() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(1);
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterDistinct>
  distinctByEntityId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterDistinct> distinctByKey({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterDistinct>
  distinctByTimeMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(4);
    });
  }

  QueryBuilder<SyncTombstone, SyncTombstone, QAfterDistinct>
  distinctByPushedBackends() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(5);
    });
  }
}

extension SyncTombstoneQueryProperty1
    on QueryBuilder<SyncTombstone, SyncTombstone, QProperty> {
  QueryBuilder<SyncTombstone, int, QAfterProperty> isarIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<SyncTombstone, bool, QAfterProperty> isDiaryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<SyncTombstone, String, QAfterProperty> entityIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<SyncTombstone, String, QAfterProperty> keyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<SyncTombstone, int, QAfterProperty> timeMsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<SyncTombstone, List<String>, QAfterProperty>
  pushedBackendsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }
}

extension SyncTombstoneQueryProperty2<R>
    on QueryBuilder<SyncTombstone, R, QAfterProperty> {
  QueryBuilder<SyncTombstone, (R, int), QAfterProperty> isarIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<SyncTombstone, (R, bool), QAfterProperty> isDiaryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<SyncTombstone, (R, String), QAfterProperty> entityIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<SyncTombstone, (R, String), QAfterProperty> keyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<SyncTombstone, (R, int), QAfterProperty> timeMsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<SyncTombstone, (R, List<String>), QAfterProperty>
  pushedBackendsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }
}

extension SyncTombstoneQueryProperty3<R1, R2>
    on QueryBuilder<SyncTombstone, (R1, R2), QAfterProperty> {
  QueryBuilder<SyncTombstone, (R1, R2, int), QOperations> isarIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<SyncTombstone, (R1, R2, bool), QOperations> isDiaryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<SyncTombstone, (R1, R2, String), QOperations>
  entityIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<SyncTombstone, (R1, R2, String), QOperations> keyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<SyncTombstone, (R1, R2, int), QOperations> timeMsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<SyncTombstone, (R1, R2, List<String>), QOperations>
  pushedBackendsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }
}
