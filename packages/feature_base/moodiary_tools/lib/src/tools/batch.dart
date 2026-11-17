import 'package:json_schema_builder/json_schema_builder.dart';

import 'tool_def.dart';

const toolBatchDescription =
    'Pass every item in one call. Each result has ok and an error on failure; '
    'do not repeat items that already succeeded. ';

Schema batchItemsSchema(Schema item) => S.object(
  properties: {'items': S.list(minItems: 1, maxItems: 20, items: item)},
  required: ['items'],
  additionalProperties: false,
);

Schema toolIdsSchema(Schema id, {int max = 20}) =>
    S.list(minItems: 1, maxItems: max, items: id);

List<Map<String, Object?>> toolBatchItems(Map<String, Object?> raw) => [
  for (final item in raw['items']! as List)
    (item as Map).cast<String, Object?>(),
];

List<Map<String, Object?>> toolBatchIds(Map<String, Object?> raw) => [
  for (final id in raw['ids']! as List) {'id': id},
];

Future<ToolResult> runToolBatch(
  List<Map<String, Object?>> items,
  Future<ToolResult> Function(Map<String, Object?>) run,
) async {
  final results = <Map<String, Object?>>[];
  for (final item in items) {
    try {
      final result = await run(item);
      results.add({
        if (item['id'] != null) 'id': item['id'],
        'ok': true,
        ...result.data,
      });
    } catch (error) {
      results.add({
        if (item['id'] != null) 'id': item['id'],
        'ok': false,
        'error': '$error',
      });
    }
  }
  return ToolResult({
    'results': results,
    'processed': results.length,
    'requested': items.length,
  });
}
