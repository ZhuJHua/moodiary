// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_stats.dart';

// **************************************************************************
// _IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, invalid_use_of_protected_member, lines_longer_than_80_chars, constant_identifier_names, avoid_js_rounded_ints, no_leading_underscores_for_local_identifiers, require_trailing_commas, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_in_if_null_operators, library_private_types_in_public_api, prefer_const_constructors
// ignore_for_file: type=lint

extension GetSearchStatsCollection on Isar {
  IsarCollection<int, SearchStats> get searchStats => this.collection();
}

final SearchStatsSchema = IsarGeneratedSchema(
  schema: IsarSchema(
    name: 'SearchStats',
    idName: 'id',
    embedded: false,
    properties: [
      IsarPropertySchema(name: 'docCount', type: IsarType.long),
      IsarPropertySchema(name: 'contentDocCount', type: IsarType.long),
      IsarPropertySchema(name: 'totalContentChars', type: IsarType.long),
    ],
    indexes: [],
  ),
  converter: IsarObjectConverter<int, SearchStats>(
    serialize: serializeSearchStats,
    deserialize: deserializeSearchStats,
    deserializeProperty: deserializeSearchStatsProp,
  ),
  getEmbeddedSchemas: () => [],
);

@isarProtected
int serializeSearchStats(IsarWriter writer, SearchStats object) {
  IsarCore.writeLong(writer, 1, object.docCount);
  IsarCore.writeLong(writer, 2, object.contentDocCount);
  IsarCore.writeLong(writer, 3, object.totalContentChars);
  return object.id;
}

@isarProtected
SearchStats deserializeSearchStats(IsarReader reader) {
  final int _id;
  _id = IsarCore.readId(reader);
  final int _docCount;
  _docCount = IsarCore.readLong(reader, 1);
  final int _contentDocCount;
  _contentDocCount = IsarCore.readLong(reader, 2);
  final int _totalContentChars;
  _totalContentChars = IsarCore.readLong(reader, 3);
  final object = SearchStats(
    id: _id,
    docCount: _docCount,
    contentDocCount: _contentDocCount,
    totalContentChars: _totalContentChars,
  );
  return object;
}

@isarProtected
dynamic deserializeSearchStatsProp(IsarReader reader, int property) {
  switch (property) {
    case 0:
      return IsarCore.readId(reader);
    case 1:
      return IsarCore.readLong(reader, 1);
    case 2:
      return IsarCore.readLong(reader, 2);
    case 3:
      return IsarCore.readLong(reader, 3);
    default:
      throw ArgumentError('Unknown property: $property');
  }
}

sealed class _SearchStatsUpdate {
  bool call({
    required int id,
    int? docCount,
    int? contentDocCount,
    int? totalContentChars,
  });
}

class _SearchStatsUpdateImpl implements _SearchStatsUpdate {
  const _SearchStatsUpdateImpl(this.collection);

  final IsarCollection<int, SearchStats> collection;

  @override
  bool call({
    required int id,
    Object? docCount = ignore,
    Object? contentDocCount = ignore,
    Object? totalContentChars = ignore,
  }) {
    return collection.updateProperties(
          [id],
          {
            if (docCount != ignore) 1: docCount as int?,
            if (contentDocCount != ignore) 2: contentDocCount as int?,
            if (totalContentChars != ignore) 3: totalContentChars as int?,
          },
        ) >
        0;
  }
}

sealed class _SearchStatsUpdateAll {
  int call({
    required List<int> id,
    int? docCount,
    int? contentDocCount,
    int? totalContentChars,
  });
}

class _SearchStatsUpdateAllImpl implements _SearchStatsUpdateAll {
  const _SearchStatsUpdateAllImpl(this.collection);

  final IsarCollection<int, SearchStats> collection;

  @override
  int call({
    required List<int> id,
    Object? docCount = ignore,
    Object? contentDocCount = ignore,
    Object? totalContentChars = ignore,
  }) {
    return collection.updateProperties(id, {
      if (docCount != ignore) 1: docCount as int?,
      if (contentDocCount != ignore) 2: contentDocCount as int?,
      if (totalContentChars != ignore) 3: totalContentChars as int?,
    });
  }
}

extension SearchStatsUpdate on IsarCollection<int, SearchStats> {
  _SearchStatsUpdate get update => _SearchStatsUpdateImpl(this);

  _SearchStatsUpdateAll get updateAll => _SearchStatsUpdateAllImpl(this);
}

sealed class _SearchStatsQueryUpdate {
  int call({int? docCount, int? contentDocCount, int? totalContentChars});
}

