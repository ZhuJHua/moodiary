// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_info.dart';

// **************************************************************************
// _IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, invalid_use_of_protected_member, lines_longer_than_80_chars, constant_identifier_names, avoid_js_rounded_ints, no_leading_underscores_for_local_identifiers, require_trailing_commas, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_in_if_null_operators, library_private_types_in_public_api, prefer_const_constructors
// ignore_for_file: type=lint

extension GetMediaInfoCollection on Isar {
  IsarCollection<String, MediaInfo> get mediaInfos => this.collection();
}

final MediaInfoSchema = IsarGeneratedSchema(
  schema: IsarSchema(
    name: 'MediaInfo',
    idName: 'fileName',
    embedded: false,
    properties: [
      IsarPropertySchema(name: 'mediaType', type: IsarType.string),
      IsarPropertySchema(name: 'fileName', type: IsarType.string),
      IsarPropertySchema(name: 'name', type: IsarType.string),
      IsarPropertySchema(name: 'durationMs', type: IsarType.long),
      IsarPropertySchema(name: 'lastModified', type: IsarType.dateTime),
    ],
    indexes: [],
  ),
  converter: IsarObjectConverter<String, MediaInfo>(
    serialize: serializeMediaInfo,
    deserialize: deserializeMediaInfo,
    deserializeProperty: deserializeMediaInfoProp,
  ),
  getEmbeddedSchemas: () => [],
);

@isarProtected
int serializeMediaInfo(IsarWriter writer, MediaInfo object) {
  IsarCore.writeString(writer, 1, object.mediaType);
  IsarCore.writeString(writer, 2, object.fileName);
  {
    final value = object.name;
    if (value == null) {
      IsarCore.writeNull(writer, 3);
    } else {
      IsarCore.writeString(writer, 3, value);
    }
  }
  IsarCore.writeLong(writer, 4, object.durationMs ?? -9223372036854775808);
  IsarCore.writeLong(
    writer,
    5,
    object.lastModified.toUtc().microsecondsSinceEpoch,
  );
  return Isar.fastHash(object.fileName);
}

@isarProtected
MediaInfo deserializeMediaInfo(IsarReader reader) {
  final String _fileName;
  _fileName = IsarCore.readString(reader, 2) ?? '';
  final String? _name;
  _name = IsarCore.readString(reader, 3);
  final int? _durationMs;
  {
    final value = IsarCore.readLong(reader, 4);
    if (value == -9223372036854775808) {
      _durationMs = null;
    } else {
      _durationMs = value;
    }
  }
  final DateTime _lastModified;
  {
    final value = IsarCore.readLong(reader, 5);
    if (value == -9223372036854775808) {
      _lastModified = DateTime.fromMillisecondsSinceEpoch(
        0,
        isUtc: true,
      ).toLocal();
    } else {
      _lastModified = DateTime.fromMicrosecondsSinceEpoch(
        value,
        isUtc: true,
      ).toLocal();
    }
  }
  final object = MediaInfo(
    fileName: _fileName,
    name: _name,
    durationMs: _durationMs,
    lastModified: _lastModified,
  );
  return object;
}

@isarProtected
dynamic deserializeMediaInfoProp(IsarReader reader, int property) {
  switch (property) {
    case 1:
      return IsarCore.readString(reader, 1) ?? '';
    case 2:
      return IsarCore.readString(reader, 2) ?? '';
    case 3:
      return IsarCore.readString(reader, 3);
    case 4:
      {
        final value = IsarCore.readLong(reader, 4);
        if (value == -9223372036854775808) {
          return null;
        } else {
          return value;
        }
      }
    case 5:
      {
        final value = IsarCore.readLong(reader, 5);
        if (value == -9223372036854775808) {
          return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toLocal();
        } else {
          return DateTime.fromMicrosecondsSinceEpoch(
            value,
            isUtc: true,
          ).toLocal();
        }
      }
    default:
      throw ArgumentError('Unknown property: $property');
  }
}

sealed class _MediaInfoUpdate {
  bool call({
    required String fileName,
    String? mediaType,
    String? name,
    int? durationMs,
    DateTime? lastModified,
  });
}

class _MediaInfoUpdateImpl implements _MediaInfoUpdate {
  const _MediaInfoUpdateImpl(this.collection);

