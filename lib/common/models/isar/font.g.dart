// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'font.dart';

// **************************************************************************
// _IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, invalid_use_of_protected_member, lines_longer_than_80_chars, constant_identifier_names, avoid_js_rounded_ints, no_leading_underscores_for_local_identifiers, require_trailing_commas, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_in_if_null_operators, library_private_types_in_public_api, prefer_const_constructors
// ignore_for_file: type=lint

extension GetFontCollection on Isar {
  IsarCollection<int, Font> get fonts => this.collection();
}

const FontSchema = IsarGeneratedSchema(
  schema: IsarSchema(
    name: 'Font',
    idName: 'id',
    embedded: false,
    properties: [
      IsarPropertySchema(
        name: 'fontFileName',
        type: IsarType.string,
      ),
      IsarPropertySchema(
        name: 'fontWghtAxisMap',
        type: IsarType.json,
      ),
      IsarPropertySchema(
        name: 'fontFamily',
        type: IsarType.string,
      ),
      IsarPropertySchema(
        name: 'fontType',
        type: IsarType.string,
      ),
    ],
    indexes: [],
  ),
  converter: IsarObjectConverter<int, Font>(
    serialize: serializeFont,
    deserialize: deserializeFont,
    deserializeProperty: deserializeFontProp,
  ),
  embeddedSchemas: [],
);

@isarProtected
int serializeFont(IsarWriter writer, Font object) {
  IsarCore.writeString(writer, 1, object.fontFileName);
  IsarCore.writeString(writer, 2, isarJsonEncode(object.fontWghtAxisMap));
  IsarCore.writeString(writer, 3, object.fontFamily);
  IsarCore.writeString(writer, 4, object.fontType);
  return object.id;
}

@isarProtected
Font deserializeFont(IsarReader reader) {
  final String _fontFileName;
  _fontFileName = IsarCore.readString(reader, 1) ?? '';
  final Map<String, dynamic> _fontWghtAxisMap;
  {
    final json = isarJsonDecode(IsarCore.readString(reader, 2) ?? 'null');
    if (json is Map<String, dynamic>) {
      _fontWghtAxisMap = json;
    } else {
      _fontWghtAxisMap = const <String, dynamic>{};
    }
  }
  final object = Font(
    fontFileName: _fontFileName,
    fontWghtAxisMap: _fontWghtAxisMap,
  );
  return object;
}

@isarProtected
dynamic deserializeFontProp(IsarReader reader, int property) {
  switch (property) {
    case 1:
      return IsarCore.readString(reader, 1) ?? '';
    case 2:
      {
        final json = isarJsonDecode(IsarCore.readString(reader, 2) ?? 'null');
        if (json is Map<String, dynamic>) {
          return json;
        } else {
          return const <String, dynamic>{};
        }
      }
    case 0:
      return IsarCore.readId(reader);
    case 3:
      return IsarCore.readString(reader, 3) ?? '';
    case 4:
      return IsarCore.readString(reader, 4) ?? '';
    default:
      throw ArgumentError('Unknown property: $property');
  }
}

sealed class _FontUpdate {
  bool call({
    required int id,
    String? fontFileName,
    String? fontFamily,
    String? fontType,
  });
}

class _FontUpdateImpl implements _FontUpdate {
  const _FontUpdateImpl(this.collection);

  final IsarCollection<int, Font> collection;

  @override
  bool call({
    required int id,
    Object? fontFileName = ignore,
    Object? fontFamily = ignore,
    Object? fontType = ignore,
  }) {
    return collection.updateProperties([
          id
        ], {
          if (fontFileName != ignore) 1: fontFileName as String?,
          if (fontFamily != ignore) 3: fontFamily as String?,
          if (fontType != ignore) 4: fontType as String?,
        }) >
        0;
  }
}

sealed class _FontUpdateAll {
  int call({
    required List<int> id,
    String? fontFileName,
    String? fontFamily,
    String? fontType,
  });
}

