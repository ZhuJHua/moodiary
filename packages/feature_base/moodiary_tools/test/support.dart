library;

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_tools/moodiary_tools.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

MoodiaryDatabase openTestDatabase() => MoodiaryDatabase.forTesting(
  NativeDatabase.memory(
    setup: (raw) => raw.execute('PRAGMA foreign_keys = ON'),
  ),
);

String paragraphDoc(String text) => jsonEncode(
  TiptapContent.newDoc([
    {
      'type': 'paragraph',
      'content': [
        {'type': 'text', 'text': text},
      ],
    },
  ]),
);

Diary makeDiary(
  String id,
  String text, {
  String? content,
  String? title,
  String type = 'tiptap',
  List<String> linkTo = const [],
  List<Map<String, dynamic>> media = const [],
  List<String> tagIds = const [],
  DateTime? time,
  String? categoryId,
  bool show = true,
  DiaryMood? mood,
}) {
  final doc =
      content ??
      (type == 'tiptap'
          ? jsonEncode(
              TiptapContent.newDoc([
                {
                  'type': 'paragraph',
                  'content': [
                    {'type': 'text', 'text': text},
                    for (final target in linkTo)
                      {
                        'type': 'diaryLink',
                        'attrs': {'id': target, 'label': 'L'},
                      },
                  ],
                },
                ...media,
              ]),
            )
          : text);
  return withDerivedMedia(
    Diary(
      id: id,
      categoryId: categoryId,
      title: title ?? 'title-$id',
      content: doc,
      contentText: text,
      time: time ?? DateTime.utc(2026, 1, 1),
      lastModified: time ?? DateTime.utc(2026, 1, 1),
      show: show,
      mood: mood,
      imageName: const [],
      audioName: const [],
      videoName: const [],
      tagIds: tagIds,
      type: type,
    ),
  );
}

class TestToolClient {
  TestToolClient(this.context);
  final ToolContext context;
  Future<ToolResult> toolCall(
    String name, [
    Map<String, dynamic> arguments = const {},
  ]) async {
    final def = moodiaryTools.firstWhere((tool) => tool.name == name);
    final result = await def.call(arguments, context);
    expect(
      await def.output.validate(result.data),
      isEmpty,
      reason: '$name output',
    );
    return result;
  }

  Future<String> newCategory(String name, {Object? color}) async {
    final created = (await toolCall('create_category', {
      'items': [
        {'name': name, 'color': ?color},
      ],
    })).data;
    final row = (created['results'] as List).single as Map;
    expect(row['ok'], isTrue);
    return (row['category'] as Map<String, dynamic>)['id'] as String;
  }
}

List<String> diaryIds(Map<String, dynamic> data) => [
  for (final diary in data['diaries'] as List)
    (diary as Map<String, dynamic>)['id'] as String,
];

Map<String, dynamic> singleSummary(Map<String, dynamic> data) =>
    (data['diaries'] as List).cast<Map<String, dynamic>>().single;

Map<String, dynamic> singleHit(Map<String, dynamic> data) =>
    (data['hits'] as List).cast<Map<String, dynamic>>().single;

Map<String, dynamic> storedDoc(String content) =>
    jsonDecode(content) as Map<String, dynamic>;

List<Map<String, dynamic>> docBlocks(Map<String, dynamic> doc) =>
    (doc['content'] as List).cast<Map<String, dynamic>>();
