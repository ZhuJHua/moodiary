/// Category tools: the category tree plus create, update and delete.
library;

import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_diary_ops/moodiary_diary_ops.dart';

import '../protocol/json_rpc.dart';
import '../protocol/mcp_types.dart';
import '../registry/mcp_registry.dart';
import 'arguments.dart';
import 'schemas.dart';

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
          'parent) with id, name, parent id, ARGB colour, colour hex and two '
          'counts: diaries is the number of visible diaries filed directly in '
          'the category, diariesTotal also counts the diaries of every '
          'descendant, so a parent never looks emptier than its children. total '
          'is the number of categories, not of diaries.',
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
          'existing category id; omit it (or send null) for a root category. '
          'color accepts a 32 bit ARGB integer or a #RRGGBB / #AARRGGBB '
          'string, and an unknown parent is invalid params.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'name': categoryNameSchema,
          'parentId': parentIdSchema,
          'color': colorSchema,
        },
        'required': ['name'],
      },
    ),
    (call, arguments) async {
      final args = Args('create_category', arguments);
      final name = args.requireText('name');
      final parentId = args.optionalText('parentId');
      final color = args.optionalColor('color');
      try {
        final category = await ops.create(
          name: name,
          parentId: parentId,
          color: color,
        );
        return McpToolResult.json({
          'created': true,
          'category': categoryInfo(category, diaryCount: 0),
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
          'Renames, recolours or reparents one category and leaves every '
          'omitted field unchanged. Send null (or an empty string) for color or '
          'parentId to clear it: parentId null makes the category a root '
          'category. Refuses a parent that would create a cycle and requires at '
          'least one of name, color and parentId.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'id': {
            'type': 'string',
            'description': 'Category id as list_categories returns it.',
          },
          'name': categoryNameSchema,
          'color': colorSchema,
          'parentId': parentIdSchema,
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
          color: args.has('color') ? args.optionalColor('color') : null,
          colorSet: args.has('color'),
          parentId: args.has('parentId') ? args.optionalText('parentId') : null,
          parentSet: args.has('parentId'),
        );
        return McpToolResult.json({
          'updated': true,
          'category': categoryInfo(category),
        });
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
          'reports the refusal in reason and nothing changes. A successful '
          'delete re-homes the child categories to the root category and lists '
          'their ids in reparentedChildren, which is what the database now '
          'holds.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'id': {
            'type': 'string',
            'description': 'Category id as list_categories returns it.',
          },
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
            'reparentedChildren': const <String>[],
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
          'reparentedChildren': [
            for (final child in result.reparented) child.id,
          ],
        });
      } on DiaryOpsException {
        return McpToolResult.error(
          'delete_category: no category with id="$id".',
        );
      }
    },
  );
}
