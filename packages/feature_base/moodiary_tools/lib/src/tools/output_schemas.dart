import 'package:flutter/foundation.dart' show internal;
import 'package:json_schema_builder/json_schema_builder.dart';

const _string = {'type': 'string'};
const _integer = {'type': 'integer'};
const _boolean = {'type': 'boolean'};
const _nullableString = {
  'type': ['string', 'null'],
};
const _nullableInteger = {
  'type': ['integer', 'null'],
};

Map<String, Object?> _list(Map<String, Object?> item) => {
  'type': 'array',
  'items': item,
};
Map<String, Object?> _object(
  Map<String, Object?> properties, {
  List<String> optional = const [],
}) => {
  'type': 'object',
  'properties': properties,
  'required': properties.keys.where((key) => !optional.contains(key)).toList(),
  'additionalProperties': false,
};

final _summaryFields = <String, Object?>{
  'id': _string,
  'title': _string,
  'time': _string,
  'timeLocal': _string,
  'lastModified': _string,
  'categoryId': _nullableString,
  'categoryName': _nullableString,
  'mood': _nullableString,
  'tags': _list(_string),
  'excerpt': _string,
  'show': _boolean,
};
final _summary = _object(_summaryFields, optional: ['excerpt']);
final _category = _object({
  'id': _string,
  'name': _string,
  'color': _nullableInteger,
  'colorHex': _nullableString,
  'lastModified': _string,
  'diaries': _nullableInteger,
});
final _mediaLists = _object({
  for (final key in ['images', 'audio', 'videos', 'files']) key: _list(_string),
});
final _link = _object({
  'id': _string,
  'title': _string,
  'time': _string,
  'timeLocal': _string,
});
final _links = _object({
  'forward': _list(_link),
  'backlinks': _list(_link),
  'dangling': _list(_string),
});
final _mediaEntry = _object({
  'name': _string,
  'mimeType': _string,
  'bytes': _integer,
  'exists': _boolean,
});

@internal
Schema toolOutputSchema(String name) => Schema.fromMap(switch (name) {
  'list_diaries' => _object({
    'diaries': _list(_summary),
    'count': _integer,
    'offset': _integer,
    'limit': _integer,
    'hasMore': _boolean,
  }),
  'get_diary' => _object(
    {
      ..._summaryFields,
      'type': _string,
      'contentFormat': _string,
      'content': {
        'type': ['string', 'object'],
      },
      'contentTruncated': _boolean,
      'placeId': _nullableString,
      'weather': _object({
        'icon': _string,
        'temp': _nullableString,
        'text': _string,
      }),
      'media': _mediaLists,
      'links': _links,
      'uri': _string,
    },
    optional: ['excerpt', 'weather', 'links'],
  ),
  'create_diary' => _object({'created': _boolean, 'diary': _summary}),
  'update_diary' => _object({'updated': _boolean, 'diary': _summary}),
  'delete_diary' => _object(
    {
      'deleted': _boolean,
      'id': _string,
      'title': _string,
      'alreadyRecycled': _boolean,
    },
    optional: ['alreadyRecycled'],
  ),
  'search_diaries' => _object({
    'query': _string,
    'total': _integer,
    'offset': _integer,
    'limit': _integer,
    'hasMore': _boolean,
    'hits': _list(
      _object(
        {..._summaryFields, 'titleHighlight': _string, 'preview': _string},
        optional: ['preview'],
      ),
    ),
  }),
  'get_diary_links' => _object({
    'id': _string,
    'title': _string,
    'time': _string,
    'timeLocal': _string,
    ...(_links['properties']! as Map<String, Object?>),
  }),
  'list_tags' => _object({
    'tags': _list(_object({'tag': _string, 'diaries': _integer})),
    'count': _integer,
    'totalDistinct': _integer,
    'scannedDiaries': _integer,
    'note': _string,
  }),
  'list_categories' => _object({
    'categories': _list(_category),
    'total': _integer,
  }),
  'create_category' => _object({'created': _boolean, 'category': _category}),
  'update_category' => _object({'updated': _boolean, 'category': _category}),
  'delete_category' => _object(
    {'deleted': _boolean, 'id': _string, 'name': _string, 'reason': _string},
    optional: ['reason'],
  ),
  'list_diary_media' => _object({
    'id': _string,
    'title': _string,
    'media': _object({
      for (final key in ['images', 'audio', 'videos', 'files'])
        key: _list(_mediaEntry),
    }),
    'count': _integer,
  }),
  'read_diary_media' => _object({
    'id': _string,
    'title': _string,
    'name': _string,
    'kind': _string,
    'mimeType': _string,
    'bytes': _integer,
    'exists': _boolean,
  }),
  'add_diary_image' || 'add_diary_attachment' => _object({
    'added': _boolean,
    'name': _string,
    'mimeType': _string,
    'bytes': _integer,
    'diary': _object({'id': _string, 'title': _string, 'media': _mediaLists}),
  }),
  'get_stats' => _object({
    for (final key in [
      'totalDiaries',
      'visibleDiaries',
      'recycleBinDiaries',
      'uncategorizedDiaries',
      'olderDiaries',
      'futureDiaries',
    ])
      key: _integer,
    'firstDiaryTime': _nullableString,
    'months': _list(_object({'month': _string, 'diaries': _integer})),
    'monthsWindow': _object({'from': _string, 'to': _string}),
    'categories': _list(
      _object({
        'categoryId': _string,
        'categoryName': _nullableString,
        'diaries': _integer,
      }),
    ),
    'moods': _object({
      'distribution': _object({
        for (final mood in ['awful', 'bad', 'okay', 'good', 'great'])
          mood: _integer,
      }),
      'recordedDiaries': _integer,
      'diariesWithoutMood': _integer,
      'averageScore': {
        'type': ['number', 'null'],
      },
      'recordedDays': _integer,
    }),
    'generatedAt': _string,
  }),
  _ => throw ArgumentError.value(name, 'name', 'Unknown tool'),
});