class _SearchStatsQueryUpdateImpl implements _SearchStatsQueryUpdate {
  const _SearchStatsQueryUpdateImpl(this.query, {this.limit});

  final IsarQuery<SearchStats> query;
  final int? limit;

  @override
  int call({
    Object? docCount = ignore,
    Object? contentDocCount = ignore,
    Object? totalContentChars = ignore,
  }) {
    return query.updateProperties(limit: limit, {
      if (docCount != ignore) 1: docCount as int?,
      if (contentDocCount != ignore) 2: contentDocCount as int?,
      if (totalContentChars != ignore) 3: totalContentChars as int?,
    });
  }
}

extension SearchStatsQueryUpdate on IsarQuery<SearchStats> {
  _SearchStatsQueryUpdate get updateFirst =>
      _SearchStatsQueryUpdateImpl(this, limit: 1);

  _SearchStatsQueryUpdate get updateAll => _SearchStatsQueryUpdateImpl(this);
}

class _SearchStatsQueryBuilderUpdateImpl implements _SearchStatsQueryUpdate {
  const _SearchStatsQueryBuilderUpdateImpl(this.query, {this.limit});

  final QueryBuilder<SearchStats, SearchStats, QOperations> query;
  final int? limit;

  @override
  int call({
    Object? docCount = ignore,
    Object? contentDocCount = ignore,
    Object? totalContentChars = ignore,
  }) {
    final q = query.build();
    try {
      return q.updateProperties(limit: limit, {
        if (docCount != ignore) 1: docCount as int?,
        if (contentDocCount != ignore) 2: contentDocCount as int?,
        if (totalContentChars != ignore) 3: totalContentChars as int?,
      });
    } finally {
      q.close();
    }
  }
}

extension SearchStatsQueryBuilderUpdate
    on QueryBuilder<SearchStats, SearchStats, QOperations> {
  _SearchStatsQueryUpdate get updateFirst =>
      _SearchStatsQueryBuilderUpdateImpl(this, limit: 1);

  _SearchStatsQueryUpdate get updateAll =>
      _SearchStatsQueryBuilderUpdateImpl(this);
}

extension SearchStatsQueryFilter
    on QueryBuilder<SearchStats, SearchStats, QFilterCondition> {
  QueryBuilder<SearchStats, SearchStats, QAfterFilterCondition> idEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<SearchStats, SearchStats, QAfterFilterCondition> idGreaterThan(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<SearchStats, SearchStats, QAfterFilterCondition>
  idGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<SearchStats, SearchStats, QAfterFilterCondition> idLessThan(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 0, value: value));
    });
  }

  QueryBuilder<SearchStats, SearchStats, QAfterFilterCondition>
  idLessThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<SearchStats, SearchStats, QAfterFilterCondition> idBetween(
    int lower,
    int upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 0, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<SearchStats, SearchStats, QAfterFilterCondition> docCountEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 1, value: value),
      );
    });
  }

  QueryBuilder<SearchStats, SearchStats, QAfterFilterCondition>
  docCountGreaterThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 1, value: value),
      );
    });
  }

  QueryBuilder<SearchStats, SearchStats, QAfterFilterCondition>
  docCountGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 1, value: value),
      );
    });
  }

  QueryBuilder<SearchStats, SearchStats, QAfterFilterCondition>
  docCountLessThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 1, value: value));
    });
  }

  QueryBuilder<SearchStats, SearchStats, QAfterFilterCondition>
  docCountLessThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 1, value: value),
      );
    });
  }

  QueryBuilder<SearchStats, SearchStats, QAfterFilterCondition> docCountBetween(
    int lower,
    int upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 1, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<SearchStats, SearchStats, QAfterFilterCondition>
  contentDocCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 2, value: value),
      );
    });
  }

  QueryBuilder<SearchStats, SearchStats, QAfterFilterCondition>
  contentDocCountGreaterThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 2, value: value),
      );
    });
  }

  QueryBuilder<SearchStats, SearchStats, QAfterFilterCondition>
  contentDocCountGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 2, value: value),
      );
    });
  }

  QueryBuilder<SearchStats, SearchStats, QAfterFilterCondition>
  contentDocCountLessThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 2, value: value));
    });
  }

  QueryBuilder<SearchStats, SearchStats, QAfterFilterCondition>
  contentDocCountLessThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 2, value: value),
      );
    });
  }

  QueryBuilder<SearchStats, SearchStats, QAfterFilterCondition>
  contentDocCountBetween(int lower, int upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 2, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<SearchStats, SearchStats, QAfterFilterCondition>
  totalContentCharsEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 3, value: value),
      );
    });
  }

  QueryBuilder<SearchStats, SearchStats, QAfterFilterCondition>
  totalContentCharsGreaterThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 3, value: value),
      );
    });
  }

  QueryBuilder<SearchStats, SearchStats, QAfterFilterCondition>
  totalContentCharsGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 3, value: value),
      );
    });
  }

  QueryBuilder<SearchStats, SearchStats, QAfterFilterCondition>
  totalContentCharsLessThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 3, value: value));
    });
  }

  QueryBuilder<SearchStats, SearchStats, QAfterFilterCondition>
  totalContentCharsLessThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 3, value: value),
      );
    });
  }

  QueryBuilder<SearchStats, SearchStats, QAfterFilterCondition>
  totalContentCharsBetween(int lower, int upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 3, lower: lower, upper: upper),
      );
    });
  }
}

