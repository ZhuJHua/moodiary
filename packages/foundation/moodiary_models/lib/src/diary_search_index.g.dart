// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diary_search_index.dart';

// **************************************************************************
// _IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, invalid_use_of_protected_member, lines_longer_than_80_chars, constant_identifier_names, avoid_js_rounded_ints, no_leading_underscores_for_local_identifiers, require_trailing_commas, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_in_if_null_operators, library_private_types_in_public_api, prefer_const_constructors
// ignore_for_file: type=lint

extension GetDiarySearchIndexCollection on Isar {
  IsarCollection<int, DiarySearchIndex> get diarySearchIndexs =>
      this.collection();
}

final DiarySearchIndexSchema = IsarGeneratedSchema(
  schema: IsarSchema(
    name: 'DiarySearchIndex',
    idName: 'id',
    embedded: false,
    properties: [
      IsarPropertySchema(name: 'token', type: IsarType.string),
      IsarPropertySchema(name: 'diaryIsarId', type: IsarType.long),
      IsarPropertySchema(
        name: 'source',
        type: IsarType.byte,

        enumMap: {"cut": 0, "cutForSearch": 1},
      ),
    ],
    indexes: [
      IsarIndexSchema(
        name: 'token',
        properties: ["token"],
        unique: false,
        hash: true,
      ),
    ],
  ),
  converter: IsarObjectConverter<int, DiarySearchIndex>(
    serialize: serializeDiarySearchIndex,
    deserialize: deserializeDiarySearchIndex,
    deserializeProperty: deserializeDiarySearchIndexProp,
  ),
  getEmbeddedSchemas: () => [],
);

@isarProtected
int serializeDiarySearchIndex(IsarWriter writer, DiarySearchIndex object) {
  IsarCore.writeString(writer, 1, object.token);
  IsarCore.writeLong(writer, 2, object.diaryIsarId);
  IsarCore.writeByte(writer, 3, object.source.index);
  return object.id;
}

@isarProtected
DiarySearchIndex deserializeDiarySearchIndex(IsarReader reader) {
  final int _id;
  _id = IsarCore.readId(reader);
  final String _token;
  _token = IsarCore.readString(reader, 1) ?? '';
  final int _diaryIsarId;
  _diaryIsarId = IsarCore.readLong(reader, 2);
  final TokenSource _source;
  {
    if (IsarCore.readNull(reader, 3)) {
      _source = TokenSource.cut;
    } else {
      _source =
          _diarySearchIndexSource[IsarCore.readByte(reader, 3)] ??
          TokenSource.cut;
    }
  }
  final object = DiarySearchIndex(
    id: _id,
    token: _token,
    diaryIsarId: _diaryIsarId,
    source: _source,
  );
  return object;
}

@isarProtected
dynamic deserializeDiarySearchIndexProp(IsarReader reader, int property) {
  switch (property) {
    case 0:
      return IsarCore.readId(reader);
    case 1:
      return IsarCore.readString(reader, 1) ?? '';
    case 2:
      return IsarCore.readLong(reader, 2);
    case 3:
      {
        if (IsarCore.readNull(reader, 3)) {
          return TokenSource.cut;
        } else {
          return _diarySearchIndexSource[IsarCore.readByte(reader, 3)] ??
              TokenSource.cut;
        }
      }
    default:
      throw ArgumentError('Unknown property: $property');
  }
}

sealed class _DiarySearchIndexUpdate {
  bool call({
    required int id,
    String? token,
    int? diaryIsarId,
    TokenSource? source,
  });
}

class _DiarySearchIndexUpdateImpl implements _DiarySearchIndexUpdate {
  const _DiarySearchIndexUpdateImpl(this.collection);

  final IsarCollection<int, DiarySearchIndex> collection;

  @override
  bool call({
    required int id,
    Object? token = ignore,
    Object? diaryIsarId = ignore,
    Object? source = ignore,
  }) {
    return collection.updateProperties(
          [id],
          {
            if (token != ignore) 1: token as String?,
            if (diaryIsarId != ignore) 2: diaryIsarId as int?,
            if (source != ignore) 3: source as TokenSource?,
          },
        ) >
        0;
  }
}

sealed class _DiarySearchIndexUpdateAll {
  int call({
    required List<int> id,
    String? token,
    int? diaryIsarId,
    TokenSource? source,
  });
}

