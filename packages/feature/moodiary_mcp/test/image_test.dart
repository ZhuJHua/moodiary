import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_mcp/src/export/diary_image_renderer.dart';
import 'package:moodiary_mcp/src/protocol/json_rpc.dart';
import 'package:moodiary_mcp/src/registry/mcp_registry.dart';
import 'package:moodiary_mcp/src/server/mcp_server.dart';
import 'package:moodiary_mcp/src/server/mcp_session.dart';
import 'package:moodiary_mcp/src/tools/image_tools.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_storage/testing.dart';

import 'support.dart';

/// Fixed 32 byte payload: the tool must forward exactly the bytes it gets.
final Uint8List _pngBytes = Uint8List.fromList(
  List<int>.generate(32, (i) => i),
);

class _FakeRenderer implements DiaryImageRenderer {
  _FakeRenderer({
    Uint8List? pngBytes,
    this.widthPx = 1080,
    this.heightPx = 2400,
    this.skippedImages = 2,
    this.failure,
  }) : pngBytes = pngBytes ?? _pngBytes;

  final Uint8List pngBytes;
  final int widthPx;
  final int heightPx;
  final int skippedImages;
  final DiaryImageRenderException? failure;

  int calls = 0;
  Diary? seenDiary;
  DiaryImageOptions? seenOptions;

