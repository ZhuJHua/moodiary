import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fast_image/fast_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';
import 'package:moodiary_tools/moodiary_tools.dart';

import '../support.dart';

/// 8 byte PNG signature plus filler, enough for the magic number sniffer.
final Uint8List pngBytes = Uint8List.fromList([
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
  ...List<int>.generate(24, (i) => i),
]);

final Uint8List pdfBytes = Uint8List.fromList(utf8.encode('%PDF-1.7\n%\n'));

class _ReadTrackingMediaStore extends DiaryMediaStore {
  _ReadTrackingMediaStore({required super.pathOf});

  bool readCalled = false;

  @override
  Future<Uint8List?> read(MediaType kind, String name) {
    readCalled = true;
    return super.read(kind, name);
  }
}

class _HeifDecoder implements IHeifDecoder {
  bool fail = false;
  Uint8List? sourceBytes;
  String? sourcePath;
  final jpegBytes = Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3]);

  @override
  Future<String?> convert(String srcPath, {required String outputPath}) async {
    sourcePath = srcPath;
    sourceBytes = await File(srcPath).readAsBytes();
    if (fail) return null;
    await File(outputPath).writeAsBytes(jpegBytes);
    return outputPath;
  }
}

void main() {
  late Directory root;
  late _ReadTrackingMediaStore store;
  late MoodiaryDatabase db;
  late DiaryRepository diaries;
  late CategoryRepository categories;
  late TestToolClient client;
  late _HeifDecoder decoder;

  setUpAll(() {
    root = Directory.systemTemp.createTempSync('mcp-media-');
    PlatformService.get().applicationSupportPath = root.path;
    PlatformService.get().applicationCachePath = '${root.path}/cache';
    FastImageRuntime.configure(
      imageDir: '${root.path}/unused-images',
      thumbDir: '${root.path}/unused-thumbs',
    );
    if (!getIt.isRegistered<IKVStorage>()) {
      getIt.registerSingleton<IKVStorage>(MemoryKVStorage());
    }
  });

  tearDownAll(() async {
    await getIt.reset();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  void buildServer() {
    client = TestToolClient(
      ToolContext(
        tags: TagRepository(db),
        diaries: diaries,
        categories: categories,
        insights: MoodInsightsRepository(db),
        surface: ToolSurface.mcp,
        mediaStore: store,
        heifDecoder: decoder,
      ),
    );
  }

  setUp(() async {
    await AppFiles.initCreateDir();
    decoder = _HeifDecoder();
    store = _ReadTrackingMediaStore(
      pathOf: (kind, name) =>
          name.isEmpty ? '${root.path}/$kind' : '${root.path}/$kind/$name',
    );
    db = openTestDatabase();
    diaries = DiaryRepository(db);
    categories = CategoryRepository(db);
    buildServer();
  });

  tearDown(() async {
    await db.close();
    final scratch = Directory(AppFiles.getCachePath('import/mcp'));
    if (scratch.existsSync()) expect(scratch.listSync(), isEmpty);
    for (final entry in root.listSync()) {
      entry.deleteSync(recursive: true);
    }
  });

  /// Writes a media file into the temporary directory the store resolves
  /// against.
  void writeMedia(String kind, String name, List<int> bytes) {
    final file = File('${root.path}/$kind/$name');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes);
  }

  Map<String, dynamic> imageNode(String src) => {
    'type': 'image',
    'attrs': {'src': src},
  };

  test('every shared tool returns data matching its output schema', () async {
    final category = await CategoryOps(categories: categories)
        .create(name: 'Empty');
    writeMedia('image', 'sample.png', pngBytes);
    await diaries.insertADiary(
      makeDiary('sample', 'schema sample', media: [imageNode('sample.png')]),
    );
    await diaries.insertADiary(makeDiary('delete-me', 'delete sample'));
    final inputs = <String, Map<String, Object?>>{
      'get_diary': {
        'ids': ['sample'],
      },
      'create_diary': {
        'items': [
          {'content': 'Created by a shared tool'},
        ],
      },
      'update_diary': {
        'items': [
          {'id': 'sample', 'title': 'Updated'},
        ],
      },
      'delete_diary': {
        'ids': ['delete-me'],
      },
      'search_diaries': {'query': 'sample'},
      'get_diary_links': {'id': 'sample'},
      'list_tags': {},
      'list_categories': {},
      'create_category': {
        'items': [
          {'name': 'Created'},
        ],
      },
      'update_category': {
        'items': [
          {'id': category.id, 'name': 'Renamed'},
        ],
      },
      'delete_category': {
        'ids': [category.id],
      },
      'list_diary_media': {'id': 'sample'},
      'read_diary_media': {'id': 'sample', 'name': 'sample.png'},
      'add_diary_image': {'id': 'sample', 'data': base64Encode(pngBytes)},
      'add_diary_attachment': {
        'id': 'sample',
        'data': base64Encode(pdfBytes),
        'fileName': 'report.pdf',
      },
      'get_stats': {},
    };
    expect(inputs.keys.toSet(), moodiaryTools.map((tool) => tool.name).toSet());
    for (final tool in moodiaryTools) {
      final result = await tool.call(inputs[tool.name]!, client.context);
      expect(
        await tool.output.validate(result.data),
        isEmpty,
        reason: tool.name,
      );
      if (tool.name == 'read_diary_media') {
        expect(result.media.single.bytes, pngBytes);
        expect(diaryIdsIn(result.data), ['sample']);
      }
    }
  });

  group('list_diary_media', () {
    test('reports every list with mime type, size and existence', () async {
      writeMedia('image', 'image-abc.png', pngBytes);
      writeMedia('audio', 'audio-abc.m4a', const [1, 2, 3]);
      await diaries.insertADiary(
        makeDiary(
          'diary-1',
          'a day with media',
          media: [
            imageNode('image-abc.png'),
            imageNode('image-missing.png'),
            {
              'type': 'audio',
              'attrs': {'src': 'audio-abc.m4a'},
            },
          ],
        ),
      );

      final data = (await client.toolCall('list_diary_media', {
        'id': 'diary-1',
      })).data;
      expect(data['id'], 'diary-1');
      expect(data['title'], 'title-diary-1');
      expect(data['count'], 3);
      final media = data['media'] as Map<String, dynamic>;
      expect(media['images'], [
        {
          'name': 'image-abc.png',
          'mimeType': 'image/png',
          'bytes': pngBytes.length,
          'exists': true,
        },
        {
          'name': 'image-missing.png',
          'mimeType': 'image/png',
          'bytes': -1,
          'exists': false,
        },
      ]);
      expect(media['audio'], [
        {
          'name': 'audio-abc.m4a',
          'mimeType': 'audio/mp4',
          'bytes': 3,
          'exists': true,
        },
      ]);
      expect(media['videos'], isEmpty);
      expect(media['files'], isEmpty);
    });

    test('a diary without media answers empty lists', () async {
      await diaries.insertADiary(makeDiary('diary-1', 'plain body'));
      final data = (await client.toolCall('list_diary_media', {
        'id': 'diary-1',
      })).data;
      expect(data['count'], 0);
      expect(data['media'], {
        'images': <Object>[],
        'audio': <Object>[],
        'videos': <Object>[],
        'files': <Object>[],
      });
    });

    test('an unknown diary is a tool error', () async {
      final response = client.toolCall('list_diary_media', {'id': 'missing'});

      await expectLater(
        response,
        throwsA(
          isA<ToolFailure>().having(
            (error) => error.message,
            'message',
            contains('no diary with id="missing"'),
          ),
        ),
      );
    });
  });

  group('add_diary_image', () {
    test(
      'writes the file, inserts a node and re-derives the media list',
      () async {
        await diaries.insertADiary(makeDiary('diary-1', 'before'));
        final response = await client.toolCall('add_diary_image', {
          'id': 'diary-1',
          'data': base64Encode(pngBytes),
          'name': 'cat.png',
          'widthPercent': 60,
        });

        final data = (response).data;
        expect(data['added'], isTrue);
        expect(data['mimeType'], 'image/png');
        expect(data['bytes'], pngBytes.length);
        final name = data['name'] as String;
        expect(name, matches(RegExp(r'^image-[0-9a-f-]{36}\.png$')));
        expect(data, isNot(contains('content')));

        final diary = data['diary'] as Map<String, dynamic>;
        expect(diary['id'], 'diary-1');
        expect(diary['title'], 'title-diary-1');
        final media = diary['media'] as Map<String, dynamic>;
        expect(media['images'], [name]);

        expect(File('${root.path}/image/$name').readAsBytesSync(), pngBytes);

        final stored = (await diaries.getDiaryByBusinessId('diary-1'))!;
        expect(stored.imageName, [name]);
        final blocks = (jsonDecode(stored.content) as Map)['content'] as List;
        final node = blocks.last as Map<String, dynamic>;
        expect(node['type'], 'image');
        expect(node['attrs'], {
          'src': name,
          'name': 'cat.png',
          'widthPercent': 60,
        });
      },
    );

    test('sniffs the type and puts the node at the start on request', () async {
      await diaries.insertADiary(
        makeDiary(
          'diary-1',
          'body',
          media: [
            {
              'type': 'image',
              'attrs': {'src': 'image-old.png'},
            },
          ],
        ),
      );
      final data = (await client.toolCall('add_diary_image', {
        'id': 'diary-1',
        'data': base64Encode(pngBytes),
        'position': 'start',
      })).data;
      expect(data['mimeType'], 'image/png');
      final name = data['name'] as String;
      final stored = (await diaries.getDiaryByBusinessId('diary-1'))!;
      expect(stored.imageName, [name, 'image-old.png']);
      final blocks = (jsonDecode(stored.content) as Map)['content'] as List;
      final node = blocks.first as Map<String, dynamic>;
      expect(node['type'], 'image');
      expect((node['attrs'] as Map)['src'], name);
      // No name argument: the stored name is the display name.
      expect((node['attrs'] as Map)['name'], name);
    });

    test('widthPercent omitted or null keeps the document default', () async {
      // `null` means the same as omitting the argument: the node carries no
      // width attribute, so the editor's own default applies.
      final cases = <Map<String, dynamic>>[
        {},
        {'widthPercent': null},
      ];
      for (var index = 0; index < cases.length; index++) {
        final id = 'diary-$index';
        await diaries.insertADiary(makeDiary(id, 'body'));
        final data = (await client.toolCall('add_diary_image', {
          'id': id,
          'data': base64Encode(pngBytes),
          ...cases[index],
        })).data;
        final name = data['name'] as String;
        final stored = (await diaries.getDiaryByBusinessId(id))!;
        final blocks = (jsonDecode(stored.content) as Map)['content'] as List;
        final node = blocks.last as Map<String, dynamic>;
        expect(node['attrs'], {'src': name, 'name': name});
      }
    });

    test('invalid base64 is invalid params', () async {
      await diaries.insertADiary(makeDiary('diary-1', 'body'));
      final response = client.toolCall('add_diary_image', {
        'id': 'diary-1',
        'data': 'not base64!!',
      });
      await expectLater(response, throwsA(isA<ToolArgumentException>()));
    });

    test('an empty payload is invalid params', () async {
      await diaries.insertADiary(makeDiary('diary-1', 'body'));
      final response = client.toolCall('add_diary_image', {
        'id': 'diary-1',
        'data': '',
      });
      await expectLater(response, throwsA(isA<ToolArgumentException>()));
    });

    for (final (mime, brand) in [
      ('image/heic', 'heic'),
      ('image/heif', 'mif1'),
    ]) {
      for (final explicitMime in [false, true]) {
        test('$mime converts to JPEG (explicit MIME: $explicitMime)', () async {
          final bytes = Uint8List.fromList([
            0,
            0,
            0,
            24,
            ...ascii.encode('ftyp$brand'),
            ...List<int>.filled(12, 0),
          ]);
          await diaries.insertADiary(makeDiary('diary-1', 'body'));
          final response = await client.toolCall('add_diary_image', {
            'id': 'diary-1',
            'data': base64Encode(bytes),
            if (explicitMime) 'mimeType': mime,
          });

          final data = (response).data;
          final name = data['name'] as String;
          expect(name, matches(RegExp(r'^image-[0-9a-f-]{36}\.jpg$')));
          expect(data['mimeType'], 'image/jpeg');
          expect(data['bytes'], decoder.jpegBytes.length);
          expect(decoder.sourceBytes, bytes);
          expect(File(decoder.sourcePath!).existsSync(), isFalse);
          expect(
            File('${root.path}/image/$name').readAsBytesSync(),
            decoder.jpegBytes,
          );
          expect(MediaHolds.contains(MediaType.image, name), isTrue);
          final stored = (await diaries.getDiaryByBusinessId('diary-1'))!;
          expect(stored.imageName, [name]);
          final blocks = (jsonDecode(stored.content) as Map)['content'] as List;
          expect(blocks.last['type'], 'image');
          expect(blocks.last['attrs']['src'], name);
        });
      }
    }

    test(
      'a failed conversion returns a write error and removes scratch',
      () async {
        decoder.fail = true;
        await diaries.insertADiary(makeDiary('diary-1', 'body'));
        final response = client.toolCall('add_diary_image', {
          'id': 'diary-1',
          'data': base64Encode(ascii.encode('unknown image header')),
          'mimeType': 'image/heic',
        });

        await expectLater(
          response,
          throwsA(
            isA<ToolFailure>().having(
              (error) => error.message,
              'message',
              contains('could not write'),
            ),
          ),
        );
        expect(File(decoder.sourcePath!).existsSync(), isFalse);
        expect(
          (await diaries.getDiaryByBusinessId('diary-1'))!.imageName,
          isEmpty,
        );
      },
    );

    test('an unsupported image type is refused', () async {
      await diaries.insertADiary(makeDiary('diary-1', 'body'));
      final response = client.toolCall('add_diary_image', {
        'id': 'diary-1',
        'data': base64Encode(pngBytes),
        'mimeType': 'image/tiff',
      });

      await expectLater(
        response,
        throwsA(
          isA<ToolFailure>().having(
            (error) => error.message,
            'message',
            contains('not supported'),
          ),
        ),
      );
    });

    test('a mime type that contradicts the bytes is refused', () async {
      await diaries.insertADiary(makeDiary('diary-1', 'body'));
      final response = client.toolCall('add_diary_image', {
        'id': 'diary-1',
        'data': base64Encode(pngBytes),
        'mimeType': 'image/jpeg',
      });

      await expectLater(
        response,
        throwsA(
          isA<ToolFailure>().having(
            (error) => error.message,
            'message',
            contains('looks like image/png'),
          ),
        ),
      );
    });

    test('a payload above the 16 MB cap is refused before decoding', () async {
      await diaries.insertADiary(makeDiary('diary-1', 'body'));
      // The estimate runs on the base64 length, so the payload only has to be
      // large enough; a 16 MB buffer encodes to ~21.3 MB of wire text.
      final oversized = base64Encode(Uint8List(16 * 1024 * 1024 + 1));
      final response = client.toolCall('add_diary_image', {
        'id': 'diary-1',
        'data': oversized,
      });

      await expectLater(
        response,
        throwsA(
          isA<ToolFailure>().having(
            (error) => error.message,
            'message',
            contains('16.0 MB'),
          ),
        ),
      );
    });

    test('an unknown diary is a tool error and writes nothing', () async {
      final response = client.toolCall('add_diary_image', {
        'id': 'missing',
        'data': base64Encode(pngBytes),
      });

      await expectLater(
        response,
        throwsA(
          isA<ToolFailure>().having(
            (error) => error.message,
            'message',
            contains('no diary with id="missing"'),
          ),
        ),
      );
      expect(
        Directory('${root.path}/image').listSync().whereType<File>(),
        isEmpty,
      );
    });

    test('a legacy markdown diary is refused with advice', () async {
      await diaries.insertADiary(
        makeDiary('diary-1', 'legacy **body**', type: 'markdown'),
      );
      final response = client.toolCall('add_diary_image', {
        'id': 'diary-1',
        'data': base64Encode(pngBytes),
      });

      await expectLater(
        response,
        throwsA(
          isA<ToolFailure>().having(
            (error) => error.message,
            'message',
            contains('Tiptap'),
          ),
        ),
      );
      await expectLater(
        response,
        throwsA(
          isA<ToolFailure>().having(
            (error) => error.message,
            'message',
            contains('contentFormat="document"'),
          ),
        ),
      );
    });
  });

  group('add_diary_attachment', () {
    test('concurrent appends keep both nodes and media names', () async {
      await diaries.insertADiary(makeDiary('diary-1', 'body'));
      final responses = await Future.wait([
        for (final fileName in ['first.pdf', 'second.pdf'])
          client.toolCall('add_diary_attachment', {
            'id': 'diary-1',
            'data': base64Encode(pdfBytes),
            'fileName': fileName,
          }),
      ]);

      final names = responses.map((response) => (response).data['name']);
      expect(names.toSet(), hasLength(2));
      final stored = (await diaries.getDiaryByBusinessId('diary-1'))!;
      expect(stored.fileName, unorderedEquals(names));
      final blocks = (jsonDecode(stored.content) as Map)['content'] as List;
      final attachments = blocks.where((node) => node['type'] == 'attachment');
      expect(attachments, hasLength(2));
      expect(
        attachments.map((node) => node['attrs']['src']),
        unorderedEquals(names),
      );
      expect(
        attachments.map((node) => node['attrs']['name']),
        unorderedEquals(['first.pdf', 'second.pdf']),
      );
      for (final name in names) {
        expect(File('${root.path}/file/$name').readAsBytesSync(), pdfBytes);
      }
    });

    test('writes the file and inserts an attachment node', () async {
      await diaries.insertADiary(makeDiary('diary-1', 'body'));
      final response = await client.toolCall('add_diary_attachment', {
        'id': 'diary-1',
        'data': base64Encode(pdfBytes),
        'fileName': 'report.pdf',
      });

      final data = (response).data;
      expect(data['added'], isTrue);
      expect(data['mimeType'], 'application/pdf');
      expect(data['bytes'], pdfBytes.length);
      final name = data['name'] as String;
      expect(name, matches(RegExp(r'^file-[0-9a-f-]{36}\.pdf$')));
      final diary = data['diary'] as Map<String, dynamic>;
      expect((diary['media'] as Map)['files'], [name]);
      expect(File('${root.path}/file/$name').readAsBytesSync(), pdfBytes);
      expect(MediaHolds.contains(MediaType.file, name), isTrue);

      final stored = (await diaries.getDiaryByBusinessId('diary-1'))!;
      expect(stored.fileName, [name]);
      final blocks = (jsonDecode(stored.content) as Map)['content'] as List;
      final node = blocks.last as Map<String, dynamic>;
      expect(node['type'], 'attachment');
      expect(node['attrs'], {
        'src': name,
        'name': 'report.pdf',
        'mime': 'application/pdf',
        'size': pdfBytes.length,
      });
    });

    test('an unusable extension becomes .bin and a path is stripped', () async {
      await diaries.insertADiary(makeDiary('diary-1', 'body'));
      final data = (await client.toolCall('add_diary_attachment', {
        'id': 'diary-1',
        'data': base64Encode(pdfBytes),
        'fileName': r'folder\notes.bad~ext',
      })).data;
      expect(data['name'], endsWith('.bin'));
      final stored = (await diaries.getDiaryByBusinessId('diary-1'))!;
      final blocks = (jsonDecode(stored.content) as Map)['content'] as List;
      final node = blocks.last as Map<String, dynamic>;
      expect((node['attrs'] as Map)['name'], r'notes.bad~ext');
    });

    test(
      'a failed attachment write leaves the diary and scratch empty',
      () async {
        await Directory('${root.path}/file').delete();
        await File('${root.path}/file').writeAsString('blocked');
        await diaries.insertADiary(makeDiary('diary-1', 'body'));
        final response = client.toolCall('add_diary_attachment', {
          'id': 'diary-1',
          'data': base64Encode(pdfBytes),
          'fileName': 'report.pdf',
        });

        await expectLater(
          response,
          throwsA(
            isA<ToolFailure>().having(
              (error) => error.message,
              'message',
              contains('could not write'),
            ),
          ),
        );
        expect(
          (await diaries.getDiaryByBusinessId('diary-1'))!.fileName,
          isEmpty,
        );
      },
    );

    test('a dot filename stays inside the scratch directory', () async {
      await diaries.insertADiary(makeDiary('diary-1', 'body'));
      final response = await client.toolCall('add_diary_attachment', {
        'id': 'diary-1',
        'data': base64Encode(pdfBytes),
        'fileName': '..',
        'mimeType': 'application/x-custom',
      });

      final data = (response).data;
      expect(data['name'], endsWith('.bin'));
      expect(data['mimeType'], 'application/x-custom');
      expect(
        File('${root.path}/file/${data['name']}').readAsBytesSync(),
        pdfBytes,
      );
    });

    test('fileName is required and must not be blank', () async {
      await diaries.insertADiary(makeDiary('diary-1', 'body'));
      final response = client.toolCall('add_diary_attachment', {
        'id': 'diary-1',
        'data': base64Encode(pdfBytes),
      });
      await expectLater(response, throwsA(isA<ToolArgumentException>()));
    });

    test('invalid base64 is invalid params', () async {
      await diaries.insertADiary(makeDiary('diary-1', 'body'));
      final response = client.toolCall('add_diary_attachment', {
        'id': 'diary-1',
        'data': '%%%',
        'fileName': 'report.pdf',
      });
      await expectLater(response, throwsA(isA<ToolArgumentException>()));
    });

    test('a malformed mimeType is invalid params', () async {
      await diaries.insertADiary(makeDiary('diary-1', 'body'));
      final response = client.toolCall('add_diary_attachment', {
        'id': 'diary-1',
        'data': base64Encode(pdfBytes),
        'fileName': 'report.pdf',
        'mimeType': 'not-a-mime',
      });
      await expectLater(response, throwsA(isA<ToolArgumentException>()));
    });
  });

  group('read_diary_media', () {
    test('an image comes back as image content plus metadata', () async {
      writeMedia('image', 'image-abc.png', pngBytes);
      await diaries.insertADiary(
        makeDiary(
          'diary-1',
          'body',
          title: 'A day',
          media: [imageNode('image-abc.png')],
        ),
      );

      final response = await client.toolCall('read_diary_media', {
        'id': 'diary-1',
        'name': 'image-abc.png',
      });

      expect(response.media, hasLength(1));
      expect(response.media.single.mimeType, 'image/png');
      expect(response.media.single.bytes, pngBytes);

      final metadata = (response).data;
      expect(metadata, {
        'id': 'diary-1',
        'title': 'A day',
        'name': 'image-abc.png',
        'kind': 'image',
        'mimeType': 'image/png',
        'bytes': pngBytes.length,
        'exists': true,
      });
    });

    for (final kind in ['audio', 'video', 'file']) {
      test('$kind returns an images-only tool error', () async {
        final name = '$kind-example.bin';
        await diaries.insertADiary(
          makeDiary(
            'diary-1',
            'body',
            media: [
              {
                'type': kind == 'file' ? 'attachment' : kind,
                'attrs': {'src': name},
              },
            ],
          ),
        );

        for (final explicitKind in [false, true]) {
          final response = client.toolCall('read_diary_media', {
            'id': 'diary-1',
            'name': name,
            if (explicitKind) 'kind': kind,
          });

          await expectLater(
            response,
            throwsA(
              isA<ToolFailure>().having(
                (error) => error.message,
                'message',
                'read_diary_media: only images can be read.',
              ),
            ),
          );
        }
      });
    }

    test('the kind argument selects the list and is cross-checked', () async {
      writeMedia('image', 'image-abc.png', pngBytes);
      await diaries.insertADiary(
        makeDiary('diary-1', 'body', media: [imageNode('image-abc.png')]),
      );

      final wrongKind = client.toolCall('read_diary_media', {
        'id': 'diary-1',
        'name': 'image-abc.png',
        'kind': 'file',
      });

      await expectLater(
        wrongKind,
        throwsA(
          isA<ToolFailure>().having(
            (error) => error.message,
            'message',
            contains('has no file media'),
          ),
        ),
      );

      await client.toolCall('read_diary_media', {
        'id': 'diary-1',
        'name': 'image-abc.png',
        'kind': 'image',
      });
    });

    test('a name the diary does not reference is refused', () async {
      await diaries.insertADiary(makeDiary('diary-1', 'body'));
      final response = client.toolCall('read_diary_media', {
        'id': 'diary-1',
        'name': 'image-abc.png',
      });

      await expectLater(
        response,
        throwsA(
          isA<ToolFailure>().having(
            (error) => error.message,
            'message',
            contains('has no image media'),
          ),
        ),
      );
    });

    test(
      'path traversal and absolute paths never reach the filesystem',
      () async {
        await diaries.insertADiary(makeDiary('diary-1', 'body'));
        for (final name in ['../secret.png', '/etc/passwd', r'..\secret.png']) {
          final response = client.toolCall('read_diary_media', {
            'id': 'diary-1',
            'name': name,
          });

          await expectLater(
            response,
            throwsA(
              isA<ToolFailure>().having(
                (error) => error.message,
                'message',
                contains('has no image media'),
              ),
            ),
          );
        }
      },
    );

    test('a referenced file missing from the device is a tool error', () async {
      await diaries.insertADiary(
        makeDiary('diary-1', 'body', media: [imageNode('image-gone.png')]),
      );
      final response = client.toolCall('read_diary_media', {
        'id': 'diary-1',
        'name': 'image-gone.png',
      });

      await expectLater(
        response,
        throwsA(
          isA<ToolFailure>().having(
            (error) => error.message,
            'message',
            contains('missing from the image'),
          ),
        ),
      );
    });

    test('an image above the inline cap is refused, not truncated', () async {
      final big = Uint8List.fromList([
        ...pngBytes,
        ...List<int>.filled(8 * 1024 * 1024, 0),
      ]);
      writeMedia('image', 'image-big.png', big);
      await diaries.insertADiary(
        makeDiary('diary-1', 'body', media: [imageNode('image-big.png')]),
      );
      final response = client.toolCall('read_diary_media', {
        'id': 'diary-1',
        'name': 'image-big.png',
      });

      await expectLater(
        response,
        throwsA(
          isA<ToolFailure>().having(
            (error) => error.message,
            'message',
            contains('inline limit'),
          ),
        ),
      );
      expect(store.readCalled, isFalse);
    });

    test('an unknown diary is a tool error', () async {
      final response = client.toolCall('read_diary_media', {
        'id': 'missing',
        'name': 'image-abc.png',
      });

      await expectLater(
        response,
        throwsA(
          isA<ToolFailure>().having(
            (error) => error.message,
            'message',
            contains('no diary with id="missing"'),
          ),
        ),
      );
    });
  });

  group('recycled diaries', () {
    test('are hidden from every media tool', () async {
      await diaries.insertADiary(
        makeDiary(
          'bin',
          'hidden body',
          show: false,
          media: [imageNode('image-abc.png')],
        ),
      );
      writeMedia('image', 'image-abc.png', pngBytes);
      final filesBefore = root
          .listSync(recursive: true)
          .whereType<File>()
          .length;

      final calls = <(String, Map<String, dynamic>)>[
        ('list_diary_media', {'id': 'bin'}),
        ('read_diary_media', {'id': 'bin', 'name': 'image-abc.png'}),
        ('add_diary_image', {'id': 'bin', 'data': base64Encode(pngBytes)}),
        (
          'add_diary_attachment',
          {'id': 'bin', 'data': base64Encode(pdfBytes), 'fileName': 'doc.pdf'},
        ),
      ];
      for (final (tool, arguments) in calls) {
        final response = client.toolCall(tool, arguments);

        await expectLater(
          response,
          throwsA(
            isA<ToolFailure>().having(
              (error) => error.message,
              'message',
              contains('no diary with id="bin"'),
            ),
          ),
          reason: tool,
        );
      }
      expect(
        root.listSync(recursive: true).whereType<File>().length,
        filesBefore,
        reason: 'a hidden diary must not receive a media file',
      );
    });
  });
}