class _DiarySearchIndexUpdateAllImpl implements _DiarySearchIndexUpdateAll {
  const _DiarySearchIndexUpdateAllImpl(this.collection);

  final IsarCollection<int, DiarySearchIndex> collection;

  @override
  int call({
    required List<int> id,
    Object? token = ignore,
    Object? diaryIsarId = ignore,
    Object? source = ignore,
  }) {
    return collection.updateProperties(id, {
      if (token != ignore) 1: token as String?,
      if (diaryIsarId != ignore) 2: diaryIsarId as int?,
      if (source != ignore) 3: source as TokenSource?,
    });
  }
}

extension DiarySearchIndexUpdate on IsarCollection<int, DiarySearchIndex> {
  _DiarySearchIndexUpdate get update => _DiarySearchIndexUpdateImpl(this);

  _DiarySearchIndexUpdateAll get updateAll =>
      _DiarySearchIndexUpdateAllImpl(this);
}

sealed class _DiarySearchIndexQueryUpdate {
  int call({String? token, int? diaryIsarId, TokenSource? source});
}

class _DiarySearchIndexQueryUpdateImpl implements _DiarySearchIndexQueryUpdate {
  const _DiarySearchIndexQueryUpdateImpl(this.query, {this.limit});

  final IsarQuery<DiarySearchIndex> query;
  final int? limit;

  @override
  int call({
    Object? token = ignore,
    Object? diaryIsarId = ignore,
    Object? source = ignore,
  }) {
    return query.updateProperties(limit: limit, {
      if (token != ignore) 1: token as String?,
      if (diaryIsarId != ignore) 2: diaryIsarId as int?,
      if (source != ignore) 3: source as TokenSource?,
    });
  }
}

extension DiarySearchIndexQueryUpdate on IsarQuery<DiarySearchIndex> {
  _DiarySearchIndexQueryUpdate get updateFirst =>
      _DiarySearchIndexQueryUpdateImpl(this, limit: 1);

  _DiarySearchIndexQueryUpdate get updateAll =>
      _DiarySearchIndexQueryUpdateImpl(this);
}

class _DiarySearchIndexQueryBuilderUpdateImpl
    implements _DiarySearchIndexQueryUpdate {
  const _DiarySearchIndexQueryBuilderUpdateImpl(this.query, {this.limit});

  final QueryBuilder<DiarySearchIndex, DiarySearchIndex, QOperations> query;
  final int? limit;

  @override
  int call({
    Object? token = ignore,
    Object? diaryIsarId = ignore,
    Object? source = ignore,
  }) {
    final q = query.build();
    try {
      return q.updateProperties(limit: limit, {
        if (token != ignore) 1: token as String?,
        if (diaryIsarId != ignore) 2: diaryIsarId as int?,
        if (source != ignore) 3: source as TokenSource?,
      });
    } finally {
      q.close();
    }
  }
}

extension DiarySearchIndexQueryBuilderUpdate
    on QueryBuilder<DiarySearchIndex, DiarySearchIndex, QOperations> {
  _DiarySearchIndexQueryUpdate get updateFirst =>
      _DiarySearchIndexQueryBuilderUpdateImpl(this, limit: 1);

  _DiarySearchIndexQueryUpdate get updateAll =>
      _DiarySearchIndexQueryBuilderUpdateImpl(this);
}

const _diarySearchIndexSource = {
  0: TokenSource.cut,
  1: TokenSource.cutForSearch,
};

