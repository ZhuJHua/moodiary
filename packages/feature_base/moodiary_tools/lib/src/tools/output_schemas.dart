import 'package:json_schema_builder/json_schema_builder.dart';

final stringOutputSchema = S.string();
final integerOutputSchema = S.integer();
final booleanOutputSchema = S.boolean();
final nullableStringOutputSchema = S.combined(
  type: [JsonType.string, JsonType.nil],
);
final nullableIntegerOutputSchema = S.combined(
  type: [JsonType.int, JsonType.nil],
);

Schema listOutputSchema(Schema item) => S.list(items: item);
ObjectSchema objectSchema(
  Map<String, Schema> properties, {
  List<String> optional = const [],
}) => ObjectSchema(
  properties: properties,
  required: properties.keys.where((key) => !optional.contains(key)).toList(),
  additionalProperties: false,
);

final diarySummaryFields = <String, Schema>{
  'id': stringOutputSchema,
  'title': stringOutputSchema,
  'time': stringOutputSchema,
  'timeLocal': stringOutputSchema,
  'lastModified': stringOutputSchema,
  'categoryId': nullableStringOutputSchema,
  'categoryName': nullableStringOutputSchema,
  'mood': nullableStringOutputSchema,
  'tags': listOutputSchema(stringOutputSchema),
  'excerpt': stringOutputSchema,
  'show': booleanOutputSchema,
};
final diarySummarySchema = objectSchema(
  diarySummaryFields,
  optional: ['excerpt'],
);
final categoryOutputSchema = objectSchema({
  'id': stringOutputSchema,
  'name': stringOutputSchema,
  'color': nullableIntegerOutputSchema,
  'colorHex': nullableStringOutputSchema,
  'lastModified': stringOutputSchema,
  'diaries': nullableIntegerOutputSchema,
});
final mediaListsOutputSchema = objectSchema({
  for (final key in ['images', 'audio', 'videos', 'files'])
    key: listOutputSchema(stringOutputSchema),
});
final linkOutputSchema = objectSchema({
  'id': stringOutputSchema,
  'title': stringOutputSchema,
  'time': stringOutputSchema,
  'timeLocal': stringOutputSchema,
});
final linksOutputSchema = objectSchema({
  'forward': listOutputSchema(linkOutputSchema),
  'backlinks': listOutputSchema(linkOutputSchema),
  'dangling': listOutputSchema(stringOutputSchema),
});
final mediaEntryOutputSchema = objectSchema({
  'name': stringOutputSchema,
  'mimeType': stringOutputSchema,
  'bytes': integerOutputSchema,
  'exists': booleanOutputSchema,
});

Schema batchOutputSchema(ObjectSchema payload) {
  final fields = payload.properties!;
  final required = payload.required!;
  return objectSchema({
    'results': listOutputSchema(
      S.combined(
        oneOf: [
          objectSchema(
            {
              'ok': S.combined(constValue: true),
              'id': stringOutputSchema,
              ...fields,
            },
            optional: [
              'id',
              ...fields.keys.where((key) => !required.contains(key)),
            ],
          ),
          objectSchema(
            {
              'ok': S.combined(constValue: false),
              'error': stringOutputSchema,
              'id': stringOutputSchema,
              ...fields,
            },
            optional: ['id', ...fields.keys],
          ),
        ],
      ),
    ),
    'processed': integerOutputSchema,
    'requested': integerOutputSchema,
  });
}
