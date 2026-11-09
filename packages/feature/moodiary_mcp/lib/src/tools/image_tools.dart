/// Long-image tool: renders one diary as the PNG the app's "export as long
/// image" page produces.
///
/// The tool returns the picture as an MCP `image` content item plus a small
/// JSON summary, and never writes into the gallery, the media directories or
/// the diary itself: the PNG is a transient payload of this call.
library;

import 'dart:convert';

import 'package:moodiary_data/moodiary_data.dart';

import '../export/diary_image_renderer.dart';
import '../protocol/json_rpc.dart';
import '../protocol/mcp_types.dart';
import '../registry/mcp_registry.dart';
import 'arguments.dart';
import 'schemas.dart';

/// Values of the `theme` argument.
const List<String> _themes = ['light', 'dark', 'system'];

/// The response cap for the inline PNG. Base64 grows the payload by a third,
/// and some clients keep tool results in their model context, so an 8 MB image
/// already costs roughly 10.7 MB of wire text.
const int _maxPngBytes = 8 * 1024 * 1024;

/// Registers the long-image tool.
///
/// [renderer] is `null` when the composition root did not install one, e.g. in
/// a test or a build without the export package; the tool then answers with a
/// readable error instead of disappearing from the catalog.
void registerImageTools(
  McpRegistry registry, {
  required DiaryRepository diaries,
  required DiaryImageRenderer? renderer,
}) {
  registry.addTool(
    const McpTool(
      name: 'render_diary_image',
      title: 'Render a diary as a long image',
      description:
          'Renders one diary as the same long PNG the app shares through '
          '"export as long image", and returns it as an MCP image content item '
          '(base64, image/png) followed by a JSON summary. Nothing is written '
          'to the diary, the gallery or the media directories. '
          'theme=system (default) follows the app theme; light and dark force '
          'one. width is the logical card width in dp and scale the pixel '
          'density; the effective scale can be lower than requested when the '
          'card would exceed the renderer texture limit, and the summary '
          'reports it. watermark adds the Moodiary mark, includeTitle and '
          'includeMeta drop the title or the metadata line. Images larger than '
          '8 MB are refused: lower scale or width instead of truncating the '
          'picture. An unknown diary id is a tool error.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'id': diaryIdSchema,
          'theme': {
            'type': 'string',
            'enum': _themes,
            'default': 'system',
            'description':
                'Card colour scheme. system (default) follows the app theme: '
                'its light/dark setting, or the platform brightness while the '
                'app follows the system.',
          },
          'width': {
            'type': 'integer',
            'minimum': 240,
            'maximum': 720,
            'default': 360,
            'description': 'Logical card width in dp, capped into 240..720.',
          },
          'scale': {
            'type': 'integer',
            'minimum': 1,
            'maximum': 3,
            'default': 3,
            'description':
                'Pixel density, capped into 1..3. The PNG is width * scale '
                'pixels wide unless the renderer lowers the scale for a very '
                'tall card.',
          },
          'watermark': {
            'type': 'boolean',
            'default': true,
            'description': 'Whether the card carries the Moodiary brand mark.',
          },
          'includeTitle': {
            'type': 'boolean',
            'default': true,
            'description': 'Whether the diary title is drawn on the card.',
          },
          'includeMeta': {
            'type': 'boolean',
            'default': true,
            'description':
                'Whether the time, mood, weather, place, tags and category '
                'line is drawn on the card.',
          },
        },
        'required': ['id'],
      },
      readOnly: true,
      // Rendering mutates nothing, but theme=system depends on the current app
      // theme, so equal arguments can produce different bytes: a client cannot
      // cache the call as if it were idempotent.
      idempotent: false,
    ),
    (call, arguments) => _renderDiaryImage(
      call,
      arguments,
      diaries: diaries,
      renderer: renderer,
    ),
  );
}

