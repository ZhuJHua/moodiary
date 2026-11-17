/// Shared diary tool fixtures and result readers.
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

/// A Tiptap document holding one paragraph with a single text run.
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

/// A diary fixture with media derived from its document.
Diary makeDiary(
  String id,
  String text, {
  String? content,
  String? title,
  String type = 'tiptap',
  List<String> linkTo = const [],
  List<Map<String, dynamic>> media = const [],
  List<String> tags = const [],
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
      tags: tags,
      type: type,
    ),
  );
}

class TestToolClient {
  TestToolClient(this.context);
  final ToolContext context;
  Future<Map<String, dynamic>> toolCall(
    String name, [
    Map<String, dynamic> arguments = const {},
  ]) async {
    final def = moodiaryTools.firstWhere((tool) => tool.name == name);
    try {
      final result = await def.call(arguments, context);
      expect(
        await def.output.validate(result.data),
        isEmpty,
        reason: '$name output',
      );
      return {
        'result': {
          'structuredContent': result.data,
          'content': [
            for (final media in result.media)
              {
                'type': 'image',
                'data': base64Encode(media.bytes),
                'mimeType': media.mimeType,
              },
            {'type': 'text', 'text': jsonEncode(result.data)},
          ],
        },
      };
    } on ToolArgumentException catch (error) {
      return {
        'error': {'code': -32602, 'message': error.message},
      };
    } on ToolFailure catch (error) {
      return {
        'result': {
          'isError': true,
          'content': [
            {'type': 'text', 'text': error.message},
          ],
        },
      };
    }
  }

  Future<String> newCategory(String name, {Object? color}) async {
    final created = structuredOf(
      await toolCall('create_category', {
        'items': [
          {'name': name, 'color': ?color},
        ],
      }),
    );
    final row = (created['results'] as List).single as Map;
    expect(row['ok'], isTrue);
    expect(row['created'], isTrue);
    return (row['category'] as Map<String, dynamic>)['id'] as String;
  }
}

Map<String, dynamic> resultOf(Map<String, dynamic> response) =>
    response['result'] as Map<String, dynamic>;

Map<String, dynamic> structuredOf(Map<String, dynamic> response) =>
    resultOf(response)['structuredContent'] as Map<String, dynamic>;

List<Map<String, dynamic>> contentOf(Map<String, dynamic> response) => [
  for (final item in resultOf(response)['content'] as List)
    (item as Map).cast<String, dynamic>(),
];

String textOf(Map<String, dynamic> response) =>
    contentOf(response).single['text'] as String;

int errorCode(Map<String, dynamic> response) =>
    (response['error'] as Map)['code'] as int;

String errorMessage(Map<String, dynamic> response) =>
    (response['error'] as Map)['message'] as String;

List<String> completionValues(Map<String, dynamic> response) {
  final completion = resultOf(response)['completion'] as Map;
  return (completion['values'] as List).cast<String>();
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

Map<String, dynamic> toolNamed(Map<String, dynamic> listed, String name) =>
    (listed['tools'] as List).cast<Map<String, dynamic>>().firstWhere(
      (tool) => tool['name'] == name,
    );

Map<String, dynamic> propertiesOf(Map<String, dynamic> tool) =>
    (tool['inputSchema'] as Map<String, dynamic>)['properties']
        as Map<String, dynamic>;
