library;

import '../ops/diary_display.dart';

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

const Map<String, dynamic> diaryIdSchema = {
  'type': 'string',
  'description':
      'Diary id (uuid v7) as returned by search_diaries or get_diary.',
};

const Map<String, dynamic> requiredCategoryIdSchema = {
  'type': 'string',
  'description': 'Category id as returned by list_categories.',
};

const Map<String, dynamic> categoryIdSchema = {
  'anyOf': [
    requiredCategoryIdSchema,
    {'type': 'null'},
  ],
  'description':
      'Category id as list_categories returns it. Unknown ids fail the item '
      'on writes or the call on search; call list_categories first. null means '
      'no search filter, or an uncategorized diary in the write '
      'tools.',
};

const Map<String, dynamic> startDateSchema = {
  'type': 'string',
  'description':
      'Inclusive ISO-8601 lower bound on the diary time. A bare yyyy-MM-dd '
      'means local midnight of that day.',
};

const Map<String, dynamic> endDateSchema = {
  'type': 'string',
  'description':
      'Inclusive ISO-8601 upper bound on the diary time. A bare yyyy-MM-dd '
      'covers that whole local day.',
};

const Map<String, dynamic> limitSchema = {
  'type': 'integer',
  'minimum': 1,
  'maximum': 100,
  'default': 20,
  'description': 'Page size, capped at 100.',
};

const Map<String, dynamic> offsetSchema = {
  'type': 'integer',
  'minimum': 0,
  'default': 0,
  'description': 'Number of matching diaries to skip.',
};

const Map<String, dynamic> readContentFormatSchema = {
  'type': 'string',
  'enum': contentFormatValues,
  'default': 'markdown',
  'description':
      'Representation actually returned: markdown (converted from the stored '
      'editor document), text (no syntax, media as [image: name] placeholders) '
      'or document (the raw stored Tiptap JSON object, which counts against '
      'the result size limit).',
};

const Map<String, dynamic> writeContentFormatSchema = {
  'type': 'string',
  'enum': contentFormatValues,
  'default': 'markdown',
  'description':
      'How content is interpreted: markdown (default) parses it and stores the '
      'editor document so formatting survives, text stores literal paragraphs '
      'so Markdown syntax stays visible, document takes a Tiptap document JSON '
      'object and rejects anything else. Applies to content only.',
};

const Map<String, dynamic> linkStyleSchema = {
  'type': 'string',
  'enum': linkStyleValues,
  'default': 'uri',
  'description':
      'How a diary mention is rendered: uri (default) keeps the target as '
      '[label](moodiary://diary/<id>) in Markdown and "label (uri)" in text, '
      'label keeps only the label.',
};

const Map<String, dynamic> excerptSchema = {
  'type': 'string',
  'enum': excerptValues,
  'default': 'plain',
  'description':
      'Preview of every entry: plain (default) is one line of plain text, '
      'markdown is the Markdown body so headings and lists survive, and none '
      'drops the preview. Both forms are cut to $excerptChars characters. '
      'Keyword search keeps its highlighted excerpt regardless of this option.',
};

const Map<String, dynamic> moodSchema = {
  'description':
      'Mood as awful, bad, okay, good or great, or as a score from 1 to 5. '
      'Send null (or an empty string) to clear it.',
  'oneOf': [
    {
      'type': 'string',
      'enum': ['awful', 'bad', 'okay', 'good', 'great'],
    },
    {'type': 'integer', 'minimum': 1, 'maximum': 5},
    {'type': 'null'},
  ],
};

const Map<String, dynamic> tagsSchema = {
  'type': ['array', 'null'],
  'items': {'type': 'string'},
  'description':
      'Replaces the whole tag list, in the order given; send null or an empty '
      'array to clear every tag.',
};

const Map<String, dynamic> colorSchema = {
  'description':
      'Category colour as a 32 bit ARGB integer (e.g. 4278233312), as #RRGGBB '
      'for an opaque colour or as #AARRGGBB for one with alpha. Send null or an '
      'empty string to clear the colour; create_category has no colour unless '
      'one is sent, and update_category leaves it unchanged when the argument '
      'is omitted.',
  'oneOf': [
    {'type': 'integer', 'minimum': 0, 'maximum': 4294967295},
    {'type': 'string'},
    {'type': 'null'},
  ],
};

const Map<String, dynamic> categoryNameSchema = {
  'type': 'string',
  'description': 'Category name; must not be empty.',
};

const Map<String, dynamic> tagLimitSchema = {
  'type': 'integer',
  'minimum': 1,
  'maximum': 500,
  'default': 50,
  'description': 'Number of tags to return, capped at 500.',
};

const Map<String, dynamic> statsMonthsSchema = {
  'type': 'integer',
  'minimum': 1,
  'maximum': 120,
  'default': 12,
  'description':
      'How many local calendar months the per-month counts cover, including '
      'the current month.',
};

const Map<String, dynamic> mediaNameSchema = {
  'type': 'string',
  'description':
      'Media file name exactly as list_diary_media shows it, e.g. '
      '"image-018f...png". Paths are rejected.',
};

const Map<String, dynamic> diarySearchSortSchema = {
  'type': 'string',
  'enum': diarySearchSortValues,
  'description': 'Defaults to relevance with query, newest when browsing. modified orders by last modification.',
};

const Map<String, dynamic> diaryTimeSchema = {
  'type': 'string',
  'description': 'ISO-8601 diary time, or YYYY-MM-DD for local midnight. Defaults to now on create. Omit or send null to keep it on update.',
};