Future<McpToolResult> _renderDiaryImage(
  McpCallContext call,
  Map<String, dynamic> arguments, {
  required DiaryRepository diaries,
  required DiaryImageRenderer? renderer,
}) async {
  final args = Args('render_diary_image', arguments);
  final id = args.requireText('id');
  final brightness = _brightnessOf(
    args.optionalEnum('theme', _themes) ?? 'system',
  );
  final width = args.optionalInt('width', fallback: 360, min: 240, max: 720);
  final scale = args.optionalInt('scale', fallback: 3, min: 1, max: 3);
  final watermark = args.optionalBool('watermark') ?? true;
  final includeTitle = args.optionalBool('includeTitle') ?? true;
  final includeMeta = args.optionalBool('includeMeta') ?? true;

  final diary = await diaries.getDiaryByBusinessId(id);
  if (diary == null) {
    return McpToolResult.error('render_diary_image: no diary with id="$id".');
  }
  if (renderer == null) {
    return McpToolResult.error(
      'render_diary_image: long-image rendering is unavailable in this build, '
      'so the diary was not rendered; read it with get_diary instead.',
    );
  }

  final options = DiaryImageOptions(
    brightness: brightness,
    widthDp: width.toDouble(),
    scale: scale,
    watermark: watermark,
    includeTitle: includeTitle,
    includeMeta: includeMeta,
  );

  final DiaryImageRenderResult rendered;
  try {
    call.reportProgress(0, message: 'render_diary_image');
    rendered = await renderer.render(
      diary: diary,
      options: options,
      onProgress: (band, total) => call.reportProgress(
        band,
        total: total,
        message: 'render_diary_image',
      ),
      isCancelled: () => call.isCancelled,
    );
  } on DiaryImageRenderException catch (e) {
    switch (e.failure) {
      case .cancelled:
        throw const JsonRpcException(
          JsonRpcCode.requestCancelled,
          'render_diary_image: request cancelled by the client',
        );
      case .unavailable:
        return McpToolResult.error(
          'render_diary_image: long-image rendering is unavailable in this '
          'build${_detail(e)}; read the diary with get_diary instead.',
        );
      case .failed:
        return McpToolResult.error(
          'render_diary_image: rendering failed${_detail(e)}; try a smaller '
          'width or scale.',
        );
    }
  }

  // A client that cancels while the last band is written must still see the
  // cancellation error, which is what the server core reports for every other
  // handler too.
  if (call.isCancelled) {
    throw const JsonRpcException(
      JsonRpcCode.requestCancelled,
      'render_diary_image: request cancelled by the client',
    );
  }

  final bytes = rendered.pngBytes;
  if (bytes.length > _maxPngBytes) {
    return McpToolResult.error(
      'render_diary_image: the PNG is ${_megabytes(bytes.length)} MB, more '
      'than the ${_maxPngBytes ~/ (1024 * 1024)} MB response limit. Lower '
      'scale (currently $scale) or width (currently $width) and call again.',
    );
  }

  final effectiveScale = rendered.widthPx <= 0
      ? scale
      : (rendered.widthPx / width).round().clamp(1, 3);
  final metadata = <String, dynamic>{
    'id': diary.id,
    'mimeType': 'image/png',
    'widthPx': rendered.widthPx,
    'heightPx': rendered.heightPx,
    'bytes': bytes.length,
    'scale': effectiveScale,
    'widthDp': width,
    'skippedImages': rendered.skippedImages,
  };
  return McpToolResult(
    content: [
      McpContent.image(base64Data: base64Encode(bytes), mimeType: 'image/png'),
      McpContent.text(jsonEncode(metadata)),
    ],
    structuredContent: metadata,
  );
}

/// The card brightness a `theme` argument forces; `null` follows the app theme.
DiaryImageBrightness? _brightnessOf(String value) => switch (value) {
  'light' => DiaryImageBrightness.light,
  'dark' => DiaryImageBrightness.dark,
  _ => null,
};

/// ` (<underlying error>)` when the renderer supplied one, else nothing.
String _detail(DiaryImageRenderException e) => switch (e.message) {
  final message? => ' ($message)',
  null => '',
};

String _megabytes(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);
