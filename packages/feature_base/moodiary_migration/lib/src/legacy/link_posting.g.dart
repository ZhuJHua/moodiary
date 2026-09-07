// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'link_posting.dart';

// **************************************************************************
// _IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, invalid_use_of_protected_member, lines_longer_than_80_chars, constant_identifier_names, avoid_js_rounded_ints, no_leading_underscores_for_local_identifiers, require_trailing_commas, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_in_if_null_operators, library_private_types_in_public_api, prefer_const_constructors
// ignore_for_file: type=lint

extension GetLinkPostingCollection on Isar {
  IsarCollection<int, LinkPosting> get linkPostings => this.collection();
}

final LinkPostingSchema = IsarGeneratedSchema(
  schema: IsarSchema(
    name: 'LinkPosting',
    idName: 'key',
    embedded: false,
    properties: [
      IsarPropertySchema(name: 'fromIsarIds', type: IsarType.longList),
    ],
    indexes: [],
  ),
  converter: IsarObjectConverter<int, LinkPosting>(
    serialize: serializeLinkPosting,
    deserialize: deserializeLinkPosting,
    deserializeProperty: deserializeLinkPostingProp,
  ),
  getEmbeddedSchemas: () => [],
);

@isarProtected
int serializeLinkPosting(IsarWriter writer, LinkPosting object) {
  {
    final list = object.fromIsarIds;
    final listWriter = IsarCore.beginList(writer, 1, list.length);
    for (var i = 0; i < list.length; i++) {
      IsarCore.writeLong(listWriter, i, list[i]);
    }
    IsarCore.endList(writer, listWriter);
  }
  return object.key;
}

@isarProtected
LinkPosting deserializeLinkPosting(IsarReader reader) {
  final int _key;
  _key = IsarCore.readId(reader);
  final List<int> _fromIsarIds;
  {
    final length = IsarCore.readList(reader, 1, IsarCore.readerPtrPtr);
    {
      final reader = IsarCore.readerPtr;
      if (reader.isNull) {
        _fromIsarIds = const <int>[];
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
        _fromIsarIds = list;
      }
    }
  }
  final object = LinkPosting(key: _key, fromIsarIds: _fromIsarIds);
  return object;
}

@isarProtected
dynamic deserializeLinkPostingProp(IsarReader reader, int property) {
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

extension LinkPostingQueryFilter
    on QueryBuilder<LinkPosting, LinkPosting, QFilterCondition> {
  QueryBuilder<LinkPosting, LinkPosting, QAfterFilterCondition> keyEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<LinkPosting, LinkPosting, QAfterFilterCondition> keyGreaterThan(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<LinkPosting, LinkPosting, QAfterFilterCondition>
  keyGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<LinkPosting, LinkPosting, QAfterFilterCondition> keyLessThan(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 0, value: value));
    });
  }

  QueryBuilder<LinkPosting, LinkPosting, QAfterFilterCondition>
  keyLessThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<LinkPosting, LinkPosting, QAfterFilterCondition> keyBetween(
    int lower,
    int upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 0, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<LinkPosting, LinkPosting, QAfterFilterCondition>
  fromIsarIdsElementEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 1, value: value),
      );
    });
  }

  QueryBuilder<LinkPosting, LinkPosting, QAfterFilterCondition>
  fromIsarIdsElementGreaterThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 1, value: value),
      );
    });
  }

  QueryBuilder<LinkPosting, LinkPosting, QAfterFilterCondition>
  fromIsarIdsElementGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 1, value: value),
      );
    });
  }

  QueryBuilder<LinkPosting, LinkPosting, QAfterFilterCondition>
  fromIsarIdsElementLessThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 1, value: value));
    });
  }

  QueryBuilder<LinkPosting, LinkPosting, QAfterFilterCondition>
  fromIsarIdsElementLessThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 1, value: value),
      );
    });
  }

  QueryBuilder<LinkPosting, LinkPosting, QAfterFilterCondition>
  fromIsarIdsElementBetween(int lower, int upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 1, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<LinkPosting, LinkPosting, QAfterFilterCondition>
  fromIsarIdsIsEmpty() {
    return not().fromIsarIdsIsNotEmpty();
  }

  QueryBuilder<LinkPosting, LinkPosting, QAfterFilterCondition>
  fromIsarIdsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterOrEqualCondition(property: 1, value: null),
      );
    });
  }
}

extension LinkPostingQueryObject
    on QueryBuilder<LinkPosting, LinkPosting, QFilterCondition> {}

extension LinkPostingQuerySortBy
    on QueryBuilder<LinkPosting, LinkPosting, QSortBy> {
  QueryBuilder<LinkPosting, LinkPosting, QAfterSortBy> sortByKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<LinkPosting, LinkPosting, QAfterSortBy> sortByKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }
}

extension LinkPostingQuerySortThenBy
    on QueryBuilder<LinkPosting, LinkPosting, QSortThenBy> {
  QueryBuilder<LinkPosting, LinkPosting, QAfterSortBy> thenByKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<LinkPosting, LinkPosting, QAfterSortBy> thenByKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }
}

extension LinkPostingQueryWhereDistinct
    on QueryBuilder<LinkPosting, LinkPosting, QDistinct> {
  QueryBuilder<LinkPosting, LinkPosting, QAfterDistinct>
  distinctByFromIsarIds() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(1);
    });
  }
}

extension LinkPostingQueryProperty1
    on QueryBuilder<LinkPosting, LinkPosting, QProperty> {
  QueryBuilder<LinkPosting, int, QAfterProperty> keyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<LinkPosting, List<int>, QAfterProperty> fromIsarIdsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }
}

extension LinkPostingQueryProperty2<R>
    on QueryBuilder<LinkPosting, R, QAfterProperty> {
  QueryBuilder<LinkPosting, (R, int), QAfterProperty> keyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<LinkPosting, (R, List<int>), QAfterProperty>
  fromIsarIdsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }
}

extension LinkPostingQueryProperty3<R1, R2>
    on QueryBuilder<LinkPosting, (R1, R2), QAfterProperty> {
  QueryBuilder<LinkPosting, (R1, R2, int), QOperations> keyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<LinkPosting, (R1, R2, List<int>), QOperations>
  fromIsarIdsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }
}
