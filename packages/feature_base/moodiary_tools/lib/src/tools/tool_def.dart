import 'dart:typed_data';

import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:moodiary_data/moodiary_data.dart';

import '../media/diary_media.dart';

enum ToolSurface { assistant, mcp }

enum ToolEffect { read, write, destructive }

class ToolArgumentException implements Exception {
  const ToolArgumentException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ToolFailure implements Exception {
  const ToolFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class DiaryRef {
  const DiaryRef(this.id);
  final String id;
}

class ToolMedia {
  const ToolMedia({required this.bytes, required this.mimeType});
  final Uint8List bytes;
  final String mimeType;
}

class ToolResult {
  const ToolResult(this.data, {this.media = const [], this.diaries = const []});
  final Map<String, Object?> data;
  final List<ToolMedia> media;
  final List<DiaryRef> diaries;
}

typedef ToolProgress = void Function(
  num progress, {
  num? total,
  String? message,
});

class ToolContext {
  ToolContext({
    required this.diaries,
    required this.categories,
    required this.insights,
    required this.surface,
    DiaryMediaStore? mediaStore,
    this.progress,
    this.semantic,
  }) : mediaStore = mediaStore ?? DiaryMediaStore();

  final DiaryRepository diaries;
  final CategoryRepository categories;
  final MoodInsightsRepository insights;
  final DiaryMediaStore mediaStore;
  final ToolSurface surface;
  final ToolProgress? progress;
  final EmbedIndexService? semantic;
}

abstract interface class ToolDefinition {
  String get name;
  String get title;
  Set<ToolSurface> get surfaces;
  ToolEffect get effect;
  bool get idempotent;
  bool get openWorld;
  String Function(ToolSurface) get description;
  Schema Function(ToolSurface) get input;
  Schema get output;
  Future<ToolResult> call(Map<String, Object?> raw, ToolContext ctx);
}

class ToolDef<I, O> implements ToolDefinition {
  const ToolDef({
    required this.name,
    required this.title,
    required this.surfaces,
    required this.effect,
    required this.idempotent,
    this.openWorld = false,
    required this.description,
    required this.input,
    required this.output,
    required this.parse,
    required this.run,
    required this.toJson,
    this.media,
    this.references,
    this.validateArguments,
  });

  @override
  final String name;
  @override
  final String title;
  @override
  final Set<ToolSurface> surfaces;
  @override
  final ToolEffect effect;
  @override
  final bool idempotent;
  @override
  final bool openWorld;
  @override
  final String Function(ToolSurface) description;
  @override
  final Schema Function(ToolSurface) input;
  @override
  final Schema output;
  final I Function(Map<String, Object?>) parse;
  final Future<O> Function(I, ToolContext) run;
  final Map<String, Object?> Function(O) toJson;
  final List<ToolMedia> Function(O)? media;

  final List<DiaryRef> Function(O)? references;
  final Future<List<ValidationError>> Function(Map<String, Object?>, Schema)?
  validateArguments;

  @override
  Future<ToolResult> call(Map<String, Object?> raw, ToolContext ctx) async {
    final schema = input(ctx.surface);
    final errors =
        await (validateArguments?.call(raw, schema) ?? schema.validate(raw));
    if (errors.isNotEmpty) {
      throw ToolArgumentException(
        '$name: ${errors.map((error) => '${error.path.join('.')}: ${error.details ?? error.error.name}').join('; ')}',
      );
    }
    final result = await run(parse(raw), ctx);
    final data = toJson(result);
    return ToolResult(
      data,
      media: media?.call(result) ?? const [],
      diaries: references?.call(result) ?? const [],
    );
  }
}
