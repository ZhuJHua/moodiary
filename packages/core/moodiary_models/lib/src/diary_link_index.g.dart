// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diary_link_index.dart';

// **************************************************************************
// _IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, invalid_use_of_protected_member, lines_longer_than_80_chars, constant_identifier_names, avoid_js_rounded_ints, no_leading_underscores_for_local_identifiers, require_trailing_commas, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_in_if_null_operators, library_private_types_in_public_api, prefer_const_constructors
// ignore_for_file: type=lint

extension GetDiaryLinkIndexCollection on Isar {
  IsarCollection<int, DiaryLinkIndex> get diaryLinkIndexs => this.collection();
}

final DiaryLinkIndexSchema = IsarGeneratedSchema(
  schema: IsarSchema(
    name: 'DiaryLinkIndex',
    idName: 'id',
    embedded: false,
    properties: [
      IsarPropertySchema(name: 'toId', type: IsarType.string),
      IsarPropertySchema(name: 'fromIsarId', type: IsarType.long),
    ],
    indexes: [
      IsarIndexSchema(
        name: 'toId',
        properties: ["toId"],
        unique: false,
        hash: true,
      ),
    ],
  ),
  converter: IsarObjectConverter<int, DiaryLinkIndex>(
    serialize: serializeDiaryLinkIndex,
    deserialize: deserializeDiaryLinkIndex,
    deserializeProperty: deserializeDiaryLinkIndexProp,
  ),
  getEmbeddedSchemas: () => [],
);

@isarProtected
int serializeDiaryLinkIndex(IsarWriter writer, DiaryLinkIndex object) {
  IsarCore.writeString(writer, 1, object.toId);
  IsarCore.writeLong(writer, 2, object.fromIsarId);
  return object.id;
}

@isarProtected
DiaryLinkIndex deserializeDiaryLinkIndex(IsarReader reader) {
  final int _id;
  _id = IsarCore.readId(reader);
  final String _toId;
  _toId = IsarCore.readString(reader, 1) ?? '';
  final int _fromIsarId;
  _fromIsarId = IsarCore.readLong(reader, 2);
  final object = DiaryLinkIndex(id: _id, toId: _toId, fromIsarId: _fromIsarId);
  return object;
}

@isarProtected
dynamic deserializeDiaryLinkIndexProp(IsarReader reader, int property) {
  switch (property) {
    case 0:
      return IsarCore.readId(reader);
    case 1:
      return IsarCore.readString(reader, 1) ?? '';
    case 2:
      return IsarCore.readLong(reader, 2);
    default:
      throw ArgumentError('Unknown property: $property');
  }
}

sealed class _DiaryLinkIndexUpdate {
  bool call({required int id, String? toId, int? fromIsarId});
}

class _DiaryLinkIndexUpdateImpl implements _DiaryLinkIndexUpdate {
  const _DiaryLinkIndexUpdateImpl(this.collection);

  final IsarCollection<int, DiaryLinkIndex> collection;

  @override
  bool call({
    required int id,
    Object? toId = ignore,
    Object? fromIsarId = ignore,
  }) {
    return collection.updateProperties(
          [id],
          {
            if (toId != ignore) 1: toId as String?,
            if (fromIsarId != ignore) 2: fromIsarId as int?,
          },
        ) >
        0;
  }
}

sealed class _DiaryLinkIndexUpdateAll {
  int call({required List<int> id, String? toId, int? fromIsarId});
}

class _DiaryLinkIndexUpdateAllImpl implements _DiaryLinkIndexUpdateAll {
  const _DiaryLinkIndexUpdateAllImpl(this.collection);

  final IsarCollection<int, DiaryLinkIndex> collection;

  @override
  int call({
    required List<int> id,
    Object? toId = ignore,
    Object? fromIsarId = ignore,
  }) {
    return collection.updateProperties(id, {
      if (toId != ignore) 1: toId as String?,
      if (fromIsarId != ignore) 2: fromIsarId as int?,
    });
  }
}

extension DiaryLinkIndexUpdate on IsarCollection<int, DiaryLinkIndex> {
  _DiaryLinkIndexUpdate get update => _DiaryLinkIndexUpdateImpl(this);

  _DiaryLinkIndexUpdateAll get updateAll => _DiaryLinkIndexUpdateAllImpl(this);
}

sealed class _DiaryLinkIndexQueryUpdate {
  int call({String? toId, int? fromIsarId});
}

