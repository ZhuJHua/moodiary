import 'dart:convert';
import 'dart:io';

import 'package:flutter_tiptap/model.dart';

void main() {
  final file = File.fromUri(
    Platform.script.resolve('../test/fixtures/html.json'),
  );
  final fixtures = jsonDecode(file.readAsStringSync()) as List;
  final schema = Schema.standard(), codec = TiptapHtmlCodec(Schema.standard());
  for (final fixture in fixtures.cast<Map<String, dynamic>>()) {
    final doc = schema.fromJson(
      (fixture['expected'] as Map).cast<String, dynamic>(),
    );
    fixture['nativeHtml'] = codec.serialize(doc);
    final rows = doc
        .rows()
        .where((r) => r.node.isTextblock && r.node.content.size > 0)
        .toList();
    fixture['nativeSlices'] = [
      for (final row in rows.take(2))
        {
          'from': row.position + 1,
          'to':
              row.position +
              1 +
              (row.node.content.size < 4 ? row.node.content.size : 4),
          'html': codec.serializeSlice(
            doc.slice(
              row.position + 1,
              row.position +
                  1 +
                  (row.node.content.size < 4 ? row.node.content.size : 4),
            ),
          ),
        },
    ];
  }
  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(fixtures)}\n',
  );
}
