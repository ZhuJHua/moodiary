/// Fixtures and JSON-RPC response readers shared by the MCP tool tests.
///
/// Every tool test drives the same server over the same in-memory database, so
/// the diary fixture and the envelope readers live here once instead of being
/// pasted into each test file; a file only adds the helpers its own tools need.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_mcp/src/server/mcp_server.dart';
import 'package:moodiary_mcp/src/server/mcp_session.dart';
import 'package:moodiary_models/moodiary_models.dart';

/// One diary with a valid Tiptap body, plus the media lists the write path
/// derives from it.
///
/// [content] replaces the generated document verbatim (a legacy diary or a rich
/// document fixture); [media] appends Tiptap media nodes to the generated one;
/// [linkTo] adds a `diaryLink` node per id after the paragraph text. Everything
/// is passed through [withDerivedMedia], which is the same projection the write
/// path applies.
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
}) {
  final doc =
      content ??
      (type == 'tiptap'
          ? jsonEncode({
              'type': 'doc',
              'attrs': {'v': 2},
              'content': [
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
              ],
            })
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
      mood: null,
      imageName: const [],
      audioName: const [],
      videoName: const [],
      tags: tags,
      type: type,
    ),
  );
}

/// A JSON-RPC client over one in-memory server session.
///
/// The sequence number is per client, so request ids stay unique inside a test
/// without every file carrying its own counter.
class TestMcpClient {
  TestMcpClient({required this.server, required this.session});

  final McpServer server;
  final McpSessionState session;

  var _seq = 0;

  Future<Map<String, dynamic>> call(
    String method, [
    Map<String, dynamic> params = const {},
  ]) async {
    final response = await server.handle(session, {
      'jsonrpc': '2.0',
      'id': ++_seq,
      'method': method,
      'params': params,
    });
    expect(response, isNotNull, reason: '$method must answer a request');
    return response!;
  }

  Future<Map<String, dynamic>> toolCall(
    String name, [
    Map<String, dynamic> arguments = const {},
  ]) => call('tools/call', {'name': name, 'arguments': arguments});

  /// Creates one category through the tool and returns its id.
  Future<String> newCategory(
    String name, {
    String? parentId,
    Object? color,
  }) async {
    final created = structuredOf(
      await toolCall('create_category', {
        'name': name,
        'parentId': ?parentId,
        'color': ?color,
      }),
    );
    expect(created['created'], isTrue);
    return (created['category'] as Map<String, dynamic>)['id'] as String;
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

String resourceText(Map<String, dynamic> response) {
  final contents = resultOf(response)['contents'] as List;
  return (contents.single as Map)['text'] as String;
}

Map<String, dynamic> resourceJson(Map<String, dynamic> response) =>
    jsonDecode(resourceText(response)) as Map<String, dynamic>;

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