class _DiaryLinkIndexQueryUpdateImpl implements _DiaryLinkIndexQueryUpdate {
  const _DiaryLinkIndexQueryUpdateImpl(this.query, {this.limit});

  final IsarQuery<DiaryLinkIndex> query;
  final int? limit;

  @override
  int call({Object? toId = ignore, Object? fromIsarId = ignore}) {
    return query.updateProperties(limit: limit, {
      if (toId != ignore) 1: toId as String?,
      if (fromIsarId != ignore) 2: fromIsarId as int?,
    });
  }
}

extension DiaryLinkIndexQueryUpdate on IsarQuery<DiaryLinkIndex> {
  _DiaryLinkIndexQueryUpdate get updateFirst =>
      _DiaryLinkIndexQueryUpdateImpl(this, limit: 1);

  _DiaryLinkIndexQueryUpdate get updateAll =>
      _DiaryLinkIndexQueryUpdateImpl(this);
}

class _DiaryLinkIndexQueryBuilderUpdateImpl
    implements _DiaryLinkIndexQueryUpdate {
  const _DiaryLinkIndexQueryBuilderUpdateImpl(this.query, {this.limit});

  final QueryBuilder<DiaryLinkIndex, DiaryLinkIndex, QOperations> query;
  final int? limit;

  @override
  int call({Object? toId = ignore, Object? fromIsarId = ignore}) {
    final q = query.build();
    try {
      return q.updateProperties(limit: limit, {
        if (toId != ignore) 1: toId as String?,
        if (fromIsarId != ignore) 2: fromIsarId as int?,
      });
    } finally {
      q.close();
    }
  }
}

extension DiaryLinkIndexQueryBuilderUpdate
    on QueryBuilder<DiaryLinkIndex, DiaryLinkIndex, QOperations> {
  _DiaryLinkIndexQueryUpdate get updateFirst =>
      _DiaryLinkIndexQueryBuilderUpdateImpl(this, limit: 1);

  _DiaryLinkIndexQueryUpdate get updateAll =>
      _DiaryLinkIndexQueryBuilderUpdateImpl(this);
}

extension DiaryLinkIndexQueryFilter
    on QueryBuilder<DiaryLinkIndex, DiaryLinkIndex, QFilterCondition> {
  QueryBuilder<DiaryLinkIndex, DiaryLinkIndex, QAfterFilterCondition> idEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<DiaryLinkIndex, DiaryLinkIndex, QAfterFilterCondition>
  idGreaterThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<DiaryLinkIndex, DiaryLinkIndex, QAfterFilterCondition>
  idGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<DiaryLinkIndex, DiaryLinkIndex, QAfterFilterCondition>
  idLessThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 0, value: value));
    });
  }

  QueryBuilder<DiaryLinkIndex, DiaryLinkIndex, QAfterFilterCondition>
  idLessThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<DiaryLinkIndex, DiaryLinkIndex, QAfterFilterCondition> idBetween(
    int lower,
    int upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 0, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<DiaryLinkIndex, DiaryLinkIndex, QAfterFilterCondition>
  toIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<DiaryLinkIndex, DiaryLinkIndex, QAfterFilterCondition>
  toIdGreaterThan(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<DiaryLinkIndex, DiaryLinkIndex, QAfterFilterCondition>
  toIdGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<DiaryLinkIndex, DiaryLinkIndex, QAfterFilterCondition>
  toIdLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<DiaryLinkIndex, DiaryLinkIndex, QAfterFilterCondition>
  toIdLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<DiaryLinkIndex, DiaryLinkIndex, QAfterFilterCondition>
  toIdBetween(String lower, String upper, {bool caseSensitive = true}) {
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

  QueryBuilder<DiaryLinkIndex, DiaryLinkIndex, QAfterFilterCondition>
  toIdStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<DiaryLinkIndex, DiaryLinkIndex, QAfterFilterCondition>
  toIdEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<DiaryLinkIndex, DiaryLinkIndex, QAfterFilterCondition>
  toIdContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<DiaryLinkIndex, DiaryLinkIndex, QAfterFilterCondition>
  toIdMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<DiaryLinkIndex, DiaryLinkIndex, QAfterFilterCondition>
  toIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<DiaryLinkIndex, DiaryLinkIndex, QAfterFilterCondition>
  toIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<DiaryLinkIndex, DiaryLinkIndex, QAfterFilterCondition>
  fromIsarIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 2, value: value),
      );
    });
  }

  QueryBuilder<DiaryLinkIndex, DiaryLinkIndex, QAfterFilterCondition>
  fromIsarIdGreaterThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 2, value: value),
      );
    });
  }

  QueryBuilder<DiaryLinkIndex, DiaryLinkIndex, QAfterFilterCondition>
  fromIsarIdGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 2, value: value),
      );
    });
  }

  QueryBuilder<DiaryLinkIndex, DiaryLinkIndex, QAfterFilterCondition>
  fromIsarIdLessThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 2, value: value));
    });
  }

  QueryBuilder<DiaryLinkIndex, DiaryLinkIndex, QAfterFilterCondition>
  fromIsarIdLessThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 2, value: value),
      );
    });
  }

  QueryBuilder<DiaryLinkIndex, DiaryLinkIndex, QAfterFilterCondition>
  fromIsarIdBetween(int lower, int upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 2, lower: lower, upper: upper),
      );
    });
  }
}

