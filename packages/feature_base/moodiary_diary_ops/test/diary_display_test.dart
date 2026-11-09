import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_diary_ops/moodiary_diary_ops.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

import 'support.dart';

Map<String, dynamic> cell(String type, String text) => {
  'type': type,
  'content': [
    {
      'type': 'paragraph',
      'content': [
        {'type': 'text', 'text': text},
      ],
    },
  ],
};

String tableDoc() => jsonEncode(
  TiptapContent.newDoc([
    {
      'type': 'table',
      'content': [
        {
          'type': 'tableRow',
          'content': [cell('tableHeader', 'a'), cell('tableHeader', 'b|c')],
        },
        {
          'type': 'tableRow',
          'content': [cell('tableCell', 'd'), cell('tableCell', 'e*f')],
        },
      ],
    },
  ]),
);

String taskListDoc() => jsonEncode(
  TiptapContent.newDoc([
    {
      'type': 'taskList',
      'content': [
        {
          'type': 'taskItem',
          'attrs': {'checked': true},
          'content': [
            {
              'type': 'paragraph',
              'content': [
                {'type': 'text', 'text': 'done'},
              ],
            },
          ],
        },
        {
          'type': 'taskItem',
          'attrs': {'checked': false},
          'content': [
            {
              'type': 'paragraph',
              'content': [
                {'type': 'text', 'text': 'todo'},
              ],
            },
          ],
        },
      ],
    },
  ]),
);

void main() {
  group('tiptapToMarkdown', () {
    test('renders a table as a GFM pipe table', () {
      expect(
        tiptapToMarkdown(tableDoc()),
        '| a | b\\|c |\n| --- | --- |\n| d | e\\*f |',
      );
    });

    test('renders a task list with its checked state', () {
      expect(tiptapToMarkdown(taskListDoc()), '- [x] done\n- [ ] todo');
    });

    test('table and task list survive a document round-trip', () {
      for (final doc in [tableDoc(), taskListDoc()]) {
        final markdown = tiptapToMarkdown(doc);
        final parsed = MarkdownToTiptap.convert(markdown)!;
        expect(tiptapToMarkdown(parsed), markdown);
      }
    });

    test('headings, lists and code blocks keep working', () {
      final doc = jsonEncode(
        TiptapContent.newDoc([
          {
            'type': 'heading',
            'attrs': {'level': 2},
            'content': [
              {'type': 'text', 'text': 'Title'},
            ],
          },
          {
            'type': 'bulletList',
            'content': [
              {
                'type': 'listItem',
                'content': [
                  {
                    'type': 'paragraph',
                    'content': [
                      {'type': 'text', 'text': 'item'},
                    ],
                  },
                ],
              },
            ],
          },
          {
            'type': 'codeBlock',
            'attrs': {'language': 'dart'},
            'content': [
              {'type': 'text', 'text': 'var a = 1;'},
            ],
          },
        ]),
      );
      expect(
        tiptapToMarkdown(doc),
        '## Title\n\n- item\n\n```dart\nvar a = 1;\n```',
      );
    });
  });

  group('escaping', () {
    /// Renders [text] as one paragraph, parses the Markdown back and expects the
    /// document to be unchanged: a caller's literal syntax must stay literal.
    void expectTextRoundTrip(String text) {
      final doc = paragraphDoc(text);
      final markdown = tiptapToMarkdown(doc);
      final parsed = MarkdownToTiptap.convert(markdown)!;
      expect(
        TiptapContent.normalize(parsed),
        TiptapContent.normalize(doc),
        reason: 'literal "$text" changed on a round-trip',
      );
      expect(tiptapToMarkdown(parsed), markdown);
    }

    test('literal Markdown characters stay plain text', () {
      expectTextRoundTrip('**bold**');
      expectTextRoundTrip('# heading');
      expectTextRoundTrip('[x](y)');
      expectTextRoundTrip('a | b');
      expectTextRoundTrip('~~strike~~ ==mark== <u>u</u> `code`');
      expectTextRoundTrip(r'C:\path\*');
      expectTextRoundTrip('- not a list');
      expectTextRoundTrip('1. not ordered');
      expectTextRoundTrip('> not a quote');
      expectTextRoundTrip('---');
    });

    test('marks keep working around escaped text', () {
      final doc = jsonEncode(
        TiptapContent.newDoc([
          {
            'type': 'paragraph',
            'content': [
              {
                'type': 'text',
                'text': 'a*b',
                'marks': [
                  {'type': 'bold'},
                ],
              },
            ],
          },
        ]),
      );

      final markdown = tiptapToMarkdown(doc);

      expect(markdown, r'**a\*b**');
      final parsed = MarkdownToTiptap.convert(markdown)!;
      expect(tiptapToMarkdown(parsed), markdown);
    });

    test('a code span with a backtick gets a longer fence', () {
      final doc = jsonEncode(
        TiptapContent.newDoc([
          {
            'type': 'paragraph',
            'content': [
              {
                'type': 'text',
                'text': 'a`b',
                'marks': [
                  {'type': 'code'},
                ],
              },
            ],
          },
        ]),
      );

      expect(tiptapToMarkdown(doc), '``a`b``');
      final parsed = MarkdownToTiptap.convert(tiptapToMarkdown(doc))!;
      expect(tiptapToMarkdown(parsed), '``a`b``');
    });
  });

  group('plain text projection', () {
    final doc = jsonEncode(
      TiptapContent.newDoc([
        {
          'type': 'paragraph',
          'content': [
            {'type': 'text', 'text': 'see '},
            {
              'type': 'diaryLink',
              'attrs': {'id': 'd1', 'label': 'other'},
            },
            {'type': 'text', 'text': ' and '},
            {
              'type': 'text',
              'text': 'site',
              'marks': [
                {
                  'type': 'link',
                  'attrs': {'href': 'https://x.test'},
                },
              ],
            },
            {
              'type': 'image',
              'attrs': {'src': 'image-1.png', 'name': 'pic'},
            },
          ],
        },
        {
          'type': 'paragraph',
          'content': [
            {'type': 'text', 'text': 'second'},
          ],
        },
      ]),
    );

    test('keeps diary and external link targets', () {
      final diary = makeDiary('source', '', content: doc);

      expect(
        diaryToText(diary),
        'see other (moodiary://diary/d1) and site (https://x.test)\n'
        '[image: pic]\nsecond',
      );
    });

    test('label style drops the targets', () {
      final diary = makeDiary('source', '', content: doc);

      expect(
        diaryToText(diary, linkStyle: DiaryLinkStyle.label),
        'see other and site\n[image: pic]\nsecond',
      );
    });

    test('excerptOf stays a one-line plain preview', () {
      final diary = makeDiary('source', '', content: doc);

      expect(excerptOf(diary), 'see other and site [image: pic] second');
    });

    test('diaryToMarkdown keeps link targets and can drop them', () {
      final diary = makeDiary('source', '', content: doc);

      expect(
        diaryToMarkdown(diary),
        'see [other](moodiary://diary/d1) and '
        '[site](https://x.test)![pic](image-1.png)\n\nsecond',
      );
      expect(
        diaryToMarkdown(diary, renderLinks: false),
        'see other and [site](https://x.test)![pic](image-1.png)\n\nsecond',
      );
    });
  });
}
