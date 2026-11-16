import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/model.dart';

void main() {
  final schema = Schema.standard();

  test('empty attrs, fragments and marks are immutable and canonical', () {
    final first = schema.node('text', text: 'one');
    final second = schema.node('text', text: 'two', attrs: {}, marks: []);
    expect(first.attrs, same(second.attrs));
    expect(first.marks, same(second.marks));
    expect(first.content, same(Fragment.empty));
    expect(Fragment(<Node>[]), same(Fragment.empty));
    expect(Fragment(const <Node>[]), same(Fragment.empty));
    expect(() => first.attrs['test'] = true, throwsUnsupportedError);
    expect(() => first.marks.add(schema.mark('bold')), throwsUnsupportedError);
    expect(Fragment.empty.toList(), isEmpty);
    expect(schema.fromJson(first.toJson()).eq(first), isTrue);
    expect(schema.node('text', text: 'one').eq(first), isTrue);
  });

  test('nonempty attrs and marks still copy and recursively freeze inputs', () {
    final nested = <Object?>['original'];
    final attrs = <String, Object?>{
      'nested': {'items': nested},
    };
    final marks = [schema.mark('bold')];
    final node = schema.node('text', text: 'text', attrs: attrs, marks: marks);
    nested.add('changed');
    attrs.clear();
    marks.clear();
    final frozen = node.attrs['nested']! as Map;
    expect(frozen['items'], ['original']);
    expect(() => frozen['items'] = [], throwsUnsupportedError);
    expect(() => (frozen['items'] as List).add('x'), throwsUnsupportedError);
    expect(node.marks.single.type, 'bold');
    expect(() => node.marks.clear(), throwsUnsupportedError);
  });

  test('fragments consume a lazy iterable once and still merge equal text', () {
    var visits = 0;
    final nodes = ['a', 'b'].map((text) {
      visits++;
      return schema.node('text', text: text);
    });
    final fragment = Fragment(nodes);
    expect(visits, 2);
    expect(fragment.single.text, 'ab');
    expect(fragment.size, 2);
    expect(Fragment(const <Node>[].map((node) => node)).isEmpty, isTrue);
  });

  test('empty coverage preserves mixed mark selection and edits', () {
    final plain = schema.node(
      'paragraph',
      content: [schema.node('text', text: 'plain')],
    );
    final marked = schema.node(
      'paragraph',
      content: [
        schema.node('text', text: 'bold', marks: [schema.mark('bold')]),
      ],
    );
    final doc = schema.node('doc', content: [plain, plain, marked, plain]);
    final restored = schema.fromJson(doc.toJson());
    expect(restored.eq(doc), isTrue);
    expect(restored.content.size, doc.content.size);
    for (final selection in const [TextSelection(1), TextSelection(1, 20)]) {
      expect(
        EditorState(doc: restored, selection: selection).toolbar.activeMarks,
        EditorState(doc: doc, selection: selection).toolbar.activeMarks,
      );
    }
  });

  test(
    'fixTables preserves trivial nodes and repairs nested malformed tables',
    () {
      final paragraph = schema.node(
        'paragraph',
        content: [schema.node('text', text: 'text')],
      );
      for (final node in [
        paragraph,
        paragraph.child(0),
        schema.node('image'),
      ]) {
        expect(fixTables(node), same(node));
        expect(fixTables(node), same(node));
      }
      final broken = schema.node(
        'table',
        content: [
          schema.node(
            'tableRow',
            content: [
              schema.node(
                'tableCell',
                attrs: {'colspan': 2},
                content: [paragraph],
              ),
            ],
          ),
          schema.node(
            'tableRow',
            content: [
              schema.node('tableCell', content: [paragraph]),
            ],
          ),
        ],
      );
      final doc = schema.node(
        'doc',
        content: [
          schema.node('blockquote', content: [broken]),
          paragraph,
        ],
      );
      final fixed = fixTables(doc);
      expect(fixTables(doc), same(fixed));
      expect(fixTables(fixed), same(fixed));
      expect(fixTables(schema.fromJson(doc.toJson())).toJson(), fixed.toJson());
      expect(TableMap.get(fixed.child(0).child(0)).problems, isEmpty);
      expect(fixed.child(1), same(paragraph));
      expect(doc.child(0).child(0), same(broken));
    },
  );
}
