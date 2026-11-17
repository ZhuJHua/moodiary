/// Category tools: list, create, update and delete.
library;

import 'package:flutter/foundation.dart' show internal;
import 'package:json_schema_builder/json_schema_builder.dart';

import '../ops/category_ops.dart';
import '../ops/diary_writes.dart';
import 'arguments.dart';
import 'category_queries.dart';
import 'diary_payloads.dart';
import 'diary_references.dart';
import 'output_schemas.dart';
import 'schemas.dart';
import 'tool_def.dart';

@internal
final List<ToolDefinition> categoryTools = [
  ToolDef(
    name: 'list_categories',
    validateArguments: validateToolArguments,
    references: (result) => diaryReferences('list_categories', result.data),
    title: 'List categories',
    description: (_) =>
        'Lists every diary category with id, name, ARGB colour, colour hex '
        'and its visible diary count. total is the number of categories.',
    input: (_) => Schema.fromMap({'type': 'object', 'properties': {}}),
    surfaces: const {ToolSurface.assistant, ToolSurface.mcp},
    effect: ToolEffect.read,
    idempotent: true,
    output: toolOutputSchema('list_categories'),
    parse: _parseListCategories,
    run: (input, ctx) => _listCategories(input, ctx),
    toJson: (result) => result.data,
    media: (result) => result.media,
  ),
  ToolDef(
    name: 'create_category',
    validateArguments: validateToolArguments,
    references: (result) => diaryReferences('create_category', result.data),
    title: 'Create a category',
    description: (_) =>
        'Creates one diary category. color accepts a 32 bit ARGB integer '
        'or a #RRGGBB / #AARRGGBB string.',
    input: (_) => Schema.fromMap({
      'type': 'object',
      'properties': {'name': categoryNameSchema, 'color': colorSchema},
      'required': ['name'],
    }),
    surfaces: const {ToolSurface.assistant, ToolSurface.mcp},
    effect: ToolEffect.write,
    idempotent: false,
    output: toolOutputSchema('create_category'),
    parse: _parseCreateCategory,
    run: (input, ctx) => _createCategory(input, ctx),
    toJson: (result) => result.data,
    media: (result) => result.media,
  ),
  ToolDef(
    name: 'update_category',
    validateArguments: validateToolArguments,
    references: (result) => diaryReferences('update_category', result.data),
    title: 'Update a category',
    description: (_) =>
        'Renames or recolours one category, leaving omitted fields unchanged. '
        'Send null (or an empty string) for color to clear it. Requires at '
        'least one of name and color.',
    input: (_) => Schema.fromMap({
      'type': 'object',
      'properties': {
        'id': {
          'type': 'string',
          'description': 'Category id as list_categories returns it.',
        },
        'name': categoryNameSchema,
        'color': colorSchema,
      },
      'required': ['id'],
    }),
    surfaces: const {ToolSurface.assistant, ToolSurface.mcp},
    effect: ToolEffect.write,
    idempotent: true,
    output: toolOutputSchema('update_category'),
    parse: _parseUpdateCategory,
    run: (input, ctx) => _updateCategory(input, ctx),
    toJson: (result) => result.data,
    media: (result) => result.media,
  ),
  ToolDef(
    name: 'delete_category',
    validateArguments: validateToolArguments,
    references: (result) => diaryReferences('delete_category', result.data),
    title: 'Delete a category',
    description: (_) =>
        'Deletes one empty category. Refuses categories holding diaries, '
        'including those in the recycle bin, and reports the reason.',
    input: (_) => Schema.fromMap({
      'type': 'object',
      'properties': {
        'id': {
          'type': 'string',
          'description': 'Category id as list_categories returns it.',
        },
      },
      'required': ['id'],
    }),
    surfaces: const {ToolSurface.assistant, ToolSurface.mcp},
    effect: ToolEffect.destructive,
    idempotent: true,
    output: toolOutputSchema('delete_category'),
    parse: _parseDeleteCategory,
    run: (input, ctx) => _deleteCategory(input, ctx),
    toJson: (result) => result.data,
    media: (result) => result.media,
  ),
];

Future<ToolResult> _listCategories(Object? input, ToolContext ctx) async {
  final categories = ctx.categories;
  final diaries = ctx.diaries;
  final listed = await CategoryToolQueries(
    categories: categories,
    diaries: diaries,
  ).list();
  return ToolResult({'categories': listed.categories, 'total': listed.total});
}

Future<ToolResult> _createCategory(
  _CreateCategoryInput input,
  ToolContext ctx,
) async {
  final categories = ctx.categories;
  final ops = CategoryOps(categories: categories);
  final (:name, :color) = input;
  final category = await ops.create(name: name, color: color);
  return ToolResult({
    'created': true,
    'category': categoryInfo(category, diaryCount: 0),
  });
}

Future<ToolResult> _updateCategory(
  _UpdateCategoryInput input,
  ToolContext ctx,
) async {
  final categories = ctx.categories;
  final ops = CategoryOps(categories: categories);
  final (:id, :name, :color, :colorSet) = input;
  try {
    final category = await ops.update(
      id: id,
      name: name,
      color: color,
      colorSet: colorSet,
    );
    return ToolResult({'updated': true, 'category': categoryInfo(category)});
  } on DiaryOpsException catch (e) {
    return switch (e.failure) {
      DiaryOpsFailure.notFound => _failure(
        'update_category: no category with id="$id".',
      ),
      DiaryOpsFailure.noChanges => throw const ToolArgumentException(
        'update_category: provide at least one of name, color',
      ),
      _ => _failure('update_category: could not update.'),
    };
  }
}

Future<ToolResult> _deleteCategory(
  _DeleteCategoryInput input,
  ToolContext ctx,
) async {
  final categories = ctx.categories;
  final ops = CategoryOps(categories: categories);
  final (:id) = input;
  try {
    final result = await ops.delete(id);
    if (!result.deleted) {
      return ToolResult({
        'deleted': false,
        'id': id,
        'name': result.category.categoryName,
        'reason':
            'the app refuses to delete a category that still holds diaries, '
            'including diaries in the recycle bin; move those diaries to '
            'another category first',
      });
    }
    return ToolResult({
      'deleted': true,
      'id': id,
      'name': result.category.categoryName,
    });
  } on DiaryOpsException {
    return _failure('delete_category: no category with id="$id".');
  }
}

typedef _CreateCategoryInput = ({String name, int? color});

_CreateCategoryInput _parseCreateCategory(Map<String, Object?> raw) {
  final args = ToolArguments('create_category', raw);
  final name = args.requireText('name');
  final color = args.optionalColor('color');
  return (name: name, color: color);
}

typedef _UpdateCategoryInput = ({
  String id,
  String? name,
  int? color,
  bool colorSet,
});

_UpdateCategoryInput _parseUpdateCategory(Map<String, Object?> raw) {
  final args = ToolArguments('update_category', raw);
  final id = args.requireText('id');
  final name = args.contains('name') ? args.requireText('name') : null;
  final color = args.has('color') ? args.optionalColor('color') : null;
  final colorSet = args.has('color');
  return (id: id, name: name, color: color, colorSet: colorSet);
}

typedef _DeleteCategoryInput = ({String id});

_DeleteCategoryInput _parseDeleteCategory(Map<String, Object?> raw) {
  final args = ToolArguments('delete_category', raw);
  final id = args.requireText('id');
  return (id: id);
}

Object? _parseListCategories(Map<String, Object?> raw) => null;

Never _failure(String message) => throw ToolFailure(message);
