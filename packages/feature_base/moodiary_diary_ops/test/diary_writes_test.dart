import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_diary_ops/moodiary_diary_ops.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

import 'support.dart';

/// A Tiptap document holding one image node named [name].
String imageDoc(String name) => jsonEncode(
  TiptapContent.newDoc([
    {
      'type': 'paragraph',
      'content': [
        {'type': 'text', 'text': 'picture '},
        {
          'type': 'image',
          'attrs': {'src': name, 'name': 'pic'},
        },
      ],
    },
  ]),
);

void main() {
  late MoodiaryDatabase db;
  late DiaryRepository diaries;
  late CategoryRepository categories;
  late DiaryWrites writes;

  setUp(() {
    db = openTestDatabase();
    diaries = DiaryRepository(db);
    categories = CategoryRepository(db);
    writes = DiaryWrites(diaries: diaries, categories: categories);
  });

  tearDown(() => db.close());

  group('document format', () {
    test('stores and normalizes a raw Tiptap document', () async {
      final document = jsonEncode({
        'type': 'doc',
        'content': [
          {
            'type': 'paragraph',
            'content': [
              {'type': 'text', 'text': 'hello document'},
            ],
          },
        ],
      });

      final created = await writes.create(
        title: 'Raw',
        content: document,
        format: DiaryContentFormat.document,
      );

      expect(DiaryType.fromValue(created.type), DiaryType.tiptap);
      final stored = (await diaries.getDiaryByBusinessId(created.id))!;
      final parsed = TiptapContent.parse(stored.content);
      expect(parsed.isDoc, isTrue);
      expect(
        parsed.normalized,
        stored.content,
        reason: 'must be v2 normalized',
      );
      expect(stored.contentText, 'hello document');
    });

    test('rejects content that is not a document', () async {
      final invalid = [
        'not json',
        jsonEncode({'type': 'paragraph', 'content': const []}),
      ];
      for (final content in invalid) {
        await expectLater(
          writes.create(
            title: 'Bad',
            content: content,
            format: DiaryContentFormat.document,
          ),
          throwsA(
            isA<DiaryOpsException>().having(
              (error) => error.failure,
              'failure',
              DiaryOpsFailure.invalidDocument,
            ),
          ),
          reason: 'content: $content',
        );
      }
      expect(await diaries.getAllDiaries(), isEmpty);
    });

    test('an invalid document patch leaves the row alone', () async {
      final created = await writes.create(title: 'Keep', content: 'old body');

      await expectLater(
        writes.update(
          id: created.id,
          patch: const DiaryPatch(content: '{"type":"text"}'),
          format: DiaryContentFormat.document,
        ),
        throwsA(isA<DiaryOpsException>()),
      );

      final stored = (await diaries.getDiaryByBusinessId(created.id))!;
      expect(stored.contentText, 'old body');
    });
  });

  group('existing formats', () {
    test('markdown still converts to a rich document', () async {
      final created = await writes.create(
        title: 'Markdown',
        content: '**bold** body',
        format: DiaryContentFormat.markdown,
      );

      final stored = (await diaries.getDiaryByBusinessId(created.id))!;
      expect(DiaryType.fromValue(stored.type), DiaryType.tiptap);
      expect(stored.contentText, 'bold body');
    });

    test('plain text keeps literal Markdown syntax', () async {
      final created = await writes.create(
        title: 'Literal',
        content: '**not bold** # not a heading',
        format: DiaryContentFormat.plainText,
      );

      final stored = (await diaries.getDiaryByBusinessId(created.id))!;
      expect(stored.contentText, '**not bold** # not a heading');
      expect(diaryToMarkdown(stored), r'\*\*not bold\*\* \# not a heading');
    });

    test('markdown media reaches the diary_media columns', () async {
      final created = await writes.create(
        title: 'Photo',
        content: 'a picture ![pic](image-1.png)',
      );

      expect(created.imageName, ['image-1.png']);
      // Reading the row back assembles the media lists from diary_media, so an
      // empty list here means the new row was never indexed for the library.
      final stored = (await diaries.getDiaryByBusinessId(created.id))!;
      expect(stored.imageName, ['image-1.png']);
    });

    test('a document patch replaces the body and its media', () async {
      final created = await writes.create(title: 'Media', content: 'no media');
      final document = jsonEncode(
        TiptapContent.newDoc([
          {
            'type': 'paragraph',
            'content': [
              {'type': 'text', 'text': 'with picture '},
              {
                'type': 'image',
                'attrs': {'src': 'image-1.png', 'name': 'pic'},
              },
            ],
          },
        ]),
      );

      await writes.update(
        id: created.id,
        patch: DiaryPatch(content: document),
        format: DiaryContentFormat.document,
      );

      final stored = (await diaries.getDiaryByBusinessId(created.id))!;
      expect(stored.imageName, ['image-1.png']);
      expect(stored.contentText, contains('with picture'));
    });
  });

  group('media ownership', () {
    Matcher foreignMedia() => throwsA(
      isA<DiaryOpsException>().having(
        (error) => error.failure,
        'failure',
        DiaryOpsFailure.foreignMedia,
      ),
    );

    test('create refuses any media reference it cannot own', () async {
      // A new diary owns no media, so any media reference is somebody else's.
      final derived = await writes.create(
        title: 'Attached',
        content: imageDoc('image-1.png'),
        format: DiaryContentFormat.document,
      );
      expect(derived.imageName, ['image-1.png']);

      await expectLater(
        writes.create(
          title: 'Borrowed',
          content: imageDoc('image-9.png'),
          format: DiaryContentFormat.document,
          enforceOwnMedia: true,
        ),
        foreignMedia(),
      );
      expect(await diaries.getAllDiaries(), hasLength(1));
    });

    test('update refuses media the diary does not own', () async {
      final created = await writes.create(
        title: 'Owned',
        content: imageDoc('image-1.png'),
        format: DiaryContentFormat.document,
      );

      await expectLater(
        writes.update(
          id: created.id,
          patch: DiaryPatch(content: imageDoc('image-9.png')),
          format: DiaryContentFormat.document,
          enforceOwnMedia: true,
        ),
        foreignMedia(),
      );

      // The check runs before the body is stored, so the row is untouched.
      final stored = (await diaries.getDiaryByBusinessId(created.id))!;
      expect(stored.imageName, ['image-1.png']);
      expect(stored.content, created.content);
    });

    test('update allows owned media and extraAllowedMedia', () async {
      final created = await writes.create(
        title: 'Owned',
        content: imageDoc('image-1.png'),
        format: DiaryContentFormat.document,
      );

      final kept = await writes.update(
        id: created.id,
        patch: DiaryPatch(content: imageDoc('image-1.png')),
        format: DiaryContentFormat.document,
        enforceOwnMedia: true,
      );
      expect(kept.imageName, ['image-1.png']);

      final attached = await writes.update(
        id: created.id,
        patch: DiaryPatch(content: imageDoc('image-2.png')),
        format: DiaryContentFormat.document,
        enforceOwnMedia: true,
        extraAllowedMedia: const {'image-2.png'},
      );
      expect(attached.imageName, ['image-2.png']);
    });
  });
}
