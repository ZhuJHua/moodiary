/// Shared fixtures for the diary ops tests: one in-memory database per test and
/// the small document builders the projections and queries need.
library;

import 'dart:convert';

import 'package:drift/native.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

/// A fresh in-memory database; foreign keys are on so cascade deletes behave
/// like the app.
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

/// A stored diary row. [linkTo] appends diary mentions to the paragraph, so the
/// repository derives the same link rows the editor would.
Diary makeDiary(
  String id,
  String text, {
  String? content,
  String? title,
  List<String> linkTo = const [],
  List<String> tags = const [],
  DateTime? time,
  String? categoryId,
  bool show = true,
  DiaryMood? mood,
  String type = 'tiptap',
}) {
  final doc =
      content ??
      jsonEncode(
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
        ]),
      );
  final stamp = time ?? DateTime.utc(2026, 1, 1);
  return Diary(
    id: id,
    categoryId: categoryId,
    title: title ?? 'title-$id',
    content: doc,
    contentText: text,
    time: stamp,
    lastModified: stamp,
    show: show,
    mood: mood,
    imageName: const [],
    audioName: const [],
    videoName: const [],
    tags: tags,
    type: type,
  );
}
