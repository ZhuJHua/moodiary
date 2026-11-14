import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart';

void main() {
  final schema = Schema.standard();
  const commands = EditorCommands();

  EditorState paragraph(String text, {List<Mark> marks = const []}) =>
      EditorState(
        doc: schema.node(
          'doc',
          content: [
            schema.node(
              'paragraph',
              content: [
                if (text.isNotEmpty)
                  schema.node('text', text: text, marks: marks),
              ],
            ),
          ],
        ),
        selection: TextSelection(text.length + 1),
      );

  EditorState execute(
    EditorState state,
    String command, [
    Map<String, dynamic> args = const {},
  ]) => state.apply(commands.execute(state, command, args));

  List<Node> linked(EditorState state) => [
    for (final row in state.doc.rows())
      for (final node in row.node.content)
        if (node.marks.any((mark) => mark.type == 'link')) node,
  ];

  String href(Node node) =>
      node.marks.firstWhere((mark) => mark.type == 'link').attrs['href']
          as String;

  for (final (input, mark) in [
    ('_hello _', 'italic'),
    ('*hello *', 'italic'),
    ('**hello **', 'bold'),
    ('`hello `', 'code'),
    ('==hello ==', 'highlight'),
  ]) {
    test('input rule maps the inserted range for $input', () {
      var state = paragraph('');
      for (final character in input.split('')) {
        state = execute(state, 'insertText', {'text': character});
      }
      expect(
        state.doc.toJson(),
        paragraph('hello ', marks: [schema.mark(mark)]).doc.toJson(),
      );
      expect(state.selection, const TextSelection(7));
      expect(state.storedMarks, isEmpty);
    });
  }

  test('random delimiter, whitespace, URL and CJK typing never throws', () {
    const chunks = [
      '_',
      '*',
      '**',
      '`',
      '==',
      ' ',
      '  ',
      'example.com',
      'https://x.org',
      '测试',
      '日记',
      'a@b.co',
      '[',
      ']',
      '(',
      ')',
    ];
    for (var seed = 0; seed < 32; seed++) {
      final random = Random(seed);
      final input = List.generate(
        64,
        (_) => chunks[random.nextInt(chunks.length)],
      ).join();
      expect(
        () {
          var state = paragraph('');
          for (final character in input.split('')) {
            state = execute(state, 'insertText', {'text': character});
            expect(
              state.selection.from,
              inInclusiveRange(0, state.doc.content.size),
            );
            expect(
              state.selection.to,
              inInclusiveRange(0, state.doc.content.size),
            );
          }
        },
        returnsNormally,
        reason: 'seed $seed: $input',
      );
    }
  });

  test('typing validates the entire final token and preserves bold', () {
    final state = execute(
      paragraph('(example.xyz)', marks: [schema.mark('bold')]),
      'insertText',
      {'text': ' '},
    );
    expect(linked(state).single.text, 'example.xyz');
    expect(href(linked(state).single), 'https://example.xyz');
    expect(linked(state).single.marks.map((mark) => mark.type), [
      'link',
      'bold',
    ]);
    for (final text in ['example.com1', 'example.com.', '192.168.0.1']) {
      expect(
        linked(execute(paragraph(text), 'insertText', {'text': ' '})),
        isEmpty,
        reason: text,
      );
    }
  });

  for (final separator in [
    '\u0000',
    '\t',
    '\n',
    '\u00a0',
    '\u1680',
    '\u180e',
    '\u200b',
    '\u2028',
    '\u2029',
    '\u205f',
    '\u3000',
  ]) {
    test(
      'typing whitespace U+${separator.codeUnitAt(0).toRadixString(16)}',
      () {
        final state = execute(paragraph('example.com'), 'insertText', {
          'text': separator,
        });
        expect(href(linked(state).single), 'https://example.com');
      },
    );
  }

  test('NEL is not a Tiptap whitespace trigger', () {
    expect(
      linked(
        execute(paragraph('example.com'), 'insertText', {'text': '\u0085'}),
      ),
      isEmpty,
    );
  });

  test('Enter links only the last word in the split block', () {
    final state = execute(paragraph('first.org example.co.uk'), 'splitBlock');
    expect(linked(state).map((node) => node.text), ['example.co.uk']);
    expect(href(linked(state).single), 'https://example.co.uk');
  });

  test('paste rule finds embedded links and uses the linkify default http', () {
    final state = execute(paragraph(''), 'pasteText', {
      'text': 'See example.com. and [example.xyz] or a@b.co; 192.168.0.1',
    });
    expect(linked(state).map(href), [
      'http://example.com',
      'http://example.xyz',
      'mailto:a@b.co',
    ]);
  });

  test('linkOnPaste keeps the selection text and uses https', () {
    final state = paragraph('label');
    final selected = state.apply(
      state.tr.setSelection(const TextSelection(1, 6)),
    );
    final pasted = execute(selected, 'pasteText', {'text': 'example.xyz'});
    expect(linked(pasted).single.text, 'label');
    expect(href(linked(pasted).single), 'https://example.xyz');
    expect(pasted.selection, selected.selection);
  });

  test('linkOnPaste falls back to insertion when code excludes the mark', () {
    final state = paragraph('label', marks: [schema.mark('code')]);
    final selected = state.apply(
      state.tr.setSelection(const TextSelection(1, 6)),
    );
    final pasted = execute(selected, 'pasteText', {'text': 'example.com'});
    expect(pasted.doc.textContent, 'example.com');
    expect(linked(pasted), isEmpty);
    expect(pasted.doc.child(0).child(0).marks.single.type, 'code');
  });

  test('typing does not link code or replace an existing link', () {
    for (final mark in [
      schema.mark('code'),
      schema.mark('link', {'href': 'https://keep.org'}),
    ]) {
      var state = paragraph('left example.com right', marks: [mark]);
      state = state.apply(state.tr.setSelection(const TextSelection(17)));
      final result = execute(state, 'insertText', {'text': ' '});
      expect(
        linked(result).every((node) => href(node) == 'https://keep.org'),
        isTrue,
      );
    }
  });

  test('inline atoms keep their position and delimit the typing candidate', () {
    final state = EditorState(
      doc: schema.node(
        'doc',
        content: [
          schema.node(
            'paragraph',
            content: [
              schema.node('text', text: 'first.org'),
              schema.node('hardBreak'),
              schema.node('text', text: 'example.xyz'),
            ],
          ),
        ],
      ),
      selection: const TextSelection(22),
    );
    final typed = execute(state, 'insertText', {'text': ' '});
    expect(linked(typed).single.text, 'example.xyz');
    expect(typed.doc.child(0).child(1).type, 'hardBreak');
  });

  test('typing preserves whitespace that was already part of a link', () {
    final state = paragraph(
      'label ',
      marks: [
        schema.mark('link', {'href': 'https://keep.org'}),
      ],
    );
    final typed = execute(state, 'insertText', {'text': ' '});
    expect(linked(typed).single.text, 'label ');
    expect(typed.doc.child(0).content.last.text, ' ');
    expect(typed.doc.child(0).content.last.marks, isEmpty);
  });

  test('typing removes only newly inserted trailing link whitespace', () {
    final initial = paragraph('label');
    final state = initial.apply(
      initial.tr.setStoredMarks([
        schema.mark('link', {'href': 'https://keep.org'}),
        schema.mark('bold'),
      ]),
    );
    final typed = execute(state, 'insertText', {'text': 'example.com '});
    expect(linked(typed).single.text, 'example.com');
    expect(typed.doc.child(0).content.last.text, ' ');
    expect(typed.doc.child(0).content.last.marks.map((mark) => mark.type), [
      'bold',
    ]);
    expect(typed.storedMarks!.map((mark) => mark.type), ['bold']);
  });

  group('replacing the end of a link with text ending in a space', () {
    final link = schema.mark('link', {'href': 'https://example.com'});
    EditorState selected() => EditorState(
      doc: paragraph('example.com', marks: [link]).doc,
      selection: const TextSelection(8, 12),
    );
    void expectUnlinkedSpace(EditorState state) {
      final typed = execute(state, 'insertText', {'text': 'x'});
      expect(linked(typed).single.text, 'exampleorg');
      expect(href(linked(typed).single), 'https://example.com');
      expect(
        typed.doc.child(0).textContent.replaceAll('\u00a0', ' '),
        'exampleorg x',
      );
    }

    test('IME composition', () {
      var state = execute(selected(), 'insertText', {
        'text': 'org ',
        'committed': false,
        'composition': 1,
      });
      state = execute(state, 'commitComposition', {'composition': 1});
      expectUnlinkedSpace(state);
    });

    test('IME composition that rewrites its trailing space', () {
      var state = execute(selected(), 'insertText', {
        'text': 'org ',
        'committed': false,
        'composition': 1,
      });
      state = execute(
        EditorState(
          doc: state.doc,
          selection: const TextSelection(11, 12),
          history: state.history,
        ),
        'insertText',
        {'text': 's ', 'committed': false, 'composition': 1},
      );
      state = execute(state, 'commitComposition', {'composition': 1});
      final typed = execute(state, 'insertText', {'text': 'x'});
      expect(linked(typed).single.text, 'exampleorgs');
      expect(typed.doc.child(0).textContent, 'exampleorgs x');
      final undone = execute(state, 'undo');
      expect(undone.doc.toJson(), selected().doc.toJson());
    });

    EditorState compose(EditorState state, int from, int to, String text) =>
        execute(
          EditorState(
            doc: state.doc,
            selection: TextSelection(from, to),
            history: state.history,
          ),
          'insertText',
          {'text': text, 'committed': false, 'composition': 1},
        );
    EditorState commit(EditorState state) =>
        execute(state, 'commitComposition', {'composition': 1});

    test('IME composition that ends with a deletion', () {
      final state = commit(
        compose(compose(selected(), 8, 12, 'org x'), 12, 13, ''),
      );
      expectUnlinkedSpace(state);
    });

    test('IME composition that adds spaces in separate updates', () {
      final state = commit(
        compose(compose(selected(), 8, 12, 'org '), 12, 12, ' '),
      );
      final typed = execute(state, 'insertText', {'text': 'x'});
      expect(linked(typed).single.text, 'exampleorg');
      expect(typed.doc.child(0).textContent, 'exampleorg  x');
    });

    test('plain text paste', () {
      expectUnlinkedSpace(
        execute(selected(), 'pasteText', {'text': 'org ', 'plain': true}),
      );
    });

    test('linked HTML paste', () {
      expectUnlinkedSpace(
        execute(selected(), 'pasteSlice', {
          'slice': TiptapHtmlCodec(schema)
              .parseSlice('<a href="https://example.com">org&nbsp;</a>'),
        }),
      );
    });

    test('a space inside the link stays linked', () {
      final state = EditorState(
        doc: paragraph('example.com', marks: [link]).doc,
        selection: const TextSelection(8, 9),
      );
      final pasted = execute(state, 'pasteText', {'text': 'a ', 'plain': true});
      expect(linked(pasted).single.text, 'examplea com');
    });
  });

  test('composition preserves whitespace that was already part of a link', () {
    final state = paragraph(
      'label ',
      marks: [
        schema.mark('link', {'href': 'https://keep.org'}),
      ],
    );
    final composed = execute(
      execute(state, 'insertText', {
        'text': ' ',
        'committed': false,
        'composition': 1,
      }),
      'commitComposition',
      {'composition': 1},
    );
    expect(linked(composed).single.text, 'label ');
  });
}
