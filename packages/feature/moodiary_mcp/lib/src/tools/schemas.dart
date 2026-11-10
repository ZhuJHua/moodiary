/// Argument schemas shared by every tool of the catalog.
///
/// The input schema is the contract a client reads before it calls a tool, so an
/// argument that appears in several tools has to mean the same thing there and
/// be described with the same words: a model that learned `excerpt` from
/// `list_diaries` must not have to re-learn it in `search_diaries`. The value
/// lists exported next to the schemas are what the handlers validate against,
/// which keeps a schema and its parser from drifting apart.
///
/// Clearing convention of the write tools: an omitted argument leaves the field
/// unchanged, an explicit `null` clears a nullable one (`categoryId`, `mood`,
/// `tags`, `color`, `parentId`), and the non-nullable ones (`title`, `content`,
/// `time`, `visible`) ignore an explicit `null`. `title` is cleared with `""`.
library;

import 'package:moodiary_diary_ops/moodiary_diary_ops.dart';

/// Values of `excerpt`, the preview projection of every list shaped result.
const List<String> excerptValues = ['plain', 'markdown', 'none'];

/// Values of `sort` in the paging tools.
const List<String> diarySortValues = ['newest', 'oldest', 'modified'];

/// Values of `sort` in `search_diaries`; relevance only exists where there is a
/// match score to rank by.
const List<String> searchSortValues = ['relevance', 'newest', 'oldest'];

/// Values of `contentFormat`, on the read and the write tools alike.
const List<String> contentFormatValues = ['markdown', 'text', 'document'];

/// Values of `linkStyle`.
const List<String> linkStyleValues = ['uri', 'label'];

/// Values of `mode` in `delete_diary`.
const List<String> deleteModeValues = ['permanent', 'recycle'];

/// Diary id as every tool names and returns it.
const Map<String, dynamic> diaryIdSchema = {
  'type': 'string',
  'description': 'Diary id (uuid v7) as returned by the list tools.',
};

/// A category id, whether it filters a list or files a diary.
const Map<String, dynamic> categoryIdSchema = {
  'type': ['string', 'null'],
  'description':
      'Category id as list_categories returns it. An unknown id is an invalid '
      'params error, so call list_categories first. null means no category: no '
      'filter in the list and search tools, an uncategorized diary in the write '
      'tools.',
};

/// The parent of a category.
const Map<String, dynamic> parentIdSchema = {
  'type': ['string', 'null'],
  'description':
      'Id of the parent category, which must exist. Send null (or an empty '
      'string) to make the category a root category; create_category has no '
      'parent unless one is given, and update_category leaves the parent '
      'unchanged when the argument is omitted.',
};

/// Lower bound of the shared date range.
const Map<String, dynamic> startDateSchema = {
  'type': 'string',
  'description':
      'Inclusive ISO-8601 lower bound on the diary time. A bare yyyy-MM-dd '
      'means local midnight of that day.',
};

/// Upper bound of the shared date range.
const Map<String, dynamic> endDateSchema = {
  'type': 'string',
  'description':
      'Inclusive ISO-8601 upper bound on the diary time. A bare yyyy-MM-dd '
      'covers that whole local day.',
};

/// Page size of the list and search tools.
const Map<String, dynamic> limitSchema = {
  'type': 'integer',
  'minimum': 1,
  'maximum': 100,
  'default': 20,
  'description': 'Page size, capped at 100.',
};

/// Offset of the list and search tools.
const Map<String, dynamic> offsetSchema = {
  'type': 'integer',
  'minimum': 0,
  'default': 0,
  'description': 'Number of matching diaries to skip.',
};

/// `sort` of `list_diaries`.
const Map<String, dynamic> diarySortSchema = {
  'type': 'string',
  'enum': diarySortValues,
  'default': 'newest',
  'description':
      'newest orders by diary time descending (default), oldest ascending, '
      'modified by last modification descending.',
};

/// `sort` of `search_diaries`.
const Map<String, dynamic> searchSortSchema = {
  'type': 'string',
  'enum': searchSortValues,
  'default': 'relevance',
  'description':
      'relevance ranks by full text match score (default); newest and oldest '
      'order by diary time instead.',
};

/// `contentFormat` of the read tools.
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

/// `contentFormat` of the write tools.
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

/// `linkStyle` of `get_diary`.
const Map<String, dynamic> linkStyleSchema = {
  'type': 'string',
  'enum': linkStyleValues,
  'default': 'uri',
  'description':
      'How a diary mention is rendered: uri (default) keeps the target as '
      '[label](moodiary://diary/<id>) in Markdown and "label (uri)" in text, '
      'label keeps only the label.',
};

/// `excerpt` of the list and search tools.
const Map<String, dynamic> excerptSchema = {
  'type': 'string',
  'enum': excerptValues,
  'default': 'plain',
  'description':
      'Preview of every entry: plain (default) is one line of plain text, '
      'markdown is the Markdown body so headings and lists survive, and none '
      'drops the preview. Both forms are cut to $mcpExcerptChars characters.',
};

/// `mood` of the write tools.
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

/// `tags` of the write tools.
const Map<String, dynamic> tagsSchema = {
  'type': ['array', 'null'],
  'items': {'type': 'string'},
  'description':
      'Replaces the whole tag list, in the order given; send null or an empty '
      'array to clear every tag.',
};

/// `visible` of the write tools.
const Map<String, dynamic> visibleSchema = {
  'type': 'boolean',
  'description':
      'Whether the diary is visible in the app; false files it in the recycle '
      'bin instead of deleting it. create_diary defaults to true, update_diary '
      'leaves it unchanged when omitted. The result summaries report the same '
      'flag as show.',
};

/// `color` of the category tools.
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

/// Name of a category.
const Map<String, dynamic> categoryNameSchema = {
  'type': 'string',
  'description': 'Category name; must not be empty.',
};

/// Page size of `list_tags`, which counts tags rather than diaries.
const Map<String, dynamic> tagLimitSchema = {
  'type': 'integer',
  'minimum': 1,
  'maximum': 500,
  'default': 50,
  'description': 'Number of tags to return, capped at 500.',
};

/// Window of `get_stats`.
const Map<String, dynamic> statsMonthsSchema = {
  'type': 'integer',
  'minimum': 1,
  'maximum': 120,
  'default': 12,
  'description':
      'How many local calendar months the per-month counts cover, including '
      'the current month.',
};

/// Name of one media file of a diary.
const Map<String, dynamic> mediaNameSchema = {
  'type': 'string',
  'description':
      'Media file name exactly as list_diary_media shows it, e.g. '
      '"image-018f...png". Paths are rejected.',
};
