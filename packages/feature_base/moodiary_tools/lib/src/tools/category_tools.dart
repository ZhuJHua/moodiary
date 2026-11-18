library;

import 'package:flutter/foundation.dart' show internal;
import 'package:json_schema_builder/json_schema_builder.dart';

import '../ops/category_ops.dart';
import '../ops/diary_writes.dart';
import 'arguments.dart';
import 'batch.dart';
import 'category_queries.dart';
import 'diary_payloads.dart';
import 'output_schemas.dart';
import 'schemas.dart';
import 'tool_def.dart';

@internal
final List<ToolDef> categoryTools = [
  ToolDef(
    name: 'list_categories',
    title: 'List categories',
    description: (_) =>
        'Lists every diary category with id, name, ARGB colour, colour hex '
        'and its visible diary count. total is the number of categories.',
    input: (_) => S.object(properties: {}),
    surfaces: const {ToolSurface.assistant, ToolSurface.mcp},
    effect: ToolEffect.read,
    idempotent: true,
    output: _listCategoriesOutput,
    parse: (raw) => raw,
    run: (_, ctx) => _listCategories(ctx),
  ),
  ToolDef(
    name: 'create_category',
    title: 'Create a category',
    description: (_) =>
        '$toolBatchDescription'
        'Creates categories in the batch. color accepts a 32 bit ARGB integer '
        'or a #RRGGBB / #AARRGGBB string.',
    input: (_) => batchItemsSchema(
      S.object(
        properties: {'name': categoryNameSchema, 'color': colorSchema},
        required: ['name'],
      ),
    ),
    surfaces: const {ToolSurface.assistant, ToolSurface.mcp},
    effect: ToolEffect.write,
    idempotent: false,
    output: _createCategoryOutput,
    parse: toolBatchItems,
    run: (items, ctx) => runToolBatch(
      items,
      (item) => _createCategory(_parseCreateCategory(item), ctx),
    ),
  ),
  ToolDef(
    name: 'update_category',
    title: 'Update a category',
    description: (_) =>
        '$toolBatchDescription'
        'Renames or recolours categories in items (1–20), leaving omitted fields unchanged. '
        'Send null (or an empty string) for color to clear it. Requires at '
        'least one of name and color.',
    input: (_) => batchItemsSchema(
      S.object(
        properties: {
          'id': requiredCategoryIdSchema,
          'name': nullableSchema(categoryNameSchema, JsonType.string),
          'color': colorSchema,
        },
        required: ['id'],
      ),
    ),
    surfaces: const {ToolSurface.assistant, ToolSurface.mcp},
    effect: ToolEffect.write,
    idempotent: true,
    output: _updateCategoryOutput,
    parse: toolBatchItems,
    run: (items, ctx) => runToolBatch(
      items,
      (item) => _updateCategory(_parseUpdateCategory(item), ctx),
    ),
  ),
  ToolDef(
    name: 'delete_category',
    title: 'Delete a category',
    description: (_) =>
        '$toolBatchDescription'
        'Deletes categories in ids (1–20). Their entries become uncategorized.',
    input: (_) => S.object(
      properties: {'ids': toolIdsSchema(requiredCategoryIdSchema)},
      required: ['ids'],
    ),
    surfaces: const {ToolSurface.assistant, ToolSurface.mcp},
    effect: ToolEffect.destructive,
    idempotent: true,
    output: _deleteCategoryOutput,
    parse: toolBatchIds,
    run: (items, ctx) => runToolBatch(
      items,
      (item) => _deleteCategory(
        ToolArguments('delete_category', item).requireText('id'),
        ctx,
      ),
    ),
  ),
];

Future<ToolResult> _listCategories(ToolContext ctx) async {
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
  return ToolResult({'category': categoryInfo(category, diaryCount: 0)});
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
    return ToolResult({'category': categoryInfo(category)});
  } on DiaryOpsException catch (e) {
    return switch (e.failure) {
      DiaryOpsFailure.notFound => toolFailure(
        'update_category: no category with id="$id".',
      ),
      DiaryOpsFailure.noChanges => throw const ToolArgumentException(
        'update_category: provide at least one of name, color',
      ),
      _ => toolFailure('update_category: could not update.'),
    };
  }
}

Future<ToolResult> _deleteCategory(String id, ToolContext ctx) async {
  final categories = ctx.categories;
  final ops = CategoryOps(categories: categories);
  try {
    final result = await ops.delete(id);
    if (!result.deleted) {
      throw const ToolFailure('the category could not be deleted');
    }
    return ToolResult({'id': id, 'name': result.category.categoryName});
  } on DiaryOpsException {
    return toolFailure('delete_category: no category with id="$id".');
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

final _listCategoriesOutput = objectSchema({
  'categories': listOutputSchema(categoryOutputSchema),
  'total': integerOutputSchema,
});

final _createCategoryOutput = batchOutputSchema(
  objectSchema({'category': categoryOutputSchema}),
);

final _updateCategoryOutput = batchOutputSchema(
  objectSchema({'category': categoryOutputSchema}),
);

final _deleteCategoryOutput = batchOutputSchema(
  objectSchema({'id': stringOutputSchema, 'name': stringOutputSchema}),
);
