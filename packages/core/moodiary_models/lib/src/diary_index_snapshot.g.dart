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
      IsarPropertySchema(name: 'cutFreqs', type: IsarType.longList),
      IsarPropertySchema(name: 'cutForSearchTokens', type: IsarType.stringList),
      IsarPropertySchema(name: 'cutForSearchFreqs', type: IsarType.longList),
      IsarPropertySchema(name: 'titleTokens', type: IsarType.stringList),
      IsarPropertySchema(name: 'titleFreqs', type: IsarType.longList),
      IsarPropertySchema(name: 'linkToIds', type: IsarType.stringList),
      IsarPropertySchema(name: 'contentChars', type: IsarType.long),
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
    final list = object.cutFreqs;
    final listWriter = IsarCore.beginList(writer, 2, list.length);
    for (var i = 0; i < list.length; i++) {
      IsarCore.writeLong(listWriter, i, list[i]);
    }
    IsarCore.endList(writer, listWriter);
  }
  {
    final list = object.cutForSearchTokens;
    final listWriter = IsarCore.beginList(writer, 3, list.length);
    for (var i = 0; i < list.length; i++) {
      IsarCore.writeString(listWriter, i, list[i]);
    }
    IsarCore.endList(writer, listWriter);
  }
  {
    final list = object.cutForSearchFreqs;
    final listWriter = IsarCore.beginList(writer, 4, list.length);
    for (var i = 0; i < list.length; i++) {
      IsarCore.writeLong(listWriter, i, list[i]);
    }
    IsarCore.endList(writer, listWriter);
  }
  {
    final list = object.titleTokens;
    final listWriter = IsarCore.beginList(writer, 5, list.length);
    for (var i = 0; i < list.length; i++) {
      IsarCore.writeString(listWriter, i, list[i]);
    }
    IsarCore.endList(writer, listWriter);
  }
  {
    final list = object.titleFreqs;
    final listWriter = IsarCore.beginList(writer, 6, list.length);
    for (var i = 0; i < list.length; i++) {
      IsarCore.writeLong(listWriter, i, list[i]);
    }
    IsarCore.endList(writer, listWriter);
  }
  {
    final list = object.linkToIds;
    final listWriter = IsarCore.beginList(writer, 7, list.length);
    for (var i = 0; i < list.length; i++) {
      IsarCore.writeString(listWriter, i, list[i]);
    }
    IsarCore.endList(writer, listWriter);
  }
  IsarCore.writeLong(writer, 8, object.contentChars);
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
  final List<int> _cutFreqs;
  {
    final length = IsarCore.readList(reader, 2, IsarCore.readerPtrPtr);
    {
      final reader = IsarCore.readerPtr;
      if (reader.isNull) {
        _cutFreqs = const <int>[];
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
        _cutFreqs = list;
      }
    }
  }
  final List<String> _cutForSearchTokens;
  {
    final length = IsarCore.readList(reader, 3, IsarCore.readerPtrPtr);
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
  final List<int> _cutForSearchFreqs;
  {
    final length = IsarCore.readList(reader, 4, IsarCore.readerPtrPtr);
    {
      final reader = IsarCore.readerPtr;
      if (reader.isNull) {
        _cutForSearchFreqs = const <int>[];
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
        _cutForSearchFreqs = list;
      }
    }
  }
  final List<String> _titleTokens;
  {
    final length = IsarCore.readList(reader, 5, IsarCore.readerPtrPtr);
    {
      final reader = IsarCore.readerPtr;
      if (reader.isNull) {
        _titleTokens = const <String>[];
      } else {
        final list = List<String>.filled(length, '', growable: true);
        for (var i = 0; i < length; i++) {
          list[i] = IsarCore.readString(reader, i) ?? '';
        }
        IsarCore.freeReader(reader);
        _titleTokens = list;
      }
    }
  }
  final List<int> _titleFreqs;
  {
    final length = IsarCore.readList(reader, 6, IsarCore.readerPtrPtr);
    {
      final reader = IsarCore.readerPtr;
      if (reader.isNull) {
        _titleFreqs = const <int>[];
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
        _titleFreqs = list;
      }
    }
  }
  final List<String> _linkToIds;
  {
    final length = IsarCore.readList(reader, 7, IsarCore.readerPtrPtr);
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
  final int _contentChars;
  _contentChars = IsarCore.readLong(reader, 8);
  final object = DiaryIndexSnapshot(
    diaryIsarId: _diaryIsarId,
    cutTokens: _cutTokens,
    cutFreqs: _cutFreqs,
    cutForSearchTokens: _cutForSearchTokens,
    cutForSearchFreqs: _cutForSearchFreqs,
    titleTokens: _titleTokens,
    titleFreqs: _titleFreqs,
    linkToIds: _linkToIds,
    contentChars: _contentChars,
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
    case 4:
      {
        final length = IsarCore.readList(reader, 4, IsarCore.readerPtrPtr);
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
    case 6:
      {
        final length = IsarCore.readList(reader, 6, IsarCore.readerPtrPtr);
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
    case 7:
      {
        final length = IsarCore.readList(reader, 7, IsarCore.readerPtrPtr);
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
    case 8:
      return IsarCore.readLong(reader, 8);
    default:
      throw ArgumentError('Unknown property: $property');
  }
}

sealed class _DiaryIndexSnapshotUpdate {
  bool call({required int diaryIsarId, int? contentChars});
}

class _DiaryIndexSnapshotUpdateImpl implements _DiaryIndexSnapshotUpdate {
  const _DiaryIndexSnapshotUpdateImpl(this.collection);

  final IsarCollection<int, DiaryIndexSnapshot> collection;

  @override
  bool call({required int diaryIsarId, Object? contentChars = ignore}) {
    return collection.updateProperties(
          [diaryIsarId],
          {if (contentChars != ignore) 8: contentChars as int?},
        ) >
        0;
  }
}

sealed class _DiaryIndexSnapshotUpdateAll {
  int call({required List<int> diaryIsarId, int? contentChars});
}

class _DiaryIndexSnapshotUpdateAllImpl implements _DiaryIndexSnapshotUpdateAll {
  const _DiaryIndexSnapshotUpdateAllImpl(this.collection);

  final IsarCollection<int, DiaryIndexSnapshot> collection;

  @override
  int call({required List<int> diaryIsarId, Object? contentChars = ignore}) {
    return collection.updateProperties(diaryIsarId, {
      if (contentChars != ignore) 8: contentChars as int?,
    });
  }
}

extension DiaryIndexSnapshotUpdate on IsarCollection<int, DiaryIndexSnapshot> {
  _DiaryIndexSnapshotUpdate get update => _DiaryIndexSnapshotUpdateImpl(this);

  _DiaryIndexSnapshotUpdateAll get updateAll =>
      _DiaryIndexSnapshotUpdateAllImpl(this);
}

sealed class _DiaryIndexSnapshotQueryUpdate {
  int call({int? contentChars});
}

class _DiaryIndexSnapshotQueryUpdateImpl
    implements _DiaryIndexSnapshotQueryUpdate {
  const _DiaryIndexSnapshotQueryUpdateImpl(this.query, {this.limit});

  final IsarQuery<DiaryIndexSnapshot> query;
  final int? limit;

  @override
  int call({Object? contentChars = ignore}) {
    return query.updateProperties(limit: limit, {
      if (contentChars != ignore) 8: contentChars as int?,
    });
  }
}

extension DiaryIndexSnapshotQueryUpdate on IsarQuery<DiaryIndexSnapshot> {
  _DiaryIndexSnapshotQueryUpdate get updateFirst =>
      _DiaryIndexSnapshotQueryUpdateImpl(this, limit: 1);

  _DiaryIndexSnapshotQueryUpdate get updateAll =>
      _DiaryIndexSnapshotQueryUpdateImpl(this);
}

class _DiaryIndexSnapshotQueryBuilderUpdateImpl
    implements _DiaryIndexSnapshotQueryUpdate {
  const _DiaryIndexSnapshotQueryBuilderUpdateImpl(this.query, {this.limit});

  final QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QOperations> query;
  final int? limit;

  @override
  int call({Object? contentChars = ignore}) {
    final q = query.build();
    try {
      return q.updateProperties(limit: limit, {
        if (contentChars != ignore) 8: contentChars as int?,
      });
    } finally {
      q.close();
    }
  }
}

extension DiaryIndexSnapshotQueryBuilderUpdate
    on QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QOperations> {
  _DiaryIndexSnapshotQueryUpdate get updateFirst =>
      _DiaryIndexSnapshotQueryBuilderUpdateImpl(this, limit: 1);

  _DiaryIndexSnapshotQueryUpdate get updateAll =>
      _DiaryIndexSnapshotQueryBuilderUpdateImpl(this);
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
  cutFreqsElementEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 2, value: value),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  cutFreqsElementGreaterThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 2, value: value),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  cutFreqsElementGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 2, value: value),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  cutFreqsElementLessThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 2, value: value));
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  cutFreqsElementLessThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 2, value: value),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  cutFreqsElementBetween(int lower, int upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 2, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  cutFreqsIsEmpty() {
    return not().cutFreqsIsNotEmpty();
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  cutFreqsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterOrEqualCondition(property: 2, value: null),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  cutForSearchTokensElementEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 3, value: value, caseSensitive: caseSensitive),
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
          property: 3,
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
          property: 3,
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
        LessCondition(property: 3, value: value, caseSensitive: caseSensitive),
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
          property: 3,
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
          property: 3,
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
          property: 3,
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
          property: 3,
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
          property: 3,
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
          property: 3,
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
        const EqualCondition(property: 3, value: ''),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  cutForSearchTokensElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 3, value: ''),
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
        const GreaterOrEqualCondition(property: 3, value: null),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  cutForSearchFreqsElementEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 4, value: value),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  cutForSearchFreqsElementGreaterThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 4, value: value),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  cutForSearchFreqsElementGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 4, value: value),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  cutForSearchFreqsElementLessThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 4, value: value));
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  cutForSearchFreqsElementLessThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 4, value: value),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  cutForSearchFreqsElementBetween(int lower, int upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 4, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  cutForSearchFreqsIsEmpty() {
    return not().cutForSearchFreqsIsNotEmpty();
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  cutForSearchFreqsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterOrEqualCondition(property: 4, value: null),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  titleTokensElementEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 5, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  titleTokensElementGreaterThan(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  titleTokensElementGreaterThanOrEqualTo(
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

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  titleTokensElementLessThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 5, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  titleTokensElementLessThanOrEqualTo(
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

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  titleTokensElementBetween(
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

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  titleTokensElementStartsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  titleTokensElementEndsWith(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  titleTokensElementContains(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  titleTokensElementMatches(String pattern, {bool caseSensitive = true}) {
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

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  titleTokensElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 5, value: ''),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  titleTokensElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 5, value: ''),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  titleTokensIsEmpty() {
    return not().titleTokensIsNotEmpty();
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  titleTokensIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterOrEqualCondition(property: 5, value: null),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  titleFreqsElementEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 6, value: value),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  titleFreqsElementGreaterThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 6, value: value),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  titleFreqsElementGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 6, value: value),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  titleFreqsElementLessThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 6, value: value));
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  titleFreqsElementLessThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 6, value: value),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  titleFreqsElementBetween(int lower, int upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 6, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  titleFreqsIsEmpty() {
    return not().titleFreqsIsNotEmpty();
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  titleFreqsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterOrEqualCondition(property: 6, value: null),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  linkToIdsElementEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 7, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  linkToIdsElementGreaterThan(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 7,
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
          property: 7,
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
        LessCondition(property: 7, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  linkToIdsElementLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 7,
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
          property: 7,
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
          property: 7,
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
          property: 7,
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
          property: 7,
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
          property: 7,
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
        const EqualCondition(property: 7, value: ''),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  linkToIdsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 7, value: ''),
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
        const GreaterOrEqualCondition(property: 7, value: null),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  contentCharsEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 8, value: value),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  contentCharsGreaterThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 8, value: value),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  contentCharsGreaterThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 8, value: value),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  contentCharsLessThan(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 8, value: value));
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  contentCharsLessThanOrEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 8, value: value),
      );
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterFilterCondition>
  contentCharsBetween(int lower, int upper) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 8, lower: lower, upper: upper),
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

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterSortBy>
  sortByContentChars() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8);
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterSortBy>
  sortByContentCharsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8, sort: Sort.desc);
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

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterSortBy>
  thenByContentChars() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8);
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterSortBy>
  thenByContentCharsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(8, sort: Sort.desc);
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
  distinctByCutFreqs() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(2);
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterDistinct>
  distinctByCutForSearchTokens() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(3);
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterDistinct>
  distinctByCutForSearchFreqs() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(4);
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterDistinct>
  distinctByTitleTokens() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(5);
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterDistinct>
  distinctByTitleFreqs() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(6);
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterDistinct>
  distinctByLinkToIds() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(7);
    });
  }

  QueryBuilder<DiaryIndexSnapshot, DiaryIndexSnapshot, QAfterDistinct>
  distinctByContentChars() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(8);
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

  QueryBuilder<DiaryIndexSnapshot, List<int>, QAfterProperty>
  cutFreqsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<DiaryIndexSnapshot, List<String>, QAfterProperty>
  cutForSearchTokensProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<DiaryIndexSnapshot, List<int>, QAfterProperty>
  cutForSearchFreqsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<DiaryIndexSnapshot, List<String>, QAfterProperty>
  titleTokensProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<DiaryIndexSnapshot, List<int>, QAfterProperty>
  titleFreqsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<DiaryIndexSnapshot, List<String>, QAfterProperty>
  linkToIdsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }

  QueryBuilder<DiaryIndexSnapshot, int, QAfterProperty> contentCharsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(8);
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

  QueryBuilder<DiaryIndexSnapshot, (R, List<int>), QAfterProperty>
  cutFreqsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<DiaryIndexSnapshot, (R, List<String>), QAfterProperty>
  cutForSearchTokensProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<DiaryIndexSnapshot, (R, List<int>), QAfterProperty>
  cutForSearchFreqsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<DiaryIndexSnapshot, (R, List<String>), QAfterProperty>
  titleTokensProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<DiaryIndexSnapshot, (R, List<int>), QAfterProperty>
  titleFreqsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<DiaryIndexSnapshot, (R, List<String>), QAfterProperty>
  linkToIdsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }

  QueryBuilder<DiaryIndexSnapshot, (R, int), QAfterProperty>
  contentCharsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(8);
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

  QueryBuilder<DiaryIndexSnapshot, (R1, R2, List<int>), QOperations>
  cutFreqsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<DiaryIndexSnapshot, (R1, R2, List<String>), QOperations>
  cutForSearchTokensProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<DiaryIndexSnapshot, (R1, R2, List<int>), QOperations>
  cutForSearchFreqsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<DiaryIndexSnapshot, (R1, R2, List<String>), QOperations>
  titleTokensProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }

  QueryBuilder<DiaryIndexSnapshot, (R1, R2, List<int>), QOperations>
  titleFreqsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(6);
    });
  }

  QueryBuilder<DiaryIndexSnapshot, (R1, R2, List<String>), QOperations>
  linkToIdsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(7);
    });
  }

  QueryBuilder<DiaryIndexSnapshot, (R1, R2, int), QOperations>
  contentCharsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(8);
    });
  }
}