class _FontUpdateAllImpl implements _FontUpdateAll {
  const _FontUpdateAllImpl(this.collection);

  final IsarCollection<int, Font> collection;

  @override
  int call({
    required List<int> id,
    Object? fontFileName = ignore,
    Object? fontFamily = ignore,
    Object? fontType = ignore,
  }) {
    return collection.updateProperties(id, {
      if (fontFileName != ignore) 1: fontFileName as String?,
      if (fontFamily != ignore) 3: fontFamily as String?,
      if (fontType != ignore) 4: fontType as String?,
    });
  }
}

extension FontUpdate on IsarCollection<int, Font> {
  _FontUpdate get update => _FontUpdateImpl(this);

  _FontUpdateAll get updateAll => _FontUpdateAllImpl(this);
}

sealed class _FontQueryUpdate {
  int call({
    String? fontFileName,
    String? fontFamily,
    String? fontType,
  });
}

class _FontQueryUpdateImpl implements _FontQueryUpdate {
  const _FontQueryUpdateImpl(this.query, {this.limit});

  final IsarQuery<Font> query;
  final int? limit;

  @override
  int call({
    Object? fontFileName = ignore,
    Object? fontFamily = ignore,
    Object? fontType = ignore,
  }) {
    return query.updateProperties(limit: limit, {
      if (fontFileName != ignore) 1: fontFileName as String?,
      if (fontFamily != ignore) 3: fontFamily as String?,
      if (fontType != ignore) 4: fontType as String?,
    });
  }
}

extension FontQueryUpdate on IsarQuery<Font> {
  _FontQueryUpdate get updateFirst => _FontQueryUpdateImpl(this, limit: 1);

  _FontQueryUpdate get updateAll => _FontQueryUpdateImpl(this);
}

class _FontQueryBuilderUpdateImpl implements _FontQueryUpdate {
  const _FontQueryBuilderUpdateImpl(this.query, {this.limit});

  final QueryBuilder<Font, Font, QOperations> query;
  final int? limit;

  @override
  int call({
    Object? fontFileName = ignore,
    Object? fontFamily = ignore,
    Object? fontType = ignore,
  }) {
    final q = query.build();
    try {
      return q.updateProperties(limit: limit, {
        if (fontFileName != ignore) 1: fontFileName as String?,
        if (fontFamily != ignore) 3: fontFamily as String?,
        if (fontType != ignore) 4: fontType as String?,
      });
    } finally {
      q.close();
    }
  }
}

extension FontQueryBuilderUpdate on QueryBuilder<Font, Font, QOperations> {
  _FontQueryUpdate get updateFirst =>
      _FontQueryBuilderUpdateImpl(this, limit: 1);

  _FontQueryUpdate get updateAll => _FontQueryBuilderUpdateImpl(this);
}

extension FontQueryFilter on QueryBuilder<Font, Font, QFilterCondition> {
  QueryBuilder<Font, Font, QAfterFilterCondition> fontFileNameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Font, Font, QAfterFilterCondition> fontFileNameGreaterThan(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<Font, Font, QAfterFilterCondition>
      fontFileNameGreaterThanOrEqualTo(
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

  QueryBuilder<Font, Font, QAfterFilterCondition> fontFileNameLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(
          property: 1,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Font, Font, QAfterFilterCondition> fontFileNameLessThanOrEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
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

  QueryBuilder<Font, Font, QAfterFilterCondition> fontFileNameBetween(
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

  QueryBuilder<Font, Font, QAfterFilterCondition> fontFileNameStartsWith(
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

  QueryBuilder<Font, Font, QAfterFilterCondition> fontFileNameEndsWith(
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

  QueryBuilder<Font, Font, QAfterFilterCondition> fontFileNameContains(
      String value,
      {bool caseSensitive = true}) {
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

  QueryBuilder<Font, Font, QAfterFilterCondition> fontFileNameMatches(
      String pattern,
      {bool caseSensitive = true}) {
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

  QueryBuilder<Font, Font, QAfterFilterCondition> fontFileNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(
          property: 1,
          value: '',
        ),
      );
    });
  }

  QueryBuilder<Font, Font, QAfterFilterCondition> fontFileNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(
          property: 1,
          value: '',
        ),
      );
    });
  }

