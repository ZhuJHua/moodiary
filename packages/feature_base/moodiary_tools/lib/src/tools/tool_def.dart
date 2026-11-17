import 'dart:typed_data';

import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:moodiary_data/moodiary_data.dart';

import '../media/diary_media.dart';
import 'diary_payloads.dart';

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

class ToolMedia {
  const ToolMedia({required this.bytes, required this.mimeType});
  final Uint8List bytes;
  final String mimeType;
}

class ToolResult {
  const ToolResult(this.data, {this.media = const []});
  final Map<String, Object?> data;
  final List<ToolMedia> media;
}

Never toolFailure(String message) => throw ToolFailure(message);

class ToolContext {
  ToolContext({
    required this.diaries,
    required this.categories,
    required this.insights,
    required this.surface,
    this.includeLinks = false,
    DiaryMediaStore? mediaStore,
    int? bodyChars,
    this.semantic,
    DateTime Function()? now,
  }) : bodyChars =
           bodyChars ??
           (surface == ToolSurface.assistant
               ? assistantBodyChars
               : mcpResultChars),
       mediaStore = mediaStore ?? DiaryMediaStore(),
       now = now ?? DateTime.now;

  final DiaryRepository diaries;
  final CategoryRepository categories;
  final MoodInsightsRepository insights;
  final DiaryMediaStore mediaStore;
  final ToolSurface surface;
  final int bodyChars;
  final bool includeLinks;
  final EmbedIndexService? semantic;
  final DateTime Function() now;
}

class ToolDef<I> {
  ToolDef({
    required this.name,
    required this.title,
    required this.surfaces,
    required this.effect,
    ToolEffect Function(Map<String, Object?> args)? tierOf,
    required this.idempotent,
    required this.description,
    required Schema Function(ToolSurface) input,
    required this.output,
    required this.parse,
    required this.run,
  }) : tierOf = tierOf ?? ((_) => effect),
       input = _cachedInput(input);

  final String name;
  final String title;
  final Set<ToolSurface> surfaces;
  final ToolEffect effect;
  final ToolEffect Function(Map<String, Object?> args) tierOf;
  final bool idempotent;
  final String Function(ToolSurface) description;
  final Schema Function(ToolSurface) input;

  final Schema output;
  final I Function(Map<String, Object?>) parse;
  final Future<ToolResult> Function(I, ToolContext) run;

  Future<ToolResult> call(Map<String, Object?> raw, ToolContext ctx) async {
    final schema = input(ctx.surface);
    final errors = await schema.validate(raw);
    if (errors.isNotEmpty) {
      throw ToolArgumentException(
        '$name: ${errors.map((error) => '${error.path.join('.')}: ${error.details ?? error.error.name}').join('; ')}',
      );
    }
    return run(parse(raw), ctx);
  }
}

Schema Function(ToolSurface) _cachedInput(Schema Function(ToolSurface) build) {
  final schemas = <ToolSurface, Schema>{};
  return (surface) => schemas.putIfAbsent(surface, () => build(surface));
}