extension SearchStatsQueryObject
    on QueryBuilder<SearchStats, SearchStats, QFilterCondition> {}

extension SearchStatsQuerySortBy
    on QueryBuilder<SearchStats, SearchStats, QSortBy> {
  QueryBuilder<SearchStats, SearchStats, QAfterSortBy> sortById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<SearchStats, SearchStats, QAfterSortBy> sortByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<SearchStats, SearchStats, QAfterSortBy> sortByDocCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1);
    });
  }

  QueryBuilder<SearchStats, SearchStats, QAfterSortBy> sortByDocCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc);
    });
  }

  QueryBuilder<SearchStats, SearchStats, QAfterSortBy> sortByContentDocCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2);
    });
  }

  QueryBuilder<SearchStats, SearchStats, QAfterSortBy>
  sortByContentDocCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc);
    });
  }

  QueryBuilder<SearchStats, SearchStats, QAfterSortBy>
  sortByTotalContentChars() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3);
    });
  }

  QueryBuilder<SearchStats, SearchStats, QAfterSortBy>
  sortByTotalContentCharsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc);
    });
  }
}

extension SearchStatsQuerySortThenBy
    on QueryBuilder<SearchStats, SearchStats, QSortThenBy> {
  QueryBuilder<SearchStats, SearchStats, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<SearchStats, SearchStats, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<SearchStats, SearchStats, QAfterSortBy> thenByDocCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1);
    });
  }

  QueryBuilder<SearchStats, SearchStats, QAfterSortBy> thenByDocCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc);
    });
  }

  QueryBuilder<SearchStats, SearchStats, QAfterSortBy> thenByContentDocCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2);
    });
  }

  QueryBuilder<SearchStats, SearchStats, QAfterSortBy>
  thenByContentDocCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc);
    });
  }

  QueryBuilder<SearchStats, SearchStats, QAfterSortBy>
  thenByTotalContentChars() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3);
    });
  }

  QueryBuilder<SearchStats, SearchStats, QAfterSortBy>
  thenByTotalContentCharsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc);
    });
  }
}

extension SearchStatsQueryWhereDistinct
    on QueryBuilder<SearchStats, SearchStats, QDistinct> {
  QueryBuilder<SearchStats, SearchStats, QAfterDistinct> distinctByDocCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(1);
    });
  }

  QueryBuilder<SearchStats, SearchStats, QAfterDistinct>
  distinctByContentDocCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(2);
    });
  }

  QueryBuilder<SearchStats, SearchStats, QAfterDistinct>
  distinctByTotalContentChars() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(3);
    });
  }
}

extension SearchStatsQueryProperty1
    on QueryBuilder<SearchStats, SearchStats, QProperty> {
  QueryBuilder<SearchStats, int, QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<SearchStats, int, QAfterProperty> docCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<SearchStats, int, QAfterProperty> contentDocCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<SearchStats, int, QAfterProperty> totalContentCharsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }
}

extension SearchStatsQueryProperty2<R>
    on QueryBuilder<SearchStats, R, QAfterProperty> {
  QueryBuilder<SearchStats, (R, int), QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<SearchStats, (R, int), QAfterProperty> docCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<SearchStats, (R, int), QAfterProperty>
  contentDocCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<SearchStats, (R, int), QAfterProperty>
  totalContentCharsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }
}

extension SearchStatsQueryProperty3<R1, R2>
    on QueryBuilder<SearchStats, (R1, R2), QAfterProperty> {
  QueryBuilder<SearchStats, (R1, R2, int), QOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<SearchStats, (R1, R2, int), QOperations> docCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<SearchStats, (R1, R2, int), QOperations>
  contentDocCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<SearchStats, (R1, R2, int), QOperations>
  totalContentCharsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }
}
