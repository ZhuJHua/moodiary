import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart' as ft;

import '../support/nodes.dart';

void main() {
  testWidgets('node views rebuild when read only changes', (tester) async {
    final schema = ft.Schema.standard();
    final nodes = TestNodes(schema);
    final controller = ft.TiptapController(
      doc: schema.node('doc', content: [nodes.image('a'), nodes.p('tail')]),
    );
    addTearDown(controller.dispose);
    var label = '';
    final views = <String, ft.TiptapNodeViewBuilder>{
      'image': (_, _) => SizedBox(height: 80, child: Text(label)),
    };
    Future<void> mount(bool readOnly) async {
      label = readOnly ? 'read' : 'edit';
      await tester.pumpWidget(
        CupertinoApp(
          home: ft.TiptapEditor(
            controller: controller,
            readOnly: readOnly,
            nodeViews: views,
          ),
        ),
      );
      await tester.pump();
    }

    await mount(true);
    expect(find.text('read'), findsOneWidget);
    await mount(false);
    expect(find.text('edit'), findsOneWidget);
    await mount(true);
    expect(find.text('read'), findsOneWidget);
  });
}
