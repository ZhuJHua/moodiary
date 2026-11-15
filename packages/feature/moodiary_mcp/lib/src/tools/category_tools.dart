/// Category tools: list, create, update and delete.
library;

import 'package:mcp_dart/mcp_dart.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_diary_ops/moodiary_diary_ops.dart';

import 'arguments.dart';
import 'category_queries.dart';
import 'diary_payloads.dart';
import 'mcp_results.dart';
import 'schemas.dart';

void registerCategoryTools(
  McpServer server, {
  required CategoryRepository categories,
  required DiaryRepository diaries,
}) {
  final ops = CategoryOps(categories: categories);

  server.registerTool(
    'list_categories',
    title: 'List categories',
    description:
        'Lists every diary category with id, name, ARGB colour, colour hex '
        'and its visible diary count. total is the number of categories.',
    inputSchema: const ToolArgumentSchema({'type': 'object', 'properties': {}}),
    annotations: const ToolAnnotations(
      readOnlyHint: true,
      destructiveHint: false,
      idempotentHint: true,
      openWorldHint: false,
    ),
    callback: (arguments, call) async {
      final listed = await McpCategoryQueries(
        categories: categories,
        diaries: diaries,
      ).list();
      return jsonToolResult({
        'categories': listed.categories,
        'total': listed.total,
      });
    },
  );

  server.registerTool(
    'create_category',
    title: 'Create a category',
    description:
        'Creates one diary category. color accepts a 32 bit ARGB integer '
        'or a #RRGGBB / #AARRGGBB string.',
    inputSchema: const ToolArgumentSchema({
      'type': 'object',
      'properties': {'name': categoryNameSchema, 'color': colorSchema},
      'required': ['name'],
    }),
    annotations: const ToolAnnotations(
      readOnlyHint: false,
      destructiveHint: false,
      idempotentHint: false,
      openWorldHint: false,
    ),
    callback: (arguments, call) async {
      final args = Args('create_category', arguments);
      final name = args.requireText('name');
      final color = args.optionalColor('color');
      final category = await ops.create(name: name, color: color);
      return jsonToolResult({
        'created': true,
        'category': categoryInfo(category, diaryCount: 0),
      });
    },
  );

  server.registerTool(
    'update_category',
    title: 'Update a category',
    description:
        'Renames or recolours one category, leaving omitted fields unchanged. '
        'Send null (or an empty string) for color to clear it. Requires at '
        'least one of name and color.',
    inputSchema: const ToolArgumentSchema({
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
    annotations: const ToolAnnotations(
      readOnlyHint: false,
      destructiveHint: false,
      idempotentHint: true,
      openWorldHint: false,
    ),
    callback: (arguments, call) async {
      final args = Args('update_category', arguments);
      final id = args.requireText('id');
      try {
        final category = await ops.update(
          id: id,
          name: args.contains('name') ? args.requireText('name') : null,
          color: args.has('color') ? args.optionalColor('color') : null,
          colorSet: args.has('color'),
        );
        return jsonToolResult({
          'updated': true,
          'category': categoryInfo(category),
        });
      } on DiaryOpsException catch (e) {
        return switch (e.failure) {
          DiaryOpsFailure.notFound => toolError(
            'update_category: no category with id="$id".',
          ),
          DiaryOpsFailure.noChanges => throw McpError(
            ErrorCode.invalidParams.value,
            'update_category: provide at least one of name, color',
          ),
          _ => toolError('update_category: could not update.'),
        };
      }
    },
  );

  server.registerTool(
    'delete_category',
    title: 'Delete a category',
    description:
        'Deletes one empty category. Refuses categories holding diaries, '
        'including those in the recycle bin, and reports the reason.',
    inputSchema: const ToolArgumentSchema({
      'type': 'object',
      'properties': {
        'id': {
          'type': 'string',
          'description': 'Category id as list_categories returns it.',
        },
      },
      'required': ['id'],
    }),
    annotations: const ToolAnnotations(
      readOnlyHint: false,
      destructiveHint: true,
      idempotentHint: true,
      openWorldHint: false,
    ),
    callback: (arguments, call) async {
      final args = Args('delete_category', arguments);
      final id = args.requireText('id');
      try {
        final result = await ops.delete(id);
        if (!result.deleted) {
          return jsonToolResult({
            'deleted': false,
            'id': id,
            'name': result.category.categoryName,
            'reason':
                'the app refuses to delete a category that still holds diaries, '
                'including diaries in the recycle bin; move those diaries to '
                'another category first',
          });
        }
        return jsonToolResult({
          'deleted': true,
          'id': id,
          'name': result.category.categoryName,
        });
      } on DiaryOpsException {
        return toolError('delete_category: no category with id="$id".');
      }
    },
  );
}