extension DiarySearchIndexQueryFilter
    on QueryBuilder<DiarySearchIndex, DiarySearchIndex, QFilterCondition> {
  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterFilterCondition>
  idEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterFilterCondition>
  idGreaterThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterFilterCondition>
  idGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterFilterCondition>
  idLessThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 0, value: value));
    });
  }

  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterFilterCondition>
  idLessThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterFilterCondition>
  idBetween(int lower, int upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 0, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterFilterCondition>
  tokenEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterFilterCondition>
  tokenGreaterThan(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterFilterCondition>
  tokenGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterFilterCondition>
  tokenLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterFilterCondition>
  tokenLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterFilterCondition>
  tokenBetween(String lower, String upper, {bool caseSensitive = true}) {
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

  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterFilterCondition>
  tokenStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterFilterCondition>
  tokenEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterFilterCondition>
  tokenContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterFilterCondition>
  tokenMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterFilterCondition>
  tokenIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterFilterCondition>
  tokenIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterFilterCondition>
  diaryIsarIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 2, value: value),
      );
    });
  }

  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterFilterCondition>
  diaryIsarIdGreaterThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 2, value: value),
      );
    });
  }

  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterFilterCondition>
  diaryIsarIdGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 2, value: value),
      );
    });
  }

  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterFilterCondition>
  diaryIsarIdLessThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 2, value: value));
    });
  }

  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterFilterCondition>
  diaryIsarIdLessThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 2, value: value),
      );
    });
  }

  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterFilterCondition>
  diaryIsarIdBetween(int lower, int upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 2, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterFilterCondition>
  sourceEqualTo(TokenSource value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 3, value: value.index),
      );
    });
  }

  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterFilterCondition>
  sourceGreaterThan(TokenSource value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 3, value: value.index),
      );
    });
  }

  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterFilterCondition>
  sourceGreaterThanOrEqualTo(TokenSource value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 3, value: value.index),
      );
    });
  }

  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterFilterCondition>
  sourceLessThan(TokenSource value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 3, value: value.index),
      );
    });
  }

  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterFilterCondition>
  sourceLessThanOrEqualTo(TokenSource value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 3, value: value.index),
      );
    });
  }

  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterFilterCondition>
  sourceBetween(TokenSource lower, TokenSource upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 3, lower: lower.index, upper: upper.index),
      );
    });
  }
}

extension DiarySearchIndexQueryObject
    on QueryBuilder<DiarySearchIndex, DiarySearchIndex, QFilterCondition> {}

extension DiarySearchIndexQuerySortBy
    on QueryBuilder<DiarySearchIndex, DiarySearchIndex, QSortBy> {
  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterSortBy> sortById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterSortBy>
  sortByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterSortBy> sortByToken({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterSortBy>
  sortByTokenDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterSortBy>
  sortByDiaryIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2);
    });
  }

  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterSortBy>
  sortByDiaryIsarIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc);
    });
  }

  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterSortBy>
  sortBySource() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3);
    });
  }

  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterSortBy>
  sortBySourceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc);
    });
  }
}

extension DiarySearchIndexQuerySortThenBy
    on QueryBuilder<DiarySearchIndex, DiarySearchIndex, QSortThenBy> {
  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterSortBy> thenByToken({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterSortBy>
  thenByTokenDesc({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterSortBy>
  thenByDiaryIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2);
    });
  }

  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterSortBy>
  thenByDiaryIsarIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc);
    });
  }

  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterSortBy>
  thenBySource() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3);
    });
  }

  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterSortBy>
  thenBySourceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc);
    });
  }
}

extension DiarySearchIndexQueryWhereDistinct
    on QueryBuilder<DiarySearchIndex, DiarySearchIndex, QDistinct> {
  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterDistinct>
  distinctByToken({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterDistinct>
  distinctByDiaryIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(2);
    });
  }

  QueryBuilder<DiarySearchIndex, DiarySearchIndex, QAfterDistinct>
  distinctBySource() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(3);
    });
  }
}

extension DiarySearchIndexQueryProperty1
    on QueryBuilder<DiarySearchIndex, DiarySearchIndex, QProperty> {
  QueryBuilder<DiarySearchIndex, int, QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<DiarySearchIndex, String, QAfterProperty> tokenProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<DiarySearchIndex, int, QAfterProperty> diaryIsarIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<DiarySearchIndex, TokenSource, QAfterProperty> sourceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }
}

extension DiarySearchIndexQueryProperty2<R>
    on QueryBuilder<DiarySearchIndex, R, QAfterProperty> {
  QueryBuilder<DiarySearchIndex, (R, int), QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<DiarySearchIndex, (R, String), QAfterProperty> tokenProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<DiarySearchIndex, (R, int), QAfterProperty>
  diaryIsarIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<DiarySearchIndex, (R, TokenSource), QAfterProperty>
  sourceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }
}

extension DiarySearchIndexQueryProperty3<R1, R2>
    on QueryBuilder<DiarySearchIndex, (R1, R2), QAfterProperty> {
  QueryBuilder<DiarySearchIndex, (R1, R2, int), QOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<DiarySearchIndex, (R1, R2, String), QOperations>
  tokenProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<DiarySearchIndex, (R1, R2, int), QOperations>
  diaryIsarIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<DiarySearchIndex, (R1, R2, TokenSource), QOperations>
  sourceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }
}
