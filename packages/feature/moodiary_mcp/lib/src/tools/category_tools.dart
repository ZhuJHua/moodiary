/// Category tools: the category tree plus create, update and delete.
library;

import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_diary_ops/moodiary_diary_ops.dart';

import '../protocol/json_rpc.dart';
import '../protocol/mcp_types.dart';
import '../registry/mcp_registry.dart';
import 'arguments.dart';

const Map<String, dynamic> _nameSchema = {
  'type': 'string',
  'description': 'Category name; must not be empty.',
};

const Map<String, dynamic> _parentIdSchema = {
  'type': 'string',
  'description':
      'Id of the parent category. An empty string makes the category a root '
      'category.',
};

const Map<String, dynamic> _colorSchema = {
  'type': 'integer',
  'description':
      'Category colour as a 32 bit ARGB integer, e.g. 4278233312 for an '
      'opaque colour. An empty string clears it.',
};

void registerCategoryTools(
  McpRegistry registry, {
  required CategoryRepository categories,
  required DiaryRepository diaries,
}) {
  final ops = CategoryOps(categories: categories, diaries: diaries);

  registry.addTool(
    const McpTool(
      name: 'list_categories',
      title: 'List categories',
      description:
          'Lists every diary category as a tree (children nested under their '
          'parent) with id, name, parent id, ARGB colour, colour hex and the '
          'number of visible diaries in each category.',
      inputSchema: {'type': 'object', 'properties': {}},
      readOnly: true,
      idempotent: true,
    ),
    (call, arguments) async {
      final tree = await ops.tree();
      return McpToolResult.json({
        'categories': tree.categories,
        'total': tree.total,
      });
    },
  );

  registry.addTool(
    const McpTool(
      name: 'create_category',
      title: 'Create a category',
      description:
          'Creates one diary category and returns it. parentId must be an '
          'existing category id.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'name': _nameSchema,
          'parentId': _parentIdSchema,
          'color': _colorSchema,
        },
        'required': ['name'],
      },
    ),
    (call, arguments) async {
      final args = Args('create_category', arguments);
      final name = args.requireText('name');
      final parentId = args.optionalText('parentId');
      final color = args.optionalArgb('color');
      try {
        final category = await ops.create(
          name: name,
          parentId: parentId,
          color: color,
        );
        return McpToolResult.json({
          'created': true,
          ...categoryInfo(category, diaryCount: 0),
        });
      } on DiaryOpsException catch (e) {
        if (e.failure == DiaryOpsFailure.notFound) {
          throw JsonRpcException(
            JsonRpcCode.invalidParams,
            'create_category: no category with id="${e.categoryId}"; call '
            'list_categories first',
          );
        }
        rethrow;
      }
    },
  );

  registry.addTool(
    const McpTool(
      name: 'update_category',
      title: 'Update a category',
      description:
          'Renames, recolours or reparents one category and leaves the other '
          'fields alone. Send an empty string for parentId or color to clear '
          'it. Refuses a parent that would create a cycle.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'id': {'type': 'string', 'description': 'Category id.'},
          'name': _nameSchema,
          'color': _colorSchema,
          'parentId': _parentIdSchema,
        },
        'required': ['id'],
      },
      idempotent: true,
    ),
    (call, arguments) async {
      final args = Args('update_category', arguments);
      final id = args.requireText('id');
      try {
        final category = await ops.update(
          id: id,
          name: args.contains('name') ? args.requireText('name') : null,
          nameSet: args.contains('name'),
          color: args.contains('color') ? args.optionalArgb('color') : null,
          colorSet: args.contains('color'),
          parentId: args.contains('parentId')
              ? args.optionalText('parentId')
              : null,
          parentSet: args.contains('parentId'),
        );
        return McpToolResult.json({'updated': true, ...categoryInfo(category)});
      } on DiaryOpsException catch (e) {
        return switch (e.failure) {
          DiaryOpsFailure.notFound => McpToolResult.error(
            'update_category: no category with id="$id".',
          ),
          DiaryOpsFailure.invalidCategory => throw JsonRpcException(
            JsonRpcCode.invalidParams,
            'update_category: no category with id="${e.categoryId}"; call '
            'list_categories first',
          ),
          DiaryOpsFailure.categoryCycle => throw JsonRpcException(
            JsonRpcCode.invalidParams,
            'update_category: parentId "${e.categoryId}" would create a '
            'category cycle',
          ),
          DiaryOpsFailure.noChanges => throw const JsonRpcException(
            JsonRpcCode.invalidParams,
            'update_category: provide at least one of name, color, parentId',
          ),
          _ => McpToolResult.error('update_category: could not update.'),
        };
      }
    },
  );

  registry.addTool(
    const McpTool(
      name: 'delete_category',
      title: 'Delete a category',
      description:
          'Deletes one empty category. The app refuses to delete a category '
          'that still holds diaries (in the recycle bin too); the result then '
          'reports the refusal instead of deleting anything. Child categories '
          'are left in place and become root categories.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'id': {'type': 'string', 'description': 'Category id.'},
        },
        'required': ['id'],
      },
      destructive: true,
      idempotent: true,
    ),
    (call, arguments) async {
      final args = Args('delete_category', arguments);
      final id = args.requireText('id');
      try {
        final result = await ops.delete(id);
        if (!result.deleted) {
          return McpToolResult.json({
            'deleted': false,
            'id': id,
            'name': result.category.categoryName,
            'reason':
                'the app refuses to delete a category that still holds diaries, '
                'including diaries in the recycle bin; move those diaries to '
                'another category first',
          });
        }
        return McpToolResult.json({
          'deleted': true,
          'id': id,
          'name': result.category.categoryName,
          'reparentedChildren': result.children,
        });
      } on DiaryOpsException {
        return McpToolResult.error(
          'delete_category: no category with id="$id".',
        );
      }
    },
  );
}
