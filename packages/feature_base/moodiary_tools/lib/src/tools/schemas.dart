library;

import 'package:json_schema_builder/json_schema_builder.dart';

import '../ops/diary_display.dart';
import 'tool_values.dart';

const List<String> excerptValues = ['plain', 'markdown', 'none'];

const List<String> diarySearchSortValues = [
  'relevance',
  'newest',
  'oldest',
  'modified',
];

const List<String> diarySearchModeValues = ['auto', 'keyword', 'meaning'];

const List<String> contentFormatValues = ['markdown', 'text', 'document'];

const List<String> linkStyleValues = ['uri', 'label'];

final Schema diaryIdSchema = S.string(
  description: 'Diary id (uuid v7) as returned by search_diaries or get_diary.',
);

final Schema requiredCategoryIdSchema = S.string(
  description: 'Category id as returned by list_categories.',
);

final Schema categoryIdSchema = S.combined(
  anyOf: [requiredCategoryIdSchema, S.nil()],
  description:
      'Category id as list_categories returns it. Unknown ids fail the item '
      'on writes or the call on search; call list_categories first. null means '
      'no search filter, or an uncategorized diary in the write '
      'tools.',
);

final Schema startDateSchema = nullableSchema(
  S.string(
    description:
        'Inclusive ISO-8601 lower bound on the diary time. A bare yyyy-MM-dd '
        'means local midnight of that day.',
  ),
  JsonType.string,
);

final Schema endDateSchema = nullableSchema(
  S.string(
    description:
        'Inclusive ISO-8601 upper bound on the diary time. A bare yyyy-MM-dd '
        'covers that whole local day.',
  ),
  JsonType.string,
);

final Schema limitSchema = nullableSchema(
  schemaWithDefault(
    S.integer(
      description: 'Page size, clamped to ${pageLimit.min}..${pageLimit.max}.',
    ),
    pageLimit.fallback,
  ),
  JsonType.int,
);

final Schema offsetSchema = nullableSchema(
  schemaWithDefault(
    S.integer(
      description:
          'Number of matching diaries to skip, clamped to ${pageOffset.min}..${pageOffset.max}.',
    ),
    pageOffset.fallback,
  ),
  JsonType.int,
);

final Schema readContentFormatSchema = nullableSchema(
  schemaWithDefault(
    S.string(
      enumValues: contentFormatValues,
      description:
          'Representation actually returned: markdown (converted from the stored '
          'editor document), text (no syntax, media as [image: name] placeholders) '
          'or document (the raw stored Tiptap JSON object, which counts against '
          'the result size limit).',
    ),
    'markdown',
  ),
  JsonType.string,
);

final Schema writeContentFormatSchema = nullableSchema(
  schemaWithDefault(
    S.string(
      enumValues: contentFormatValues,
      description:
          'How content is interpreted: markdown (default) parses it and stores the '
          'editor document so formatting survives, text stores literal paragraphs '
          'so Markdown syntax stays visible, document takes a Tiptap document JSON '
          'object and rejects anything else. Applies to content only.',
    ),
    'markdown',
  ),
  JsonType.string,
);

final Schema linkStyleSchema = nullableSchema(
  schemaWithDefault(
    S.string(
      enumValues: linkStyleValues,
      description:
          'How a diary mention is rendered: uri (default) keeps the target as '
          '[label](moodiary://diary/<id>) in Markdown and "label (uri)" in text, '
          'label keeps only the label.',
    ),
    'uri',
  ),
  JsonType.string,
);

final Schema excerptSchema = nullableSchema(
  schemaWithDefault(
    S.string(
      enumValues: excerptValues,
      description:
          'Preview of every entry: plain (default) is one line of plain text, '
          'markdown is the Markdown body so headings and lists survive, and none '
          'drops the preview. Both forms are cut to $excerptChars characters. '
          'Keyword search keeps its highlighted excerpt regardless of this option.',
    ),
    'plain',
  ),
  JsonType.string,
);

final Schema moodSchema = S.combined(
  description:
      'Mood as ${toolMoodNames.join(', ')}, or as a score from 1 to 5. '
      'Send null (or an empty string) to clear it.',
  oneOf: [
    S.string(
      pattern:
          r'^\s*(?:' +
          toolMoodNames
              .map(
                (name) => name
                    .split('')
                    .map((letter) => '[$letter${letter.toUpperCase()}]')
                    .join(),
              )
              .join('|') +
          r'|[1-5])?\s*$',
    ),
    S.integer(minimum: 1, maximum: 5),
    S.nil(),
  ],
);

final Schema tagsSchema = nullableSchema(
  S.list(
    items: S.string(),
    description:
        'Replaces the whole tag list, in the order given; send null or an empty '
        'array to clear every tag. Use list_tags to read existing tags before '
        'choosing or changing them.',
  ),
  JsonType.list,
);

final Schema colorSchema = S.combined(
  description:
      'Category colour as a 32 bit ARGB integer (e.g. 4278233312), as #RRGGBB '
      'for an opaque colour or as #AARRGGBB for one with alpha. Send null or an '
      'empty string to clear the colour; create_category has no colour unless '
      'one is sent, and update_category leaves it unchanged when the argument '
      'is omitted.',
  oneOf: [S.integer(minimum: 0, maximum: 4294967295), S.string(), S.nil()],
);

final Schema categoryNameSchema = S.string(
  description: 'Category name; must not be empty.',
);

final Schema tagLimitSchema = nullableSchema(
  schemaWithDefault(
    S.integer(
      description:
          'Number of tags to return, clamped to ${tagLimit.min}..${tagLimit.max}.',
    ),
    tagLimit.fallback,
  ),
  JsonType.int,
);

final Schema statsMonthsSchema = nullableSchema(
  schemaWithDefault(
    S.integer(
      description:
          'How many local calendar months the per-month counts cover, including '
          'the current month, clamped to ${statsMonths.min}..${statsMonths.max}.',
    ),
    statsMonths.fallback,
  ),
  JsonType.int,
);

final Schema mediaNameSchema = S.string(
  description:
      'Media file name exactly as list_diary_media shows it, e.g. '
      '"image-018f...png". Paths are rejected.',
);

final Schema diarySearchSortSchema = nullableSchema(
  S.string(
    enumValues: diarySearchSortValues,
    description: 'Defaults to relevance with query, newest when browsing. modified orders by last modification.',
  ),
  JsonType.string,
);

final Schema diaryTimeSchema = nullableSchema(
  S.string(
    description:
        'YYYY-MM-DD uses the current local time of day on create and keeps the '
        'existing local time of day on update; ISO-8601 datetimes without an '
        'offset are local, while an offset or Z is converted to local time. '
        'Omit or send null for now on create or to keep the time on update; '
        'future dates are allowed.',
  ),
  JsonType.string,
);

Schema schemaWithDefault(Schema schema, Object value) {
  schema.value.addAll(S.combined(defaultValue: value).value);
  return schema;
}

Schema nullableSchema(Schema schema, JsonType type) {
  final values = schema.value['enum'] as List?;
  return S.combined(
    type: [type, JsonType.nil],
    anyOf: [
      schema,
      if (values != null)
        S.string(
          pattern:
              r'^\s*(?:' +
              values.map((value) => RegExp.escape(value as String)).join('|') +
              r')?\s*$',
        ),
      S.nil(),
    ],
  );
}
