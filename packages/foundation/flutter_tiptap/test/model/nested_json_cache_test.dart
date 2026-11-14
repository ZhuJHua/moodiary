import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart';

import '../support/large_doc.dart';

void main() {
  test('nested cache encodes edits and keeps old versions', () {
    final schema = Schema.standard(), codec = DocumentCodec();
    codec.encode(schema.node('doc', content: [schema.node('paragraph')]));
    final original = generateLargeListDocument(schema: schema);
    final old = codec.encode(original);
    expect(jsonDecode(old), original.toJson());
    final list = original.child(0),
        position = 3 + list.content.positionAt(5000) + 10;
    final state = EditorState(
      doc: original,
      selection: TextSelection(position),
    );
    const commands = EditorCommands();
    final next = commands.execute(state, 'insertText', {'text': '中'}).doc;
    final encoded = codec.encode(next);
    expect(jsonDecode(encoded), next.toJson());
    expect(codec.encode(original), old);
    expect(codec.encode(next), encoded);
  });

  testWidgets(
    'save callbacks coalesce edits, observe latest state and stop on disposal',
    (tester) async {
      var callbacks = 0;
      String? saved;
      late final TiptapController controller;
      controller = TiptapController(
        onChanged: (_) {
          callbacks++;
          saved = controller.json;
        },
      );
      for (var i = 0; i < 20; i++) {
        controller.exec('insertText', {'text': 'x'});
      }
      expect(callbacks, 0);
      await tester.pump();
      expect(callbacks, 1);
      expect(saved, controller.json);
      expect(controller.state.doc.textContent, 'x' * 20);
      controller.exec('insertText', {'text': 'y'});
      controller.dispose();
      await tester.pump();
      expect(callbacks, 1);
    },
  );
}
