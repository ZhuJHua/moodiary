import 'dart:math' as math;

import 'package:flutter_tiptap/model.dart';

/// Reproducible UTF-16 text budget, including one deliberately long paragraph.
Node generateLargeDocument(int characters, {Schema? schema, int seed = 17}) {
  if (characters < 50000) {
    throw ArgumentError.value(characters, 'characters', 'Minimum is 50000');
  }
  final s = schema ?? Schema.standard();
  final random = math.Random(seed), blocks = <Node>[];
  const alphabet = '日记记录今天的天气和心情 flutter rich text diary writing ';
  var remaining = characters, index = 0;
  while (remaining > 0) {
    final length = math.min(
      remaining,
      index == 3 ? 50000 : 20 + random.nextInt(481),
    );
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(alphabet[random.nextInt(alphabet.length)]);
    }
    final text = buffer.toString();
    final type = index % 30 == 0 ? 'heading' : 'paragraph';
    final marks = index % 7 == 0 ? [s.mark('bold')] : const <Mark>[];
    blocks.add(
      s.node(
        type,
        attrs: type == 'heading' ? {'level': 1 + index % 6} : null,
        content: [s.node('text', text: text, marks: marks)],
      ),
    );
    remaining -= length;
    if (index > 0 && index % 997 == 0) {
      blocks.add(
        s.fromJson({
          'type': 'futureMedia',
          'attrs': {
            'id': index,
            'payload': [1, '保留', null],
          },
        }),
      );
    }
    index++;
  }
  return s.node('doc', content: blocks);
}

/// One top-level list, including a deterministic nested branch in each item.
/// Used by the model benchmark.
Node generateLargeListDocument({
  int items = 10000,
  Schema? schema,
  bool nested = true,
}) {
  if (items < 1) throw ArgumentError.value(items, 'items');
  final s = schema ?? Schema.standard();
  Node paragraph(String text) =>
      s.node('paragraph', content: [s.node('text', text: text)]);
  return s.node(
    'doc',
    content: [
      s.node(
        'bulletList',
        content: Iterable.generate(
          items,
          (i) => s.node(
            'listItem',
            content: [
              paragraph('第 $i 项 Diary list item'),
              if (nested)
                s.node(
                  'bulletList',
                  content: [
                    s.node('listItem', content: [paragraph('nested $i')]),
                  ],
                ),
            ],
          ),
        ),
      ),
    ],
  );
}

Node generateLargeTableDocument({
  int rows = 2000,
  int columns = 4,
  Schema? schema,
}) {
  final s = schema ?? Schema.standard();
  return s.node(
    'doc',
    content: [
      s.node(
        'table',
        content: [
          for (var r = 0; r < rows; r++)
            s.node(
              'tableRow',
              content: [
                for (var c = 0; c < columns; c++)
                  s.node(
                    r == 0 ? 'tableHeader' : 'tableCell',
                    content: [
                      s.node(
                        'paragraph',
                        content: [s.node('text', text: '$r / $c 中文 cell')],
                      ),
                    ],
                  ),
              ],
            ),
        ],
      ),
      s.node('paragraph'),
    ],
  );
}

Node generateLargeMixedDocument({int groups = 1000, Schema? schema}) {
  if (groups < 1) throw ArgumentError.value(groups, 'groups');
  final documentSchema = schema ?? Schema.standard();
  Node paragraph(String value) => documentSchema.node(
    'paragraph',
    content: [documentSchema.node('text', text: value)],
  );
  return documentSchema.node(
    'doc',
    content: [
      for (var index = 0; index < groups; index++) ...[
        documentSchema.node(
          'blockquote',
          content: [
            documentSchema.node(
              'orderedList',
              attrs: {'start': 100000 + index},
              content: [
                documentSchema.node(
                  'listItem',
                  content: [
                    paragraph('Mixed 中文 group $index'),
                    documentSchema.node(
                      'taskList',
                      content: [
                        documentSchema.node(
                          'taskItem',
                          attrs: {'checked': index.isEven},
                          content: [paragraph('Nested task $index')],
                        ),
                      ],
                    ),
                    documentSchema.node(
                      'codeBlock',
                      attrs: {'language': 'dart'},
                      content: [
                        documentSchema.node(
                          'text',
                          text: 'final value$index = "${'unbreakable_' * 32}";',
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        documentSchema.node(
          'table',
          content: [
            documentSchema.node(
              'tableRow',
              content: [
                for (var column = 0; column < 3; column++)
                  documentSchema.node(
                    column == 0 ? 'tableHeader' : 'tableCell',
                    content: [
                      paragraph('Cell $index / $column'),
                      if (column == 1)
                        documentSchema.node(
                          'bulletList',
                          content: [
                            documentSchema.node(
                              'listItem',
                              content: [paragraph('Cell bullet $index')],
                            ),
                          ],
                        ),
                      if (column == 2)
                        documentSchema.node(
                          'image',
                          attrs: {'src': 'image-$index', 'widthPercent': 50},
                        ),
                    ],
                  ),
              ],
            ),
          ],
        ),
        documentSchema.node('horizontalRule'),
      ],
      paragraph('Sentinel'),
    ],
  );
}
