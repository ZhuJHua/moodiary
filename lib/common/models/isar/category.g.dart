// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category.dart';

// **************************************************************************
// _IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, invalid_use_of_protected_member, lines_longer_than_80_chars, constant_identifier_names, avoid_js_rounded_ints, no_leading_underscores_for_local_identifiers, require_trailing_commas, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_in_if_null_operators, library_private_types_in_public_api, prefer_const_constructors
// ignore_for_file: type=lint

extension GetCategoryCollection on Isar {
  IsarCollection<String, Category> get categorys => this.collection();
}

const CategorySchema = IsarGeneratedSchema(
  schema: IsarSchema(
    name: 'Category',
    idName: 'id',
    embedded: false,
    properties: [
      IsarPropertySchema(
        name: 'id',
        type: IsarType.string,
      ),
      IsarPropertySchema(
        name: 'categoryName',
        type: IsarType.string,
      ),
    ],
    indexes: [],
  ),
  converter: IsarObjectConverter<String, Category>(
    serialize: serializeCategory,
    deserialize: deserializeCategory,
    deserializeProperty: deserializeCategoryProp,
  ),
  embeddedSchemas: [],
);

@isarProtected
int serializeCategory(IsarWriter writer, Category object) {
  IsarCore.writeString(writer, 1, object.id);
  IsarCore.writeString(writer, 2, object.categoryName);
  return Isar.fastHash(object.id);
}

@isarProtected
Category deserializeCategory(IsarReader reader) {
  final object = Category();
  object.id = IsarCore.readString(reader, 1) ?? '';
  object.categoryName = IsarCore.readString(reader, 2) ?? '';
  return object;
}

@isarProtected
dynamic deserializeCategoryProp(IsarReader reader, int property) {
  switch (property) {
    case 1:
      return IsarCore.readString(reader, 1) ?? '';
    case 2:
      return IsarCore.readString(reader, 2) ?? '';
    default:
      throw ArgumentError('Unknown property: $property');
  }
}

sealed class _CategoryUpdate {
  bool call({
    required String id,
    String? categoryName,
  });
}

class _CategoryUpdateImpl implements _CategoryUpdate {
  const _CategoryUpdateImpl(this.collection);

  final IsarCollection<String, Category> collection;

  @override
  bool call({
    required String id,
    Object? categoryName = ignore,
  }) {
    return collection.updateProperties([
          id
        ], {
          if (categoryName != ignore) 2: categoryName as String?,
        }) >
        0;
  }
}

sealed class _CategoryUpdateAll {
  int call({
    required List<String> id,
    String? categoryName,
  });
}

class _CategoryUpdateAllImpl implements _CategoryUpdateAll {
  const _CategoryUpdateAllImpl(this.collection);

  final IsarCollection<String, Category> collection;

  @override
  int call({
    required List<String> id,
    Object? categoryName = ignore,
  }) {
    return collection.updateProperties(id, {
      if (categoryName != ignore) 2: categoryName as String?,
    });
  }
}

extension CategoryUpdate on IsarCollection<String, Category> {
  _CategoryUpdate get update => _CategoryUpdateImpl(this);

  _CategoryUpdateAll get updateAll => _CategoryUpdateAllImpl(this);
}

sealed class _CategoryQueryUpdate {
  int call({
    String? categoryName,
  });
}

class _CategoryQueryUpdateImpl implements _CategoryQueryUpdate {
  const _CategoryQueryUpdateImpl(this.query, {this.limit});

  final IsarQuery<Category> query;
  final int? limit;

  @override
  int call({
    Object? categoryName = ignore,
  }) {
    return query.updateProperties(limit: limit, {
      if (categoryName != ignore) 2: categoryName as String?,
    });
  }
}

extension CategoryQueryUpdate on IsarQuery<Category> {
  _CategoryQueryUpdate get updateFirst =>
      _CategoryQueryUpdateImpl(this, limit: 1);

  _CategoryQueryUpdate get updateAll => _CategoryQueryUpdateImpl(this);
}

class _CategoryQueryBuilderUpdateImpl implements _CategoryQueryUpdate {
  const _CategoryQueryBuilderUpdateImpl(this.query, {this.limit});

  final QueryBuilder<Category, Category, QOperations> query;
  final int? limit;

  @override
  int call({
    Object? categoryName = ignore,
  }) {
    final q = query.build();
    try {
      return q.updateProperties(limit: limit, {
        if (categoryName != ignore) 2: categoryName as String?,
      });
    } finally {
      q.close();
    }
  }
}

extension CategoryQueryBuilderUpdate
    on QueryBuilder<Category, Category, QOperations> {
  _CategoryQueryUpdate get updateFirst =>
      _CategoryQueryBuilderUpdateImpl(this, limit: 1);

  _CategoryQueryUpdate get updateAll => _CategoryQueryBuilderUpdateImpl(this);
}

