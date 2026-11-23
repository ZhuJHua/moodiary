library;

import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_mcp/src/transport/mcp_http_endpoint.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

MoodiaryDatabase openTestDatabase() => MoodiaryDatabase.forTesting(
  NativeDatabase.memory(
    setup: (raw) => raw.execute('PRAGMA foreign_keys = ON'),
  ),
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

class TestMcpClient {
  TestMcpClient({required this.server});

  final McpServer server;
  final sdk = McpClient(
    const Implementation(name: 'test', version: '1'),
    options: const McpClientOptions(
      protocol: McpProtocol.legacy,
      protocolVersion: '2025-06-18',
    ),
  );
  Future<void>? _ready;

  Future<void> connect() => _ready ??= _connect();

  Future<void> _connect() async {
    final toServer = StreamController<List<int>>();
    final toClient = StreamController<List<int>>();
    await server.connect(
      IOStreamTransport(
        stream: toServer.stream,
        sink: toClient.sink,
        maxIncomingMessageBytes: McpHttpEndpoint.maxIncomingMessageBytes,
      ),
    );
    await sdk.connect(
      IOStreamTransport(
        stream: toClient.stream,
        sink: toServer.sink,
        maxIncomingMessageBytes: McpHttpEndpoint.maxIncomingMessageBytes,
      ),
    );
  }

  Future<void> close() async {
    await sdk.close();
    await server.close();
  }

  Future<Map<String, dynamic>> call(
    String method, [
    Map<String, dynamic> params = const {},
  ]) async {
    await connect();
    try {
      final result = await sdk.request(
        JsonRpcRequest(id: 0, method: method, params: params),
        _TestResult.new,
      );
      return {'result': result.toJson()};
    } on McpError catch (error) {
      return {
        'error': {'code': error.code, 'message': error.message},
      };
    }
  }

  Future<Map<String, dynamic>> toolCall(
    String name, [
    Map<String, dynamic> arguments = const {},
  ]) => call('tools/call', {'name': name, 'arguments': arguments});
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

List<String> completionValues(Map<String, dynamic> response) {
  final completion = resultOf(response)['completion'] as Map;
  return (completion['values'] as List).cast<String>();
}

List<String> diaryIds(Map<String, dynamic> data) => [
  for (final diary in data['hits'] as List)
    (diary as Map<String, dynamic>)['id'] as String,
];

Map<String, dynamic> toolNamed(Map<String, dynamic> listed, String name) =>
    (listed['tools'] as List).cast<Map<String, dynamic>>().firstWhere(
      (tool) => tool['name'] == name,
    );

Map<String, dynamic> propertiesOf(Map<String, dynamic> tool) =>
    (tool['inputSchema'] as Map<String, dynamic>)['properties']
        as Map<String, dynamic>;

class _TestResult implements BaseResultData {
  _TestResult(this.value);
  final Map<String, dynamic> value;
  @override
  Map<String, dynamic>? get meta => value['_meta'] as Map<String, dynamic>?;
  @override
  Map<String, dynamic> toJson() => value;
}
