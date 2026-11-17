import 'package:json_schema_builder/json_schema_builder.dart';

import 'tool_def.dart';

Schema batchItemsSchema(Map<String, Object?> item) => Schema.fromMap({
  'type': 'object',
  'properties': {
    'items': {'type': 'array', 'minItems': 1, 'maxItems': 20, 'items': item},
  },
  'required': ['items'],
  'additionalProperties': false,
});

Map<String, Object?> toolIdsSchema(Map<String, Object?> id, {int max = 20}) => {
  'type': 'array',
  'minItems': 1,
  'maxItems': max,
  'items': id,
};

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
      final failed = result.data['deleted'] == false;
      results.add({
        if (item['id'] != null) 'id': item['id'],
        'ok': !failed,
        ...result.data,
        if (failed) 'error': result.data['reason'],
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
