import 'dart:convert';

const _long =
    'longpathlongpathlongpathlongpathlongpath'
    'longpathlongpathlongpathlongpathlongpath';
const _href = 'https://example.com/$_long';

/// One paragraph mixing marks, a hard break, inline code, a link, a
/// reference chip and an unbreakable word.
final referenceDocument = jsonEncode({
  'type': 'doc',
  'attrs': {'v': 2},
  'content': [
    {
      'type': 'paragraph',
      'content': [
        {'type': 'text', 'text': '中文日记 mixed text '},
        for (final mark in ['bold', 'italic', 'strike', 'underline'])
          {
            'type': 'text',
            'text': mark == 'bold' ? mark : ' $mark',
            'marks': [
              {'type': mark},
            ],
          },
        {
          'type': 'text',
          'text': ' highlight',
          'marks': [
            {
              'type': 'highlight',
              'attrs': {'color': '#fbe7a1'},
            },
          ],
        },
        {'type': 'hardBreak'},
        {
          'type': 'text',
          'text': 'inline_code_long_token_' * 3,
          'marks': [
            {'type': 'code'},
          ],
        },
        {
          'type': 'text',
          'text': ' $_href',
          'marks': [
            {
              'type': 'link',
              'attrs': {'href': _href},
            },
          ],
        },
        {
          'type': 'diaryLink',
          'attrs': {'id': 'research-diary', 'label': '日记 reference chip'},
        },
        {'type': 'text', 'text': ' Unbreakable${'word' * 24}'},
      ],
    },
  ],
});