  final IsarCollection<String, MediaInfo> collection;

  @override
  bool call({
    required String fileName,
    Object? mediaType = ignore,
    Object? name = ignore,
    Object? durationMs = ignore,
    Object? lastModified = ignore,
  }) {
    return collection.updateProperties(
          [fileName],
          {
            if (mediaType != ignore) 1: mediaType as String?,
            if (name != ignore) 3: name as String?,
            if (durationMs != ignore) 4: durationMs as int?,
            if (lastModified != ignore) 5: lastModified as DateTime?,
          },
        ) >
        0;
  }
}

sealed class _MediaInfoUpdateAll {
  int call({
    required List<String> fileName,
    String? mediaType,
    String? name,
    int? durationMs,
    DateTime? lastModified,
  });
}

class _MediaInfoUpdateAllImpl implements _MediaInfoUpdateAll {
  const _MediaInfoUpdateAllImpl(this.collection);

  final IsarCollection<String, MediaInfo> collection;

  @override
  int call({
    required List<String> fileName,
    Object? mediaType = ignore,
    Object? name = ignore,
    Object? durationMs = ignore,
    Object? lastModified = ignore,
  }) {
    return collection.updateProperties(fileName, {
      if (mediaType != ignore) 1: mediaType as String?,
      if (name != ignore) 3: name as String?,
      if (durationMs != ignore) 4: durationMs as int?,
      if (lastModified != ignore) 5: lastModified as DateTime?,
    });
  }
}

extension MediaInfoUpdate on IsarCollection<String, MediaInfo> {
  _MediaInfoUpdate get update => _MediaInfoUpdateImpl(this);

  _MediaInfoUpdateAll get updateAll => _MediaInfoUpdateAllImpl(this);
}

sealed class _MediaInfoQueryUpdate {
  int call({
    String? mediaType,
    String? name,
    int? durationMs,
    DateTime? lastModified,
  });
}

class _MediaInfoQueryUpdateImpl implements _MediaInfoQueryUpdate {
  const _MediaInfoQueryUpdateImpl(this.query, {this.limit});

  final IsarQuery<MediaInfo> query;
  final int? limit;

  @override
  int call({
    Object? mediaType = ignore,
    Object? name = ignore,
    Object? durationMs = ignore,
    Object? lastModified = ignore,
  }) {
    return query.updateProperties(limit: limit, {
      if (mediaType != ignore) 1: mediaType as String?,
      if (name != ignore) 3: name as String?,
      if (durationMs != ignore) 4: durationMs as int?,
      if (lastModified != ignore) 5: lastModified as DateTime?,
    });
  }
}

extension MediaInfoQueryUpdate on IsarQuery<MediaInfo> {
  _MediaInfoQueryUpdate get updateFirst =>
      _MediaInfoQueryUpdateImpl(this, limit: 1);

  _MediaInfoQueryUpdate get updateAll => _MediaInfoQueryUpdateImpl(this);
}

class _MediaInfoQueryBuilderUpdateImpl implements _MediaInfoQueryUpdate {
  const _MediaInfoQueryBuilderUpdateImpl(this.query, {this.limit});

  final QueryBuilder<MediaInfo, MediaInfo, QOperations> query;
  final int? limit;

  @override
  int call({
    Object? mediaType = ignore,
    Object? name = ignore,
    Object? durationMs = ignore,
    Object? lastModified = ignore,
  }) {
    final q = query.build();
    try {
      return q.updateProperties(limit: limit, {
        if (mediaType != ignore) 1: mediaType as String?,
        if (name != ignore) 3: name as String?,
        if (durationMs != ignore) 4: durationMs as int?,
        if (lastModified != ignore) 5: lastModified as DateTime?,
      });
    } finally {
      q.close();
    }
  }
}

extension MediaInfoQueryBuilderUpdate
    on QueryBuilder<MediaInfo, MediaInfo, QOperations> {
  _MediaInfoQueryUpdate get updateFirst =>
      _MediaInfoQueryBuilderUpdateImpl(this, limit: 1);

  _MediaInfoQueryUpdate get updateAll => _MediaInfoQueryBuilderUpdateImpl(this);
}

