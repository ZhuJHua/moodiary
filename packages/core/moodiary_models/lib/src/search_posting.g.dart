// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_posting.dart';

// **************************************************************************
// _IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, invalid_use_of_protected_member, lines_longer_than_80_chars, constant_identifier_names, avoid_js_rounded_ints, no_leading_underscores_for_local_identifiers, require_trailing_commas, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_in_if_null_operators, library_private_types_in_public_api, prefer_const_constructors
// ignore_for_file: type=lint

extension GetSearchPostingCollection on Isar {
  IsarCollection<int, SearchPosting> get searchPostings => this.collection();
}

final SearchPostingSchema = IsarGeneratedSchema(
  schema: IsarSchema(
    name: 'SearchPosting',
    idName: 'key',
    embedded: false,
    properties: [
      IsarPropertySchema(name: 'diaryIsarIds', type: IsarType.longList),
    ],
    indexes: [],
  ),
  converter: IsarObjectConverter<int, SearchPosting>(
    serialize: serializeSearchPosting,
    deserialize: deserializeSearchPosting,
    deserializeProperty: deserializeSearchPostingProp,
  ),
  getEmbeddedSchemas: () => [],
);

@isarProtected
int serializeSearchPosting(IsarWriter writer, SearchPosting object) {
  {
    final list = object.diaryIsarIds;
    final listWriter = IsarCore.beginList(writer, 1, list.length);
    for (var i = 0; i < list.length; i++) {
      IsarCore.writeLong(listWriter, i, list[i]);
    }
    IsarCore.endList(writer, listWriter);
  }
  return object.key;
}

@isarProtected
SearchPosting deserializeSearchPosting(IsarReader reader) {
  final int _key;
  _key = IsarCore.readId(reader);
  final List<int> _diaryIsarIds;
  {
    final length = IsarCore.readList(reader, 1, IsarCore.readerPtrPtr);
    {
      final reader = IsarCore.readerPtr;
      if (reader.isNull) {
        _diaryIsarIds = const <int>[];
      } else {
        final list = List<int>.filled(
          length,
          -9223372036854775808,
          growable: true,
        );
        for (var i = 0; i < length; i++) {
          list[i] = IsarCore.readLong(reader, i);
        }
        IsarCore.freeReader(reader);
        _diaryIsarIds = list;
      }
    }
  }
  final object = SearchPosting(key: _key, diaryIsarIds: _diaryIsarIds);
  return object;
}

@isarProtected
dynamic deserializeSearchPostingProp(IsarReader reader, int property) {
  switch (property) {
    case 0:
      return IsarCore.readId(reader);
    case 1:
      {
        final length = IsarCore.readList(reader, 1, IsarCore.readerPtrPtr);
        {
          final reader = IsarCore.readerPtr;
          if (reader.isNull) {
            return const <int>[];
          } else {
            final list = List<int>.filled(
              length,
              -9223372036854775808,
              growable: true,
            );
            for (var i = 0; i < length; i++) {
              list[i] = IsarCore.readLong(reader, i);
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

extension SearchPostingQueryFilter
    on QueryBuilder<SearchPosting, SearchPosting, QFilterCondition> {
  QueryBuilder<SearchPosting, SearchPosting, QAfterFilterCondition> keyEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<SearchPosting, SearchPosting, QAfterFilterCondition>
  keyGreaterThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<SearchPosting, SearchPosting, QAfterFilterCondition>
  keyGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<SearchPosting, SearchPosting, QAfterFilterCondition> keyLessThan(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 0, value: value));
    });
  }

  QueryBuilder<SearchPosting, SearchPosting, QAfterFilterCondition>
  keyLessThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<SearchPosting, SearchPosting, QAfterFilterCondition> keyBetween(
    int lower,
    int upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 0, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<SearchPosting, SearchPosting, QAfterFilterCondition>
  diaryIsarIdsElementEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 1, value: value),
      );
    });
  }

  QueryBuilder<SearchPosting, SearchPosting, QAfterFilterCondition>
  diaryIsarIdsElementGreaterThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 1, value: value),
      );
    });
  }

  QueryBuilder<SearchPosting, SearchPosting, QAfterFilterCondition>
  diaryIsarIdsElementGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 1, value: value),
      );
    });
  }

  QueryBuilder<SearchPosting, SearchPosting, QAfterFilterCondition>
  diaryIsarIdsElementLessThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 1, value: value));
    });
  }

  QueryBuilder<SearchPosting, SearchPosting, QAfterFilterCondition>
  diaryIsarIdsElementLessThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 1, value: value),
      );
    });
  }

  QueryBuilder<SearchPosting, SearchPosting, QAfterFilterCondition>
  diaryIsarIdsElementBetween(int lower, int upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 1, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<SearchPosting, SearchPosting, QAfterFilterCondition>
  diaryIsarIdsIsEmpty() {
    return not().diaryIsarIdsIsNotEmpty();
  }

  QueryBuilder<SearchPosting, SearchPosting, QAfterFilterCondition>
  diaryIsarIdsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterOrEqualCondition(property: 1, value: null),
      );
    });
  }
}

extension SearchPostingQueryObject
    on QueryBuilder<SearchPosting, SearchPosting, QFilterCondition> {}

extension SearchPostingQuerySortBy
    on QueryBuilder<SearchPosting, SearchPosting, QSortBy> {
  QueryBuilder<SearchPosting, SearchPosting, QAfterSortBy> sortByKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<SearchPosting, SearchPosting, QAfterSortBy> sortByKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }
}

extension SearchPostingQuerySortThenBy
    on QueryBuilder<SearchPosting, SearchPosting, QSortThenBy> {
  QueryBuilder<SearchPosting, SearchPosting, QAfterSortBy> thenByKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<SearchPosting, SearchPosting, QAfterSortBy> thenByKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }
}

extension SearchPostingQueryWhereDistinct
    on QueryBuilder<SearchPosting, SearchPosting, QDistinct> {
  QueryBuilder<SearchPosting, SearchPosting, QAfterDistinct>
  distinctByDiaryIsarIds() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(1);
    });
  }
}

extension SearchPostingQueryProperty1
    on QueryBuilder<SearchPosting, SearchPosting, QProperty> {
  QueryBuilder<SearchPosting, int, QAfterProperty> keyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<SearchPosting, List<int>, QAfterProperty>
  diaryIsarIdsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }
}

extension SearchPostingQueryProperty2<R>
    on QueryBuilder<SearchPosting, R, QAfterProperty> {
  QueryBuilder<SearchPosting, (R, int), QAfterProperty> keyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<SearchPosting, (R, List<int>), QAfterProperty>
  diaryIsarIdsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }
}

extension SearchPostingQueryProperty3<R1, R2>
    on QueryBuilder<SearchPosting, (R1, R2), QAfterProperty> {
  QueryBuilder<SearchPosting, (R1, R2, int), QOperations> keyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<SearchPosting, (R1, R2, List<int>), QOperations>
  diaryIsarIdsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }
}
