// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diary_index_snapshot.dart';

// **************************************************************************
// _IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, invalid_use_of_protected_member, lines_longer_than_80_chars, constant_identifier_names, avoid_js_rounded_ints, no_leading_underscores_for_local_identifiers, require_trailing_commas, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_in_if_null_operators, library_private_types_in_public_api, prefer_const_constructors
// ignore_for_file: type=lint

extension GetDiaryIndexSnapshotCollection on Isar {
  IsarCollection<int, DiaryIndexSnapshot> get diaryIndexSnapshots =>
      this.collection();
}

final DiaryIndexSnapshotSchema = IsarGeneratedSchema(
  schema: IsarSchema(
    name: 'DiaryIndexSnapshot',
    idName: 'diaryIsarId',
    embedded: false,
    properties: [
      IsarPropertySchema(name: 'cutTokens', type: IsarType.stringList),
      IsarPropertySchema(name: 'cutForSearchTokens', type: IsarType.stringList),
      IsarPropertySchema(name: 'linkToIds', type: IsarType.stringList),
    ],
    indexes: [],
  ),
  converter: IsarObjectConverter<int, DiaryIndexSnapshot>(
    serialize: serializeDiaryIndexSnapshot,
    deserialize: deserializeDiaryIndexSnapshot,
    deserializeProperty: deserializeDiaryIndexSnapshotProp,
  ),
  getEmbeddedSchemas: () => [],
);

@isarProtected
int serializeDiaryIndexSnapshot(IsarWriter writer, DiaryIndexSnapshot object) {
  {
    final list = object.cutTokens;
    final listWriter = IsarCore.beginList(writer, 1, list.length);
    for (var i = 0; i < list.length; i++) {
      IsarCore.writeString(listWriter, i, list[i]);
    }
    IsarCore.endList(writer, listWriter);
  }
  {
    final list = object.cutForSearchTokens;
    final listWriter = IsarCore.beginList(writer, 2, list.length);
    for (var i = 0; i < list.length; i++) {
      IsarCore.writeString(listWriter, i, list[i]);
    }
    IsarCore.endList(writer, listWriter);
  }
  {
    final list = object.linkToIds;
    final listWriter = IsarCore.beginList(writer, 3, list.length);
    for (var i = 0; i < list.length; i++) {
      IsarCore.writeString(listWriter, i, list[i]);
    }
    IsarCore.endList(writer, listWriter);
  }
  return object.diaryIsarId;
}

@isarProtected
DiaryIndexSnapshot deserializeDiaryIndexSnapshot(IsarReader reader) {
  final int _diaryIsarId;
  _diaryIsarId = IsarCore.readId(reader);
  final List<String> _cutTokens;
  {
    final length = IsarCore.readList(reader, 1, IsarCore.readerPtrPtr);
    {
      final reader = IsarCore.readerPtr;
      if (reader.isNull) {
        _cutTokens = const <String>[];
      } else {
        final list = List<String>.filled(length, '', growable: true);
        for (var i = 0; i < length; i++) {
          list[i] = IsarCore.readString(reader, i) ?? '';
        }
        IsarCore.freeReader(reader);
        _cutTokens = list;
      }
    }
  }
  final List<String> _cutForSearchTokens;
  {
    final length = IsarCore.readList(reader, 2, IsarCore.readerPtrPtr);
    {
      final reader = IsarCore.readerPtr;
      if (reader.isNull) {
        _cutForSearchTokens = const <String>[];
      } else {
        final list = List<String>.filled(length, '', growable: true);
        for (var i = 0; i < length; i++) {
          list[i] = IsarCore.readString(reader, i) ?? '';
        }
        IsarCore.freeReader(reader);
        _cutForSearchTokens = list;
      }
    }
  }
  final List<String> _linkToIds;
  {
    final length = IsarCore.readList(reader, 3, IsarCore.readerPtrPtr);
    {
      final reader = IsarCore.readerPtr;
      if (reader.isNull) {
        _linkToIds = const <String>[];
      } else {
        final list = List<String>.filled(length, '', growable: true);
        for (var i = 0; i < length; i++) {
          list[i] = IsarCore.readString(reader, i) ?? '';
        }
        IsarCore.freeReader(reader);
        _linkToIds = list;
      }
    }
  }
  final object = DiaryIndexSnapshot(
    diaryIsarId: _diaryIsarId,
    cutTokens: _cutTokens,
    cutForSearchTokens: _cutForSearchTokens,
    linkToIds: _linkToIds,
  );
  return object;
}