extension MediaInfoQueryFilter
    on QueryBuilder<MediaInfo, MediaInfo, QFilterCondition> {
  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition> mediaTypeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition>
  mediaTypeGreaterThan(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition>
  mediaTypeGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition> mediaTypeLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 1, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition>
  mediaTypeLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition> mediaTypeBetween(
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

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition> mediaTypeStartsWith(
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

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition> mediaTypeEndsWith(
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

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition> mediaTypeContains(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition> mediaTypeMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition> mediaTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition>
  mediaTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 1, value: ''),
      );
    });
  }

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition> fileNameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 2, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition> fileNameGreaterThan(
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

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition>
  fileNameGreaterThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition> fileNameLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 2, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition>
  fileNameLessThanOrEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition> fileNameBetween(
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

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition> fileNameStartsWith(
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

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition> fileNameEndsWith(
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

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition> fileNameContains(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition> fileNameMatches(
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

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition> fileNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 2, value: ''),
      );
    });
  }

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition>
  fileNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 2, value: ''),
      );
    });
  }

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition> nameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const IsNullCondition(property: 3));
    });
  }

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition> nameIsNotNull() {
    return QueryBuilder.apply(not(), (query) {
      return query.addFilterCondition(const IsNullCondition(property: 3));
    });
  }

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition> nameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 3, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition> nameGreaterThan(
    String? value, {
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

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition>
  nameGreaterThanOrEqualTo(String? value, {bool caseSensitive = true}) {
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

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition> nameLessThan(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(property: 3, value: value, caseSensitive: caseSensitive),
      );
    });
  }

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition>
  nameLessThanOrEqualTo(String? value, {bool caseSensitive = true}) {
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

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition> nameBetween(
    String? lower,
    String? upper, {
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

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition> nameStartsWith(
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

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition> nameEndsWith(
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

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition> nameContains(
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

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition> nameMatches(
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

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition> nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(property: 3, value: ''),
      );
    });
  }

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition> nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(property: 3, value: ''),
      );
    });
  }

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition> durationMsIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const IsNullCondition(property: 4));
    });
  }

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition>
  durationMsIsNotNull() {
    return QueryBuilder.apply(not(), (query) {
      return query.addFilterCondition(const IsNullCondition(property: 4));
    });
  }

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition> durationMsEqualTo(
    int? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 4, value: value),
      );
    });
  }

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition>
  durationMsGreaterThan(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 4, value: value),
      );
    });
  }

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition>
  durationMsGreaterThanOrEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 4, value: value),
      );
    });
  }

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition> durationMsLessThan(
    int? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 4, value: value));
    });
  }

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition>
  durationMsLessThanOrEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 4, value: value),
      );
    });
  }

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition> durationMsBetween(
    int? lower,
    int? upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 4, lower: lower, upper: upper),
      );
    });
  }

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition> lastModifiedEqualTo(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(property: 5, value: value),
      );
    });
  }

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition>
  lastModifiedGreaterThan(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(property: 5, value: value),
      );
    });
  }

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition>
  lastModifiedGreaterThanOrEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(property: 5, value: value),
      );
    });
  }

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition>
  lastModifiedLessThan(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(LessCondition(property: 5, value: value));
    });
  }

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition>
  lastModifiedLessThanOrEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(property: 5, value: value),
      );
    });
  }

  QueryBuilder<MediaInfo, MediaInfo, QAfterFilterCondition> lastModifiedBetween(
    DateTime lower,
    DateTime upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(property: 5, lower: lower, upper: upper),
      );
    });
  }
}

extension MediaInfoQueryObject
    on QueryBuilder<MediaInfo, MediaInfo, QFilterCondition> {}

extension MediaInfoQuerySortBy on QueryBuilder<MediaInfo, MediaInfo, QSortBy> {
  QueryBuilder<MediaInfo, MediaInfo, QAfterSortBy> sortByMediaType({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MediaInfo, MediaInfo, QAfterSortBy> sortByMediaTypeDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MediaInfo, MediaInfo, QAfterSortBy> sortByFileName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MediaInfo, MediaInfo, QAfterSortBy> sortByFileNameDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MediaInfo, MediaInfo, QAfterSortBy> sortByName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MediaInfo, MediaInfo, QAfterSortBy> sortByNameDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MediaInfo, MediaInfo, QAfterSortBy> sortByDurationMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4);
    });
  }

  QueryBuilder<MediaInfo, MediaInfo, QAfterSortBy> sortByDurationMsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, sort: Sort.desc);
    });
  }

  QueryBuilder<MediaInfo, MediaInfo, QAfterSortBy> sortByLastModified() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5);
    });
  }

  QueryBuilder<MediaInfo, MediaInfo, QAfterSortBy> sortByLastModifiedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, sort: Sort.desc);
    });
  }
}

