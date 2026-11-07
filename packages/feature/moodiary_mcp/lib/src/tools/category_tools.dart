/// Category tools: the category tree plus create, update and delete.
library;

import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';

import '../protocol/json_rpc.dart';
import '../protocol/mcp_types.dart';
import '../registry/mcp_registry.dart';
import 'arguments.dart';
import 'diary_format.dart';

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
    (call, arguments) =>
        _listCategories(categories: categories, diaries: diaries),
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
    (call, arguments) => _createCategory(arguments, categories: categories),
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
    (call, arguments) => _updateCategory(arguments, categories: categories),
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
    (call, arguments) => _deleteCategory(arguments, categories: categories),
  );
}

/// The `moodiary://categories` payload, also returned by `list_categories`.
Future<Map<String, dynamic>> categoryTreePayload(
  CategoryRepository categories,
  DiaryRepository diaries,
) async {
  final all = await categories.getAllCategories();
  final counts = (await diaries.diaryCountByCategory()).byCategory;
  return {'categories': _tree(all, counts), 'total': all.length};
}

List<Map<String, dynamic>> _tree(List<Category> all, Map<String, int> counts) {
  final ids = {for (final category in all) category.id};
  final childrenOf = <String?, List<Category>>{};
  for (final category in all) {
    final parent = category.parentId;
    final key = parent != null && parent != category.id && ids.contains(parent)
        ? parent
        : null;
    childrenOf.putIfAbsent(key, () => []).add(category);
  }

  Map<String, dynamic> node(Category category, Set<String> path) {
    final children = <Map<String, dynamic>>[];
    for (final child in childrenOf[category.id] ?? const <Category>[]) {
      if (path.contains(child.id)) continue;
      children.add(node(child, {...path, child.id}));
    }
    return categoryInfo(
      category,
      diaryCount: counts[category.id] ?? 0,
      children: children,
    );
  }

  return [
    for (final root in childrenOf[null] ?? const <Category>[])
      node(root, {root.id}),
  ];
}

/// One category as the catalog shows it.
Map<String, dynamic> categoryInfo(
  Category category, {
  int? diaryCount,
  List<Map<String, dynamic>> children = const [],
}) => {
  'id': category.id,
  'name': category.categoryName,
  'parentId': category.parentId,
  'color': category.color,
  'colorHex': colorHex(category.color),
  'lastModified': isoUtc(category.lastModified),
  'diaries': diaryCount,
  'children': children,
};

Future<McpToolResult> _listCategories({
  required CategoryRepository categories,
  required DiaryRepository diaries,
}) async => McpToolResult.json(await categoryTreePayload(categories, diaries));

Future<McpToolResult> _createCategory(
  Map<String, dynamic> arguments, {
  required CategoryRepository categories,
}) async {
  final args = Args('create_category', arguments);
  final name = args.requireText('name');
  final parentId = args.optionalText('parentId');
  final color = args.optionalArgb('color');
  if (parentId != null) {
    await _requireCategory(categories, parentId, 'create_category');
  }

  final category = Category.create(
    categoryName: name,
    parentId: parentId,
    color: color,
  );
  await categories.insertACategory(category);
  return McpToolResult.json({
    'created': true,
    ...categoryInfo(category, diaryCount: 0),
  });
}

Future<McpToolResult> _updateCategory(
  Map<String, dynamic> arguments, {
  required CategoryRepository categories,
}) async {
  final args = Args('update_category', arguments);
  final id = args.requireText('id');
  final existing = await categories.getCategoryById(id);
  if (existing == null) {
    return McpToolResult.error('update_category: no category with id="$id".');
  }

  var next = existing;
  var changed = false;
  if (args.contains('name')) {
    next = next.copyWith(categoryName: args.requireText('name'));
    changed = true;
  }
  if (args.contains('color')) {
    next = next.copyWith(color: args.optionalArgb('color'));
    changed = true;
  }
  if (args.contains('parentId')) {
    final parentId = args.optionalText('parentId');
    if (parentId != null) {
      await _requireCategory(categories, parentId, 'update_category');
      await _rejectCycle(categories, id, parentId);
    }
    next = next.copyWith(parentId: parentId);
    changed = true;
  }
  if (!changed) {
    throw const JsonRpcException(
      JsonRpcCode.invalidParams,
      'update_category: provide at least one of name, color, parentId',
    );
  }

  next = next.copyWith(lastModified: DateTime.timestamp());
  await categories.insertACategory(next);
  return McpToolResult.json({'updated': true, ...categoryInfo(next)});
}

Future<McpToolResult> _deleteCategory(
  Map<String, dynamic> arguments, {
  required CategoryRepository categories,
}) async {
  final args = Args('delete_category', arguments);
  final id = args.requireText('id');
  final existing = await categories.getCategoryById(id);
  if (existing == null) {
    return McpToolResult.error('delete_category: no category with id="$id".');
  }
  final all = await categories.getAllCategories();
  final children = all.where((category) => category.parentId == id).length;
  final removed = await categories.deleteACategory(id);
  if (!removed) {
    return McpToolResult.json({
      'deleted': false,
      'id': id,
      'name': existing.categoryName,
      'reason':
          'the app refuses to delete a category that still holds diaries, '
          'including diaries in the recycle bin; move those diaries to another '
          'category first',
    });
  }
  return McpToolResult.json({
    'deleted': true,
    'id': id,
    'name': existing.categoryName,
    'reparentedChildren': children,
  });
}

Future<void> _requireCategory(
  CategoryRepository categories,
  String id,
  String subject,
) async {
  final category = await categories.getCategoryById(id);
  if (category == null) {
    throw JsonRpcException(
      JsonRpcCode.invalidParams,
      '$subject: no category with id="$id"; call list_categories first',
    );
  }
}

/// Walks up from the prospective parent; reaching [id] would close a cycle.
Future<void> _rejectCycle(
  CategoryRepository categories,
  String id,
  String parentId,
) async {
  final seen = <String>{id};
  var cursor = parentId;
  while (true) {
    if (!seen.add(cursor)) {
      throw JsonRpcException(
        JsonRpcCode.invalidParams,
        'update_category: parentId "$parentId" would create a category cycle',
      );
    }
    final parent = await categories.getCategoryById(cursor);
    final next = parent?.parentId;
    if (next == null || next.isEmpty) return;
    cursor = next;
  }
}