@isarProtected
dynamic deserializeDiaryIndexSnapshotProp(IsarReader reader, int property) {
  switch (property) {
    case 0:
      return IsarCore.readId(reader);
    case 1:
      {
        final length = IsarCore.readList(reader, 1, IsarCore.readerPtrPtr);
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
    case 2:
      {
        final length = IsarCore.readList(reader, 2, IsarCore.readerPtrPtr);
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
    case 3:
      {
        final length = IsarCore.readList(reader, 3, IsarCore.readerPtrPtr);
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

extension DiaryIndexSnapshotQueryFilter
    on QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QFilterCondition> {
  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  diaryIsarIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  diaryIsarIdGreaterThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  diaryIsarIdGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  diaryIsarIdLessThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 0, value: value));
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  diaryIsarIdLessThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 0, value: value),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  diaryIsarIdBetween(int lower, int upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 0, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  cutTokensElementEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  cutTokensElementGreaterThan(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  cutTokensElementGreaterThanOrEqualTo(
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

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  cutTokensElementLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  cutTokensElementLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  cutTokensElementBetween(
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

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  cutTokensElementStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  cutTokensElementEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  cutTokensElementContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  cutTokensElementMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  cutTokensElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  cutTokensElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  cutTokensIsEmpty() {
    return not().cutTokensIsNotEmpty();
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  cutTokensIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterOrEqualCondition(property: 1, value: null),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  cutForSearchTokensElementEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 2, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  cutForSearchTokensElementGreaterThan(
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

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  cutForSearchTokensElementGreaterThanOrEqualTo(
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

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  cutForSearchTokensElementLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 2, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  cutForSearchTokensElementLessThanOrEqualTo(
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

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  cutForSearchTokensElementBetween(
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

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  cutForSearchTokensElementStartsWith(
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

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  cutForSearchTokensElementEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  cutForSearchTokensElementContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  cutForSearchTokensElementMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  cutForSearchTokensElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 2, value: ''),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  cutForSearchTokensElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 2, value: ''),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  cutForSearchTokensIsEmpty() {
    return not().cutForSearchTokensIsNotEmpty();
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  cutForSearchTokensIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterOrEqualCondition(property: 2, value: null),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  linkToIdsElementEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 3, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  linkToIdsElementGreaterThan(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  linkToIdsElementGreaterThanOrEqualTo(
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

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  linkToIdsElementLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 3, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  linkToIdsElementLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  linkToIdsElementBetween(
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

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  linkToIdsElementStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  linkToIdsElementEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  linkToIdsElementContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  linkToIdsElementMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  linkToIdsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 3, value: ''),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  linkToIdsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 3, value: ''),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  linkToIdsIsEmpty() {
    return not().linkToIdsIsNotEmpty();
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  linkToIdsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterOrEqualCondition(property: 3, value: null),
      );
    });
  }
}

extension DiaryIndexSnapshotQueryObject
    on QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QFilterCondition> {}

extension DiaryIndexSnapshotQuerySortBy
    on QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QSortBy> {
  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterSortBy>
  sortByDiaryIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterSortBy>
  sortByDiaryIsarIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }
}

extension DiaryIndexSnapshotQuerySortThenBy
    on QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QSortThenBy> {
  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterSortBy>
  thenByDiaryIsarId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterSortBy>
  thenByDiaryIsarIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }
}

extension DiaryIndexSnapshotQueryWhereDistinct
    on QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QDistinct> {
  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterDistinct>
  distinctByCutTokens() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(1);
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterDistinct>
  distinctByCutForSearchTokens() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(2);
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterDistinct>
  distinctByLinkToIds() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(3);
    });
  }
}

extension DiaryIndexSnapshotQueryProperty1
    on QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QProperty> {
  QueryBuilder<DiaryIndexSnapshot, int, QAfterProperty> diaryIsarIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<DiaryIndexSnapshot, List<String>, QAfterProperty>
  cutTokensProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<DiaryIndexSnapshot, List<String>, QAfterProperty>
  cutForSearchTokensProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<DiaryIndexSnapshot, List<String>, QAfterProperty>
  linkToIdsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }
}

extension DiaryIndexSnapshotQueryProperty2<R>
    on QueryBuilder<DiaryIndexSnapshot, R, QAfterProperty> {
  QueryBuilder<DiaryIndexSnapshot, (R, int), QAfterProperty>
  diaryIsarIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<DiaryIndexSnapshot, (R, List<String>), QAfterProperty>
  cutTokensProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<DiaryIndexSnapshot, (R, List<String>), QAfterProperty>
  cutForSearchTokensProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<DiaryIndexSnapshot, (R, List<String>), QAfterProperty>
  linkToIdsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }
}

extension DiaryIndexSnapshotQueryProperty3<R1, R2>
    on QueryBuilder<DiaryIndexSnapshot, (R1, R2), QAfterProperty> {
  QueryBuilder<DiaryIndexSnapshot, (R1, R2, int), QOperations>
  diaryIsarIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<DiaryIndexSnapshot, (R1, R2, List<String>), QOperations>
  cutTokensProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<DiaryIndexSnapshot, (R1, R2, List<String>), QOperations>
  cutForSearchTokensProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<DiaryIndexSnapshot, (R1, R2, List<String>), QOperations>
  linkToIdsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }
}
