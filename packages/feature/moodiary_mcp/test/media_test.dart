import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_mcp/src/media/diary_media.dart';
import 'package:moodiary_mcp/src/protocol/json_rpc.dart';
import 'package:moodiary_mcp/src/registry/mcp_registry.dart';
import 'package:moodiary_mcp/src/resources/media_resources.dart';
import 'package:moodiary_mcp/src/server/mcp_server.dart';
import 'package:moodiary_mcp/src/server/mcp_session.dart';
import 'package:moodiary_mcp/src/tools/media_tools.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';

import 'support.dart';

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

void main() {
  late Directory root;
  late DiaryMediaStore store;
  late MoodiaryDatabase db;
  late DiaryRepository diaries;
  late CategoryRepository categories;
  late McpServer server;
  late McpSessionState session;
  late TestMcpClient client;

  setUpAll(() {
    if (!getIt.isRegistered<IKVStorage>()) {
      getIt.registerSingleton<IKVStorage>(MemoryKVStorage());
    }
  });

  /// Catalog with only the media tools and resources, so the test does not
  /// depend on the rest of the frozen catalog.
  void buildServer() {
    final registry = McpRegistry();
    registerMediaTools(
      registry,
      diaries: diaries,
      categories: categories,
      store: store,
    );
    registerMediaResources(registry, diaries: diaries, store: store);
    server = McpServer(registry: registry, serverVersion: 'test');
    session = server.createSession();
    client = TestMcpClient(server: server, session: session);
  }

  setUp(() async {
    root = Directory.systemTemp.createTempSync('mcp-media-');
    store = DiaryMediaStore(
      pathOf: (kind, name) =>
          name.isEmpty ? '${root.path}/$kind' : '${root.path}/$kind/$name',
    );
    db = MoodiaryDatabase.forTesting(
      NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA foreign_keys = ON'),
      ),
    );
    diaries = DiaryRepository(db);
    categories = CategoryRepository(db);
    buildServer();
  });

  tearDown(() async {
    server.dispose();
    await db.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<Map<String, dynamic>> call(
    String method, [
    Map<String, dynamic> params = const {},
  ]) => client.call(method, params);

  Future<Map<String, dynamic>> toolCall(
    String name, [
    Map<String, dynamic> arguments = const {},
  ]) => client.toolCall(name, arguments);

  Map<String, dynamic> resourceContent(Map<String, dynamic> response) =>
      ((resultOf(response)['contents'] as List).single as Map)
          .cast<String, dynamic>();

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

  Map<String, dynamic> attachmentNode(String src) => {
    'type': 'attachment',
    'attrs': {'src': src},
  };

  test('catalog advertises the media tools and the media template', () async {
    final listed = resultOf(await call('tools/list'));
    final tools = (listed['tools'] as List).cast<Map<String, dynamic>>();
    expect(
      {for (final tool in tools) tool['name']},
      {
        'list_diary_media',
        'read_diary_media',
        'add_diary_image',
        'add_diary_attachment',
      },
    );
    for (final tool in tools) {
      expect((tool['description'] as String).trim(), isNotEmpty);
      expect(tool['inputSchema'], containsPair('type', 'object'));
    }
    final byName = {for (final tool in tools) tool['name']: tool};
    for (final name in ['list_diary_media', 'read_diary_media']) {
      expect(
        (byName[name]!['annotations'] as Map)['readOnlyHint'],
        isTrue,
        reason: '$name must be read only',
      );
      expect(
        (byName[name]!['annotations'] as Map)['idempotentHint'],
        isTrue,
        reason: '$name must be idempotent',
      );
    }
    for (final name in ['add_diary_image', 'add_diary_attachment']) {
      expect(
        (byName[name]!['annotations'] as Map)['readOnlyHint'],
        isFalse,
        reason: '$name must not be read only',
      );
    }
    expect((byName['add_diary_image']!['inputSchema'] as Map)['required'], [
      'id',
      'data',
    ]);
    expect(
      (byName['add_diary_attachment']!['inputSchema'] as Map)['required'],
      ['id', 'data', 'fileName'],
    );

    final templates = resultOf(await call('resources/templates/list'));
    final uris = [
      for (final template in templates['resourceTemplates'] as List)
        (template as Map)['uriTemplate'],
    ];
    expect(uris, contains('moodiary://diary/{id}/media/{name}'));
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

      final data = structuredOf(
        await toolCall('list_diary_media', {'id': 'diary-1'}),
      );
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
      final data = structuredOf(
        await toolCall('list_diary_media', {'id': 'diary-1'}),
      );
      expect(data['count'], 0);
      expect(data['media'], {
        'images': <Object>[],
        'audio': <Object>[],
        'videos': <Object>[],
        'files': <Object>[],
      });
    });

    test('an unknown diary is a tool error', () async {
      final response = await toolCall('list_diary_media', {'id': 'missing'});
      expect(resultOf(response)['isError'], isTrue);
      expect(textOf(response), contains('no diary with id="missing"'));
    });
  });

  group('add_diary_image', () {
    test(
      'writes the file, inserts a node and re-derives the media list',
      () async {
        await diaries.insertADiary(makeDiary('diary-1', 'before'));
        final response = await toolCall('add_diary_image', {
          'id': 'diary-1',
          'data': base64Encode(pngBytes),
          'name': 'cat.png',
          'widthPercent': 60,
        });
        expect(resultOf(response)['isError'], isFalse);
        final data = structuredOf(response);
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
      final data = structuredOf(
        await toolCall('add_diary_image', {
          'id': 'diary-1',
          'data': base64Encode(pngBytes),
          'position': 'start',
        }),
      );
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
        final data = structuredOf(
          await toolCall('add_diary_image', {
            'id': id,
            'data': base64Encode(pngBytes),
            ...cases[index],
          }),
        );
        final name = data['name'] as String;
        final stored = (await diaries.getDiaryByBusinessId(id))!;
        final blocks = (jsonDecode(stored.content) as Map)['content'] as List;
        final node = blocks.last as Map<String, dynamic>;
        expect(node['attrs'], {'src': name, 'name': name});
      }
    });

    test('invalid base64 is invalid params', () async {
      await diaries.insertADiary(makeDiary('diary-1', 'body'));
      final response = await toolCall('add_diary_image', {
        'id': 'diary-1',
        'data': 'not base64!!',
      });
      expect(errorCode(response), JsonRpcCode.invalidParams);
    });

    test('an empty payload is invalid params', () async {
      await diaries.insertADiary(makeDiary('diary-1', 'body'));
      final response = await toolCall('add_diary_image', {
        'id': 'diary-1',
        'data': '',
      });
      expect(errorCode(response), JsonRpcCode.invalidParams);
    });

    test('HEIC is refused with a readable error', () async {
      await diaries.insertADiary(makeDiary('diary-1', 'body'));
      final response = await toolCall('add_diary_image', {
        'id': 'diary-1',
        'data': base64Encode(pngBytes),
        'mimeType': 'image/heic',
      });
      expect(resultOf(response)['isError'], isTrue);
      expect(textOf(response), contains('HEIC'));
    });

    test('an unsupported image type is refused', () async {
      await diaries.insertADiary(makeDiary('diary-1', 'body'));
      final response = await toolCall('add_diary_image', {
        'id': 'diary-1',
        'data': base64Encode(pngBytes),
        'mimeType': 'image/tiff',
      });
      expect(resultOf(response)['isError'], isTrue);
      expect(textOf(response), contains('not supported'));
    });

    test('a mime type that contradicts the bytes is refused', () async {
      await diaries.insertADiary(makeDiary('diary-1', 'body'));
      final response = await toolCall('add_diary_image', {
        'id': 'diary-1',
        'data': base64Encode(pngBytes),
        'mimeType': 'image/jpeg',
      });
      expect(resultOf(response)['isError'], isTrue);
      expect(textOf(response), contains('looks like image/png'));
    });

    test('a payload above the 16 MB cap is refused before decoding', () async {
      await diaries.insertADiary(makeDiary('diary-1', 'body'));
      // The estimate runs on the base64 length, so the payload only has to be
      // large enough; a 16 MB buffer encodes to ~21.3 MB of wire text.
      final oversized = base64Encode(Uint8List(16 * 1024 * 1024 + 1));
      final response = await toolCall('add_diary_image', {
        'id': 'diary-1',
        'data': oversized,
      });
      expect(resultOf(response)['isError'], isTrue);
      expect(textOf(response), contains('16 MB'));
    });

    test('an unknown diary is a tool error and writes nothing', () async {
      final response = await toolCall('add_diary_image', {
        'id': 'missing',
        'data': base64Encode(pngBytes),
      });
      expect(resultOf(response)['isError'], isTrue);
      expect(textOf(response), contains('no diary with id="missing"'));
      expect(Directory('${root.path}/image').existsSync(), isFalse);
    });

    test('a legacy markdown diary is refused with advice', () async {
      await diaries.insertADiary(
        makeDiary('diary-1', 'legacy **body**', type: 'markdown'),
      );
      final response = await toolCall('add_diary_image', {
        'id': 'diary-1',
        'data': base64Encode(pngBytes),
      });
      expect(resultOf(response)['isError'], isTrue);
      expect(textOf(response), contains('Tiptap'));
      expect(textOf(response), contains('contentFormat="document"'));
    });
  });

  group('add_diary_attachment', () {
    test('writes the file and inserts an attachment node', () async {
      await diaries.insertADiary(makeDiary('diary-1', 'body'));
      final response = await toolCall('add_diary_attachment', {
        'id': 'diary-1',
        'data': base64Encode(pdfBytes),
        'fileName': 'report.pdf',
      });
      expect(resultOf(response)['isError'], isFalse);
      final data = structuredOf(response);
      expect(data['added'], isTrue);
      expect(data['mimeType'], 'application/pdf');
      expect(data['bytes'], pdfBytes.length);
      final name = data['name'] as String;
      expect(name, matches(RegExp(r'^file-[0-9a-f-]{36}\.pdf$')));
      final diary = data['diary'] as Map<String, dynamic>;
      expect((diary['media'] as Map)['files'], [name]);
      expect(File('${root.path}/file/$name').readAsBytesSync(), pdfBytes);

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
      final data = structuredOf(
        await toolCall('add_diary_attachment', {
          'id': 'diary-1',
          'data': base64Encode(pdfBytes),
          'fileName': r'notes.bad~ext',
        }),
      );
      expect(data['name'], endsWith('.bin'));
      final stored = (await diaries.getDiaryByBusinessId('diary-1'))!;
      final blocks = (jsonDecode(stored.content) as Map)['content'] as List;
      final node = blocks.last as Map<String, dynamic>;
      expect((node['attrs'] as Map)['name'], r'notes.bad~ext');
    });

    test('fileName is required and must not be blank', () async {
      await diaries.insertADiary(makeDiary('diary-1', 'body'));
      final response = await toolCall('add_diary_attachment', {
        'id': 'diary-1',
        'data': base64Encode(pdfBytes),
      });
      expect(errorCode(response), JsonRpcCode.invalidParams);
    });

    test('invalid base64 is invalid params', () async {
      await diaries.insertADiary(makeDiary('diary-1', 'body'));
      final response = await toolCall('add_diary_attachment', {
        'id': 'diary-1',
        'data': '%%%',
        'fileName': 'report.pdf',
      });
      expect(errorCode(response), JsonRpcCode.invalidParams);
    });

    test('a malformed mimeType is invalid params', () async {
      await diaries.insertADiary(makeDiary('diary-1', 'body'));
      final response = await toolCall('add_diary_attachment', {
        'id': 'diary-1',
        'data': base64Encode(pdfBytes),
        'fileName': 'report.pdf',
        'mimeType': 'not-a-mime',
      });
      expect(errorCode(response), JsonRpcCode.invalidParams);
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

      final response = await toolCall('read_diary_media', {
        'id': 'diary-1',
        'name': 'image-abc.png',
      });
      expect(resultOf(response)['isError'], isFalse);
      final content = contentOf(response);
      expect(content, hasLength(2));
      expect(content.first['type'], 'image');
      expect(content.first['mimeType'], 'image/png');
      expect(base64Decode(content.first['data'] as String), pngBytes);

      final metadata = structuredOf(response);
      expect(metadata, {
        'id': 'diary-1',
        'title': 'A day',
        'name': 'image-abc.png',
        'kind': 'image',
        'mimeType': 'image/png',
        'bytes': pngBytes.length,
        'exists': true,
        'uri': 'moodiary://diary/diary-1/media/image-abc.png',
      });
      expect(content.last, {'type': 'text', 'text': jsonEncode(metadata)});
    });

    test('a non-inline kind returns metadata plus a resource_link', () async {
      writeMedia('file', 'file-report.pdf', pdfBytes);
      await diaries.insertADiary(
        makeDiary(
          'diary-1',
          'body',
          media: [attachmentNode('file-report.pdf')],
        ),
      );

      final response = await toolCall('read_diary_media', {
        'id': 'diary-1',
        'name': 'file-report.pdf',
      });
      expect(resultOf(response)['isError'], isFalse);
      final content = contentOf(response);
      expect(content, hasLength(2));
      expect(content.first['type'], 'text');
      final metadata = jsonDecode(content.first['text'] as String) as Map;
      expect(metadata['kind'], 'file');
      expect(metadata['mimeType'], 'application/pdf');
      expect(metadata['bytes'], pdfBytes.length);
      expect(content.last['type'], 'resource_link');
      expect(
        content.last['uri'],
        'moodiary://diary/diary-1/media/file-report.pdf',
      );
      expect(content.last['mimeType'], 'application/pdf');
      expect(structuredOf(response), metadata);
    });

    test('the kind argument selects the list and is cross-checked', () async {
      writeMedia('image', 'image-abc.png', pngBytes);
      await diaries.insertADiary(
        makeDiary('diary-1', 'body', media: [imageNode('image-abc.png')]),
      );

      final wrongKind = await toolCall('read_diary_media', {
        'id': 'diary-1',
        'name': 'image-abc.png',
        'kind': 'file',
      });
      expect(resultOf(wrongKind)['isError'], isTrue);
      expect(textOf(wrongKind), contains('has no file media'));

      final rightKind = await toolCall('read_diary_media', {
        'id': 'diary-1',
        'name': 'image-abc.png',
        'kind': 'image',
      });
      expect(resultOf(rightKind)['isError'], isFalse);
    });

    test('a name the diary does not reference is refused', () async {
      await diaries.insertADiary(makeDiary('diary-1', 'body'));
      final response = await toolCall('read_diary_media', {
        'id': 'diary-1',
        'name': 'image-abc.png',
      });
      expect(resultOf(response)['isError'], isTrue);
      expect(textOf(response), contains('has no image media'));
    });

    test(
      'path traversal and absolute paths never reach the filesystem',
      () async {
        await diaries.insertADiary(makeDiary('diary-1', 'body'));
        for (final name in ['../secret.png', '/etc/passwd', r'..\secret.png']) {
          final response = await toolCall('read_diary_media', {
            'id': 'diary-1',
            'name': name,
          });
          expect(
            resultOf(response)['isError'],
            isTrue,
            reason: '$name must be refused',
          );
          expect(textOf(response), contains('has no image media'));
        }
      },
    );

    test('a referenced file missing from the device is a tool error', () async {
      await diaries.insertADiary(
        makeDiary('diary-1', 'body', media: [imageNode('image-gone.png')]),
      );
      final response = await toolCall('read_diary_media', {
        'id': 'diary-1',
        'name': 'image-gone.png',
      });
      expect(resultOf(response)['isError'], isTrue);
      expect(textOf(response), contains('missing from the image'));
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
      final response = await toolCall('read_diary_media', {
        'id': 'diary-1',
        'name': 'image-big.png',
      });
      expect(resultOf(response)['isError'], isTrue);
      expect(textOf(response), contains('inline limit'));
    });

    test('an unknown diary is a tool error', () async {
      final response = await toolCall('read_diary_media', {
        'id': 'missing',
        'name': 'image-abc.png',
      });
      expect(resultOf(response)['isError'], isTrue);
      expect(textOf(response), contains('no diary with id="missing"'));
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
        final response = await toolCall(tool, arguments);
        expect(resultOf(response)['isError'], isTrue, reason: tool);
        expect(
          textOf(response),
          contains('no diary with id="bin"'),
          reason: tool,
        );
      }
      expect(
        root.listSync(recursive: true).whereType<File>().length,
        filesBefore,
        reason: 'a hidden diary must not receive a media file',
      );
    });

    test('their media resource is not found', () async {
      await diaries.insertADiary(
        makeDiary(
          'bin',
          'hidden body',
          show: false,
          media: [imageNode('image-abc.png')],
        ),
      );
      writeMedia('image', 'image-abc.png', pngBytes);

      final response = await call('resources/read', {
        'uri': 'moodiary://diary/bin/media/image-abc.png',
      });
      expect(errorCode(response), JsonRpcCode.resourceNotFound);
    });
  });

  group('media resource', () {
    test('serves the bytes as a blob with the sniffed mime type', () async {
      writeMedia('image', 'image-abc.png', pngBytes);
      await diaries.insertADiary(
        makeDiary('diary-1', 'body', media: [imageNode('image-abc.png')]),
      );

      final response = await call('resources/read', {
        'uri': 'moodiary://diary/diary-1/media/image-abc.png',
      });
      final content = resourceContent(response);
      expect(content['uri'], 'moodiary://diary/diary-1/media/image-abc.png');
      expect(content['mimeType'], 'image/png');
      expect(base64Decode(content['blob'] as String), pngBytes);
    });

    test('serves a non-image media file too', () async {
      writeMedia('video', 'video-abc.mp4', const [0, 0, 0, 24]);
      await diaries.insertADiary(
        makeDiary(
          'diary-1',
          'body',
          media: [
            {
              'type': 'video',
              'attrs': {'src': 'video-abc.mp4'},
            },
          ],
        ),
      );
      final response = await call('resources/read', {
        'uri': 'moodiary://diary/diary-1/media/video-abc.mp4',
      });
      final content = resourceContent(response);
      expect(content['mimeType'], 'video/mp4');
      expect(base64Decode(content['blob'] as String), [0, 0, 0, 24]);
    });

    test(
      'unknown diaries and unreferenced names are resource not found',
      () async {
        await diaries.insertADiary(makeDiary('diary-1', 'body'));
        for (final uri in [
          'moodiary://diary/missing/media/image-abc.png',
          'moodiary://diary/diary-1/media/image-abc.png',
          'moodiary://diary/diary-1/media/..%2F..%2Fetc%2Fpasswd',
          'moodiary://diary/diary-1/media/%2Fetc%2Fpasswd',
        ]) {
          final response = await call('resources/read', {'uri': uri});
          expect(
            errorCode(response),
            JsonRpcCode.resourceNotFound,
            reason: '$uri must not resolve',
          );
        }
      },
    );

    test(
      'a referenced file missing from the device is resource not found',
      () async {
        await diaries.insertADiary(
          makeDiary('diary-1', 'body', media: [imageNode('image-gone.png')]),
        );
        final response = await call('resources/read', {
          'uri': 'moodiary://diary/diary-1/media/image-gone.png',
        });
        expect(errorCode(response), JsonRpcCode.resourceNotFound);
      },
    );
  });
}