extension MediaInfoQuerySortThenBy
    on QueryBuilder<MediaInfo, MediaInfo, QSortThenBy> {
  QueryBuilder<MediaInfo, MediaInfo, QAfterSortBy> thenByMediaType({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MediaInfo, MediaInfo, QAfterSortBy> thenByMediaTypeDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MediaInfo, MediaInfo, QAfterSortBy> thenByFileName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MediaInfo, MediaInfo, QAfterSortBy> thenByFileNameDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MediaInfo, MediaInfo, QAfterSortBy> thenByName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MediaInfo, MediaInfo, QAfterSortBy> thenByNameDesc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MediaInfo, MediaInfo, QAfterSortBy> thenByDurationMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4);
    });
  }

  QueryBuilder<MediaInfo, MediaInfo, QAfterSortBy> thenByDurationMsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, sort: Sort.desc);
    });
  }

  QueryBuilder<MediaInfo, MediaInfo, QAfterSortBy> thenByLastModified() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5);
    });
  }

  QueryBuilder<MediaInfo, MediaInfo, QAfterSortBy> thenByLastModifiedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(5, sort: Sort.desc);
    });
  }
}

extension MediaInfoQueryWhereDistinct
    on QueryBuilder<MediaInfo, MediaInfo, QDistinct> {
  QueryBuilder<MediaInfo, MediaInfo, QAfterDistinct> distinctByMediaType({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MediaInfo, MediaInfo, QAfterDistinct> distinctByName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<MediaInfo, MediaInfo, QAfterDistinct> distinctByDurationMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(4);
    });
  }

  QueryBuilder<MediaInfo, MediaInfo, QAfterDistinct> distinctByLastModified() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(5);
    });
  }
}

extension MediaInfoQueryProperty1
    on QueryBuilder<MediaInfo, MediaInfo, QProperty> {
  QueryBuilder<MediaInfo, String, QAfterProperty> mediaTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<MediaInfo, String, QAfterProperty> fileNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<MediaInfo, String?, QAfterProperty> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<MediaInfo, int?, QAfterProperty> durationMsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<MediaInfo, DateTime, QAfterProperty> lastModifiedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }
}

extension MediaInfoQueryProperty2<R>
    on QueryBuilder<MediaInfo, R, QAfterProperty> {
  QueryBuilder<MediaInfo, (R, String), QAfterProperty> mediaTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<MediaInfo, (R, String), QAfterProperty> fileNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<MediaInfo, (R, String?), QAfterProperty> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<MediaInfo, (R, int?), QAfterProperty> durationMsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<MediaInfo, (R, DateTime), QAfterProperty>
  lastModifiedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }
}

extension MediaInfoQueryProperty3<R1, R2>
    on QueryBuilder<MediaInfo, (R1, R2), QAfterProperty> {
  QueryBuilder<MediaInfo, (R1, R2, String), QOperations> mediaTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<MediaInfo, (R1, R2, String), QOperations> fileNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<MediaInfo, (R1, R2, String?), QOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<MediaInfo, (R1, R2, int?), QOperations> durationMsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }

  QueryBuilder<MediaInfo, (R1, R2, DateTime), QOperations>
  lastModifiedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(5);
    });
  }
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MediaInfo _$MediaInfoFromJson(Map<String, dynamic> json) => _MediaInfo(
  fileName: json['fileName'] as String,
  name: json['name'] as String?,
  durationMs: (json['durationMs'] as num?)?.toInt(),
  lastModified: const UtcDateTimeConverter().fromJson(
    json['lastModified'] as String,
  ),
);

Map<String, dynamic> _$MediaInfoToJson(
  _MediaInfo instance,
) => <String, dynamic>{
  'fileName': instance.fileName,
  'name': instance.name,
  'durationMs': instance.durationMs,
  'lastModified': const UtcDateTimeConverter().toJson(instance.lastModified),
};