  QueryBuilder<Font, Font, QAfterFilterCondition> idEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(
          property: 0,
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Font, Font, QAfterFilterCondition> idGreaterThan(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 0,
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Font, Font, QAfterFilterCondition> idGreaterThanOrEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 0,
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Font, Font, QAfterFilterCondition> idLessThan(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(
          property: 0,
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Font, Font, QAfterFilterCondition> idLessThanOrEqualTo(
    int value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 0,
          value: value,
        ),
      );
    });
  }

  QueryBuilder<Font, Font, QAfterFilterCondition> idBetween(
    int lower,
    int upper,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 0,
          lower: lower,
          upper: upper,
        ),
      );
    });
  }

  QueryBuilder<Font, Font, QAfterFilterCondition> fontFamilyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Font, Font, QAfterFilterCondition> fontFamilyGreaterThan(
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

  QueryBuilder<Font, Font, QAfterFilterCondition>
      fontFamilyGreaterThanOrEqualTo(
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

  QueryBuilder<Font, Font, QAfterFilterCondition> fontFamilyLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(
          property: 3,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Font, Font, QAfterFilterCondition> fontFamilyLessThanOrEqualTo(
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

  QueryBuilder<Font, Font, QAfterFilterCondition> fontFamilyBetween(
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

  QueryBuilder<Font, Font, QAfterFilterCondition> fontFamilyStartsWith(
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

  QueryBuilder<Font, Font, QAfterFilterCondition> fontFamilyEndsWith(
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

  QueryBuilder<Font, Font, QAfterFilterCondition> fontFamilyContains(
      String value,
      {bool caseSensitive = true}) {
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

  QueryBuilder<Font, Font, QAfterFilterCondition> fontFamilyMatches(
      String pattern,
      {bool caseSensitive = true}) {
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

  QueryBuilder<Font, Font, QAfterFilterCondition> fontFamilyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(
          property: 3,
          value: '',
        ),
      );
    });
  }

  QueryBuilder<Font, Font, QAfterFilterCondition> fontFamilyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(
          property: 3,
          value: '',
        ),
      );
    });
  }

  QueryBuilder<Font, Font, QAfterFilterCondition> fontTypeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(
          property: 4,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Font, Font, QAfterFilterCondition> fontTypeGreaterThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterCondition(
          property: 4,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Font, Font, QAfterFilterCondition> fontTypeGreaterThanOrEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        GreaterOrEqualCondition(
          property: 4,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Font, Font, QAfterFilterCondition> fontTypeLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(
          property: 4,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Font, Font, QAfterFilterCondition> fontTypeLessThanOrEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessOrEqualCondition(
          property: 4,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Font, Font, QAfterFilterCondition> fontTypeBetween(
    String lower,
    String upper, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        BetweenCondition(
          property: 4,
          lower: lower,
          upper: upper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Font, Font, QAfterFilterCondition> fontTypeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        StartsWithCondition(
          property: 4,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Font, Font, QAfterFilterCondition> fontTypeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EndsWithCondition(
          property: 4,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Font, Font, QAfterFilterCondition> fontTypeContains(String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        ContainsCondition(
          property: 4,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Font, Font, QAfterFilterCondition> fontTypeMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        MatchesCondition(
          property: 4,
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Font, Font, QAfterFilterCondition> fontTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(
          property: 4,
          value: '',
        ),
      );
    });
  }

  QueryBuilder<Font, Font, QAfterFilterCondition> fontTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(
          property: 4,
          value: '',
        ),
      );
    });
  }
}

extension FontQueryObject on QueryBuilder<Font, Font, QFilterCondition> {}

extension FontQuerySortBy on QueryBuilder<Font, Font, QSortBy> {
  QueryBuilder<Font, Font, QAfterSortBy> sortByFontFileName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(
        1,
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<Font, Font, QAfterSortBy> sortByFontFileNameDesc(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(
        1,
        sort: Sort.desc,
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<Font, Font, QAfterSortBy> sortByFontWghtAxisMap() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2);
    });
  }

  QueryBuilder<Font, Font, QAfterSortBy> sortByFontWghtAxisMapDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc);
    });
  }

  QueryBuilder<Font, Font, QAfterSortBy> sortById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<Font, Font, QAfterSortBy> sortByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<Font, Font, QAfterSortBy> sortByFontFamily(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(
        3,
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<Font, Font, QAfterSortBy> sortByFontFamilyDesc(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(
        3,
        sort: Sort.desc,
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<Font, Font, QAfterSortBy> sortByFontType(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(
        4,
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<Font, Font, QAfterSortBy> sortByFontTypeDesc(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(
        4,
        sort: Sort.desc,
        caseSensitive: caseSensitive,
      );
    });
  }
}

extension FontQuerySortThenBy on QueryBuilder<Font, Font, QSortThenBy> {
  QueryBuilder<Font, Font, QAfterSortBy> thenByFontFileName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Font, Font, QAfterSortBy> thenByFontFileNameDesc(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Font, Font, QAfterSortBy> thenByFontWghtAxisMap() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2);
    });
  }

  QueryBuilder<Font, Font, QAfterSortBy> thenByFontWghtAxisMapDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc);
    });
  }

  QueryBuilder<Font, Font, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0);
    });
  }

  QueryBuilder<Font, Font, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(0, sort: Sort.desc);
    });
  }

  QueryBuilder<Font, Font, QAfterSortBy> thenByFontFamily(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Font, Font, QAfterSortBy> thenByFontFamilyDesc(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(3, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Font, Font, QAfterSortBy> thenByFontType(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Font, Font, QAfterSortBy> thenByFontTypeDesc(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(4, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }
}

extension FontQueryWhereDistinct on QueryBuilder<Font, Font, QDistinct> {
  QueryBuilder<Font, Font, QAfterDistinct> distinctByFontFileName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Font, Font, QAfterDistinct> distinctByFontWghtAxisMap() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(2);
    });
  }

  QueryBuilder<Font, Font, QAfterDistinct> distinctByFontFamily(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(3, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Font, Font, QAfterDistinct> distinctByFontType(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(4, caseSensitive: caseSensitive);
    });
  }
}

extension FontQueryProperty1 on QueryBuilder<Font, Font, QProperty> {
  QueryBuilder<Font, String, QAfterProperty> fontFileNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<Font, Map<String, dynamic>, QAfterProperty>
      fontWghtAxisMapProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<Font, int, QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<Font, String, QAfterProperty> fontFamilyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<Font, String, QAfterProperty> fontTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }
}

extension FontQueryProperty2<R> on QueryBuilder<Font, R, QAfterProperty> {
  QueryBuilder<Font, (R, String), QAfterProperty> fontFileNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<Font, (R, Map<String, dynamic>), QAfterProperty>
      fontWghtAxisMapProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<Font, (R, int), QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<Font, (R, String), QAfterProperty> fontFamilyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<Font, (R, String), QAfterProperty> fontTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }
}

extension FontQueryProperty3<R1, R2>
    on QueryBuilder<Font, (R1, R2), QAfterProperty> {
  QueryBuilder<Font, (R1, R2, String), QOperations> fontFileNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<Font, (R1, R2, Map<String, dynamic>), QOperations>
      fontWghtAxisMapProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }

  QueryBuilder<Font, (R1, R2, int), QOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(0);
    });
  }

  QueryBuilder<Font, (R1, R2, String), QOperations> fontFamilyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(3);
    });
  }

  QueryBuilder<Font, (R1, R2, String), QOperations> fontTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(4);
    });
  }
}