extension CategoryQueryFilter
    on QueryBuilder<Category, Category, QFilterCondition> {
  QueryBuilder<Category, Category, QAfterFilterCondition> idEqualTo(
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

  QueryBuilder<Category, Category, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<Category, Category, QAfterFilterCondition>
      idGreaterThanOrEqualTo(
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

  QueryBuilder<Category, Category, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<Category, Category, QAfterFilterCondition> idLessThanOrEqualTo(
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

  QueryBuilder<Category, Category, QAfterFilterCondition> idBetween(
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

  QueryBuilder<Category, Category, QAfterFilterCondition> idStartsWith(
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

  QueryBuilder<Category, Category, QAfterFilterCondition> idEndsWith(
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

  QueryBuilder<Category, Category, QAfterFilterCondition> idContains(
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

  QueryBuilder<Category, Category, QAfterFilterCondition> idMatches(
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

  QueryBuilder<Category, Category, QAfterFilterCondition> idIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(
          property: 1,
          value: '',
        ),
      );
    });
  }

  QueryBuilder<Category, Category, QAfterFilterCondition> idIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(
          property: 1,
          value: '',
        ),
      );
    });
  }

  QueryBuilder<Category, Category, QAfterFilterCondition> categoryNameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        EqualCondition(
          property: 2,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Category, Category, QAfterFilterCondition>
      categoryNameGreaterThan(
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

  QueryBuilder<Category, Category, QAfterFilterCondition>
      categoryNameGreaterThanOrEqualTo(
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

  QueryBuilder<Category, Category, QAfterFilterCondition> categoryNameLessThan(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        LessCondition(
          property: 2,
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<Category, Category, QAfterFilterCondition>
      categoryNameLessThanOrEqualTo(
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

  QueryBuilder<Category, Category, QAfterFilterCondition> categoryNameBetween(
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

  QueryBuilder<Category, Category, QAfterFilterCondition>
      categoryNameStartsWith(
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

  QueryBuilder<Category, Category, QAfterFilterCondition> categoryNameEndsWith(
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

  QueryBuilder<Category, Category, QAfterFilterCondition> categoryNameContains(
      String value,
      {bool caseSensitive = true}) {
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

  QueryBuilder<Category, Category, QAfterFilterCondition> categoryNameMatches(
      String pattern,
      {bool caseSensitive = true}) {
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

  QueryBuilder<Category, Category, QAfterFilterCondition>
      categoryNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const EqualCondition(
          property: 2,
          value: '',
        ),
      );
    });
  }

  QueryBuilder<Category, Category, QAfterFilterCondition>
      categoryNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const GreaterCondition(
          property: 2,
          value: '',
        ),
      );
    });
  }
}

extension CategoryQueryObject
    on QueryBuilder<Category, Category, QFilterCondition> {}

extension CategoryQuerySortBy on QueryBuilder<Category, Category, QSortBy> {
  QueryBuilder<Category, Category, QAfterSortBy> sortById(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(
        1,
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<Category, Category, QAfterSortBy> sortByIdDesc(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(
        1,
        sort: Sort.desc,
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<Category, Category, QAfterSortBy> sortByCategoryName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(
        2,
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<Category, Category, QAfterSortBy> sortByCategoryNameDesc(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(
        2,
        sort: Sort.desc,
        caseSensitive: caseSensitive,
      );
    });
  }
}

extension CategoryQuerySortThenBy
    on QueryBuilder<Category, Category, QSortThenBy> {
  QueryBuilder<Category, Category, QAfterSortBy> thenById(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Category, Category, QAfterSortBy> thenByIdDesc(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(1, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Category, Category, QAfterSortBy> thenByCategoryName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Category, Category, QAfterSortBy> thenByCategoryNameDesc(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(2, sort: Sort.desc, caseSensitive: caseSensitive);
    });
  }
}

extension CategoryQueryWhereDistinct
    on QueryBuilder<Category, Category, QDistinct> {
  QueryBuilder<Category, Category, QAfterDistinct> distinctByCategoryName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(2, caseSensitive: caseSensitive);
    });
  }
}

extension CategoryQueryProperty1
    on QueryBuilder<Category, Category, QProperty> {
  QueryBuilder<Category, String, QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<Category, String, QAfterProperty> categoryNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }
}

extension CategoryQueryProperty2<R>
    on QueryBuilder<Category, R, QAfterProperty> {
  QueryBuilder<Category, (R, String), QAfterProperty> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<Category, (R, String), QAfterProperty> categoryNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }
}

extension CategoryQueryProperty3<R1, R2>
    on QueryBuilder<Category, (R1, R2), QAfterProperty> {
  QueryBuilder<Category, (R1, R2, String), QOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(1);
    });
  }

  QueryBuilder<Category, (R1, R2, String), QOperations> categoryNameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addProperty(2);
    });
  }
}