  @override
  Future<DiaryImageRenderResult> render({
    required Diary diary,
    required DiaryImageOptions options,
    void Function(int band, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    calls++;
    seenDiary = diary;
    seenOptions = options;
    if (failure case final failure?) throw failure;
    onProgress?.call(1, 3);
    onProgress?.call(2, 3);
    onProgress?.call(3, 3);
    return DiaryImageRenderResult(
      pngBytes: pngBytes,
      widthPx: widthPx,
      heightPx: heightPx,
      skippedImages: skippedImages,
    );
  }
}

void main() {
  late MoodiaryDatabase db;
  late DiaryRepository diaries;
  late McpServer server;
  late McpSessionState session;
  late TestMcpClient client;

  setUpAll(() {
    if (!getIt.isRegistered<IKVStorage>()) {
      getIt.registerSingleton<IKVStorage>(MemoryKVStorage());
    }
  });

  setUp(() async {
    db = MoodiaryDatabase.forTesting(
      NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA foreign_keys = ON'),
      ),
    );
    diaries = DiaryRepository(db);
    await diaries.insertADiary(makeDiary('diary-1', 'a day worth exporting'));
  });

  tearDown(() async {
    server.dispose();
    await db.close();
  });

  /// Builds a server whose catalog holds only the image tool, so the test does
  /// not depend on the rest of the catalog the Lead wires in.
  void buildServer(DiaryImageRenderer? renderer) {
    final registry = McpRegistry();
    registerImageTools(registry, diaries: diaries, renderer: renderer);
    server = McpServer(registry: registry, serverVersion: 'test');
    session = server.createSession();
    client = TestMcpClient(server: server, session: session);
  }

  Future<Map<String, dynamic>> call(
    String method, [
    Map<String, dynamic> params = const {},
  ]) => client.call(method, params);

  Future<Map<String, dynamic>> toolCall([
    Map<String, dynamic> arguments = const {},
  ]) => client.toolCall('render_diary_image', arguments);

  test('catalog advertises a read-only, non-idempotent image tool', () async {
    buildServer(_FakeRenderer());
    final listed = (await call('tools/list'))['result'] as Map;
    final tool = (listed['tools'] as List).cast<Map<String, dynamic>>().single;
    expect(tool['name'], 'render_diary_image');
    expect((tool['description'] as String).trim(), isNotEmpty);
    expect(tool['annotations'], {
      'readOnlyHint': true,
      'destructiveHint': false,
      'idempotentHint': false,
      'openWorldHint': false,
    });

    final schema = tool['inputSchema'] as Map<String, dynamic>;
    expect(schema['type'], 'object');
    expect(schema['required'], ['id']);
    final properties = schema['properties'] as Map<String, dynamic>;
    expect(properties['theme'], containsPair('default', 'system'));
    expect((properties['theme'] as Map)['enum'], ['light', 'dark', 'system']);
    expect(properties['width'], containsPair('default', 360));
    expect(properties['scale'], containsPair('default', 3));
    expect(properties['watermark'], containsPair('default', true));
    expect(properties['includeTitle'], containsPair('default', true));
    expect(properties['includeMeta'], containsPair('default', true));
  });

  group('successful render', () {
    test('returns image content plus structured metadata', () async {
      final renderer = _FakeRenderer();
      buildServer(renderer);

      final response = await toolCall({'id': 'diary-1'});
      expect(resultOf(response)['isError'], isFalse);

      final content = contentOf(response);
      expect(content, hasLength(2));
      expect(content.first['type'], 'image');
      expect(content.first['mimeType'], 'image/png');
      expect(base64Decode(content.first['data'] as String), renderer.pngBytes);

      final metadata = structuredOf(response);
      expect(metadata, {
        'id': 'diary-1',
        'mimeType': 'image/png',
        'widthPx': 1080,
        'heightPx': 2400,
        'bytes': renderer.pngBytes.length,
        'scale': 3,
        'widthDp': 360,
        'skippedImages': 2,
      });
      expect(content.last, {'type': 'text', 'text': jsonEncode(metadata)});

      expect(renderer.calls, 1);
      expect(renderer.seenDiary?.id, 'diary-1');
      final options = renderer.seenOptions!;
      expect(options.brightness, isNull);
      expect(options.widthDp, 360);
      expect(options.scale, 3);
      expect(options.watermark, isTrue);
      expect(options.includeTitle, isTrue);
      expect(options.includeMeta, isTrue);
    });

    test('forwards theme and layout arguments to the renderer', () async {
      final renderer = _FakeRenderer();
      buildServer(renderer);

      await toolCall({
        'id': 'diary-1',
        'theme': 'light',
        'width': 480,
        'scale': 2,
        'watermark': false,
        'includeTitle': false,
        'includeMeta': false,
      });
      var options = renderer.seenOptions!;
      expect(options.brightness, DiaryImageBrightness.light);
      expect(options.widthDp, 480);
      expect(options.scale, 2);
      expect(options.watermark, isFalse);
      expect(options.includeTitle, isFalse);
      expect(options.includeMeta, isFalse);

      await toolCall({'id': 'diary-1', 'theme': 'dark'});
      options = renderer.seenOptions!;
      expect(options.brightness, DiaryImageBrightness.dark);

      await toolCall({'id': 'diary-1', 'theme': 'system'});
      options = renderer.seenOptions!;
      expect(options.brightness, isNull);
    });

    test('reports the effective scale when the composer lowers it', () async {
      buildServer(
        _FakeRenderer(widthPx: 720, heightPx: 1440, skippedImages: 0),
      );

      final response = await toolCall({
        'id': 'diary-1',
        'width': 720,
        'scale': 3,
      });
      final metadata = structuredOf(response);
      expect(metadata['widthDp'], 720);
      expect(metadata['scale'], 1);
      expect(metadata['skippedImages'], 0);
    });

    test('clamps width and scale like other count arguments', () async {
      final renderer = _FakeRenderer();
      buildServer(renderer);

      await toolCall({'id': 'diary-1', 'width': 10, 'scale': 99});
      expect(renderer.seenOptions!.widthDp, 240);
      expect(renderer.seenOptions!.scale, 3);

      await toolCall({'id': 'diary-1', 'width': 5000, 'scale': 0});
      expect(renderer.seenOptions!.widthDp, 720);
      expect(renderer.seenOptions!.scale, 1);
    });
  });

  group('failures', () {
    test('unknown diary id is a tool error and skips rendering', () async {
      final renderer = _FakeRenderer();
      buildServer(renderer);

      final response = await toolCall({'id': 'missing'});
      expect(resultOf(response)['isError'], isTrue);
      expect(
        contentOf(response).single['text'],
        contains('no diary with id="missing"'),
      );
      expect(renderer.calls, 0);
    });

    test('a missing renderer reports the feature as unavailable', () async {
      buildServer(null);

      final response = await toolCall({'id': 'diary-1'});
      expect(resultOf(response)['isError'], isTrue);
      expect(
        contentOf(response).single['text'],
        contains('unavailable in this build'),
      );
    });

    test('a renderer side cancellation answers with the MCP code', () async {
      buildServer(
        _FakeRenderer(
          failure: const DiaryImageRenderException(
            DiaryImageRenderFailure.cancelled,
          ),
        ),
      );

      final response = await toolCall({'id': 'diary-1'});
      expect(response['error'], isNotNull);
      expect(
        (response['error'] as Map<String, dynamic>)['code'],
        JsonRpcCode.requestCancelled,
      );
    });

    test('an unavailable renderer surfaces its diagnostic', () async {
      buildServer(
        _FakeRenderer(
          failure: const DiaryImageRenderException(
            DiaryImageRenderFailure.unavailable,
            'fast_image is not loaded',
          ),
        ),
      );

      final response = await toolCall({'id': 'diary-1'});
      expect(resultOf(response)['isError'], isTrue);
      final text = contentOf(response).single['text'] as String;
      expect(text, contains('unavailable in this build'));
      expect(text, contains('fast_image is not loaded'));
    });

    test('a failed render explains how to retry smaller', () async {
      buildServer(
        _FakeRenderer(
          failure: const DiaryImageRenderException(
            DiaryImageRenderFailure.failed,
            'no implicit view',
          ),
        ),
      );

      final response = await toolCall({'id': 'diary-1', 'width': 480});
      expect(resultOf(response)['isError'], isTrue);
      final text = contentOf(response).single['text'] as String;
      expect(text, contains('rendering failed'));
      expect(text, contains('no implicit view'));
      expect(text, contains('smaller width or scale'));
    });

    test('a PNG above the response limit is refused, not truncated', () async {
      const limit = 8 * 1024 * 1024;
      buildServer(_FakeRenderer(pngBytes: Uint8List(limit + 1)));

      final response = await toolCall({'id': 'diary-1'});
      expect(resultOf(response)['isError'], isTrue);
      final text = contentOf(response).single['text'] as String;
      expect(text, contains('response limit'));
      expect(text, contains('Lower scale'));
      expect(text, contains('width'));
    });

    test('a recycled diary is not rendered', () async {
      final renderer = _FakeRenderer();
      buildServer(renderer);
      await diaries.insertADiary(makeDiary('bin', 'hidden body', show: false));

      final response = await toolCall({'id': 'bin'});
      expect(resultOf(response)['isError'], isTrue);
      expect(
        contentOf(response).single['text'],
        contains('no diary with id="bin"'),
      );
      expect(renderer.calls, 0);
    });

    test('an invalid theme is invalid params', () async {
      buildServer(_FakeRenderer());
      final response = await toolCall({'id': 'diary-1', 'theme': 'sepia'});
      expect(
        (response['error'] as Map<String, dynamic>)['code'],
        JsonRpcCode.invalidParams,
      );
    });
  });
}