extension DiaryLinkIndexQueryObject
    on QueryBuilder<DiaryLinkIndex, DiaryLinkIndex, QFilterCondition> {}

extension DiaryLinkIndexQuerySortBy
    on QueryBuilder<DiaryLinkIndex, DiaryLinkIndex, QSortBy> {
  QueryBuilder<DiaryLinkIndex, DiaryLinkIndex, QAfterSortBy> sortById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<DiaryLinkIndex, DiaryLinkIndex, QAfterSortBy> sortByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<DiaryLinkIndex, DiaryLinkIndex, QAfterSortBy> sortByToId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DiaryLinkIndex, DiaryLinkIndex, QAfterSortBy> sortByToIdDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DiaryLinkIndex, DiaryLinkIndex, QAfterSortBy>
  sortByFromIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2);
    });
  }

  QueryBuilder<DiaryLinkIndex, DiaryLinkIndex, QAfterSortBy>
  sortByFromIsarIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc);
    });
  }
}

extension DiaryLinkIndexQuerySortThenBy
    on QueryBuilder<DiaryLinkIndex, DiaryLinkIndex, QSortThenBy> {
  QueryBuilder<DiaryLinkIndex, DiaryLinkIndex, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<DiaryLinkIndex, DiaryLinkIndex, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<DiaryLinkIndex, DiaryLinkIndex, QAfterSortBy> thenByToId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DiaryLinkIndex, DiaryLinkIndex, QAfterSortBy> thenByToIdDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DiaryLinkIndex, DiaryLinkIndex, QAfterSortBy>
  thenByFromIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2);
    });
  }

  QueryBuilder<DiaryLinkIndex, DiaryLinkIndex, QAfterSortBy>
  thenByFromIsarIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc);
    });
  }
}

extension DiaryLinkIndexQueryWhereDistinct
    on QueryBuilder<DiaryLinkIndex, DiaryLinkIndex, QDistinct> {
  QueryBuilder<DiaryLinkIndex, DiaryLinkIndex, QAfterDistinct> distinctByToId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DiaryLinkIndex, DiaryLinkIndex, QAfterDistinct>
  distinctByFromIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(2);
    });
  }
}

extension DiaryLinkIndexQueryProperty1
    on QueryBuilder<DiaryLinkIndex, DiaryLinkIndex, QProperty> {
  QueryBuilder<DiaryLinkIndex, int, QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<DiaryLinkIndex, String, QAfterProperty> toIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<DiaryLinkIndex, int, QAfterProperty> fromIsarIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }
}

extension DiaryLinkIndexQueryProperty2<R>
    on QueryBuilder<DiaryLinkIndex, R, QAfterProperty> {
  QueryBuilder<DiaryLinkIndex, (R, int), QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<DiaryLinkIndex, (R, String), QAfterProperty> toIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<DiaryLinkIndex, (R, int), QAfterProperty> fromIsarIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }
}

extension DiaryLinkIndexQueryProperty3<R1, R2>
    on QueryBuilder<DiaryLinkIndex, (R1, R2), QAfterProperty> {
  QueryBuilder<DiaryLinkIndex, (R1, R2, int), QOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<DiaryLinkIndex, (R1, R2, String), QOperations> toIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<DiaryLinkIndex, (R1, R2, int), QOperations>
  fromIsarIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }
}
