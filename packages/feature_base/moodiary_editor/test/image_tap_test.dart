// ignore_for_file: deprecated_member_use

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart' as ft;
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_editor/moodiary_editor.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';

void main() {
  testWidgets('image taps open at once when read only and on double tap '
      'when editing', (tester) async {
    final schema = ft.Schema.standard();
    final content = schema
        .node(
          'doc',
          attrs: {'v': 2},
          content: [
            schema.node(
              'paragraph',
              content: [schema.node('text', text: 'Lead')],
            ),
            schema.node('image', attrs: {'src': 'tap.png'}),
            schema.node('paragraph'),
          ],
        )
        .toJsonString();
    var opened = 0;
    var readOnly = true;
    late StateSetter setReadOnly;
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          theme: buildMuiTheme(brightness: Brightness.light),
          localizationsDelegates: const [
            ...GlobalMaterialLocalizations.delegates,
            GlobalMuiLocalizations.delegate,
          ],
          builder: (_, child) => MaterialUiCompatibilityBridge(child: child!),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                setReadOnly = setState;
                return MoodiaryEditor(
                  initialContent: content,
                  readOnly: readOnly,
                  mediaResolver: (_, {poster = false}) => null,
                  onImageTap: (_, _, _) => opened++,
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final image = find.byType(Hero);
    Future<void> show(bool value) async {
      setReadOnly(() => readOnly = value);
      await tester.pumpAndSettle();
      expect(
        tester.widget<ft.TiptapEditor>(find.byType(ft.TiptapEditor)).readOnly,
        value,
      );
    }

    await tester.tap(image);
    await tester.pump();
    expect(opened, 1);

    await show(false);
    await tester.tap(image);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(image);
    await tester.pump();
    expect(opened, 2);
    await tester.pumpAndSettle();

    await tester.tap(image);
    await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 10));
    expect(opened, 2);
    expect(
      tester
          .widget<ft.TiptapEditor>(find.byType(ft.TiptapEditor))
          .controller
          .state
          .selection,
      isA<ft.NodeSelection>(),
    );

    await show(true);
    await tester.tap(image);
    await tester.pump();
    expect(opened, 3);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
