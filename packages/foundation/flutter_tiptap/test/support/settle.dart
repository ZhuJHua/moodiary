import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tiptap/flutter_tiptap.dart';

Future<void> settleEditor(WidgetTester tester) async {
  final editors = tester
      .stateList<TiptapEditorState>(find.byType(TiptapEditor))
      .toList();
  for (final editor in editors) {
    editor.debugMuteCaret(true);
  }
  try {
    await tester.pumpAndSettle();
  } finally {
    for (final editor in editors) {
      if (editor.mounted) editor.debugMuteCaret(false);
    }
  }
}
