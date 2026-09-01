// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reindex_queue.dart';

// **************************************************************************
// _IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, invalid_use_of_protected_member, lines_longer_than_80_chars, constant_identifier_names, avoid_js_rounded_ints, no_leading_underscores_for_local_identifiers, require_trailing_commas, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_in_if_null_operators, library_private_types_in_public_api, prefer_const_constructors
// ignore_for_file: type=lint

extension GetReindexQueueCollection on Isar {
  IsarCollection<int, ReindexQueue> get reindexQueues => this.collection();
}

final ReindexQueueSchema = IsarGeneratedSchema(
  schema: IsarSchema(
    name: 'ReindexQueue',
    idName: 'diaryIsarId',
    embedded: false,
    properties: [],
    indexes: [],
  ),
  converter: IsarObjectConverter<int, ReindexQueue>(
    serialize: serializeReindexQueue,
    deserialize: deserializeReindexQueue,
    deserializeProperty: deserializeReindexQueueProp,
  ),
  getEmbeddedSchemas: () => [],
);

@isarProtected
int serializeReindexQueue(IsarWriter writer, ReindexQueue object) {
  return object.diaryIsarId;
}

@isarProtected
ReindexQueue deserializeReindexQueue(IsarReader reader) {
  final int _diaryIsarId;
  _diaryIsarId = IsarCore.readId(reader);
  final object = ReindexQueue(diaryIsarId: _diaryIsarId);
  return object;
}

@isarProtected
dynamic deserializeReindexQueueProp(IsarReader reader, int property) {
  switch (property) {
    case 0:
      return IsarCore.readId(reader);
    default:
      throw ArgumentError('Unknown property: $property');
  }
}

extension ReindexQueueQueryFilter
    on QueryBuilder<ReindexQueue, ReindexQueue, QFilterCondition> {
  QueryBuilder<ReindexQueue, ReindexQueue, QAfterFilterCondition>
  diaryIsarIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<ReindexQueue, ReindexQueue, QAfterFilterCondition>
  diaryIsarIdGreaterThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<ReindexQueue, ReindexQueue, QAfterFilterCondition>
  diaryIsarIdGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<ReindexQueue, ReindexQueue, QAfterFilterCondition>
  diaryIsarIdLessThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 0, value: value));
    });
  }

  QueryBuilder<ReindexQueue, ReindexQueue, QAfterFilterCondition>
  diaryIsarIdLessThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<ReindexQueue, ReindexQueue, QAfterFilterCondition>
  diaryIsarIdBetween(int lower, int upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 0, lower: lower, upper: upper),
      );
    });
  }
}

extension ReindexQueueQueryObject
    on QueryBuilder<ReindexQueue, ReindexQueue, QFilterCondition> {}

extension ReindexQueueQuerySortBy
    on QueryBuilder<ReindexQueue, ReindexQueue, QSortBy> {
  QueryBuilder<ReindexQueue, ReindexQueue, QAfterSortBy> sortByDiaryIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<ReindexQueue, ReindexQueue, QAfterSortBy>
  sortByDiaryIsarIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }
}

extension ReindexQueueQuerySortThenBy
    on QueryBuilder<ReindexQueue, ReindexQueue, QSortThenBy> {
  QueryBuilder<ReindexQueue, ReindexQueue, QAfterSortBy> thenByDiaryIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<ReindexQueue, ReindexQueue, QAfterSortBy>
  thenByDiaryIsarIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }
}

extension ReindexQueueQueryWhereDistinct
    on QueryBuilder<ReindexQueue, ReindexQueue, QDistinct> {}

extension ReindexQueueQueryProperty1
    on QueryBuilder<ReindexQueue, ReindexQueue, QProperty> {
  QueryBuilder<ReindexQueue, int, QAfterProperty> diaryIsarIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }
}

extension ReindexQueueQueryProperty2<R>
    on QueryBuilder<ReindexQueue, R, QAfterProperty> {
  QueryBuilder<ReindexQueue, (R, int), QAfterProperty> diaryIsarIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }
}

extension ReindexQueueQueryProperty3<R1, R2>
    on QueryBuilder<ReindexQueue, (R1, R2), QAfterProperty> {
  QueryBuilder<ReindexQueue, (R1, R2, int), QOperations> diaryIsarIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }
}
