/// The app's implementation of the MCP long-image renderer.
///
/// `moodiary_mcp` cannot import `moodiary_export` (feature packages never
/// import each other), so the server only knows the abstract
/// `DiaryImageRenderer`. This adapter is the composition root counterpart: it
/// maps the transport-free options onto the export package's
/// [ExportService] / [ImageCardStyle] / [ImageComposer] wiring, renders into a
/// per-call directory below the cache, reads the PNG back and deletes it.
///
/// Nothing here touches the diary database, the media directories or the
/// gallery: the returned bytes are the only product of a call.
library;

import 'dart:io';
import 'dart:ui' show Brightness, PlatformDispatcher;

import 'package:moodiary_export/moodiary_export.dart';
import 'package:moodiary_mcp/moodiary_mcp.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:moodiary_storage/moodiary_storage.dart';

/// Renders a diary through the same pipeline as the native "export as long
/// image" page, but keeps the result in memory.
class AppDiaryImageRenderer implements DiaryImageRenderer {
  const AppDiaryImageRenderer();

  @override
  Future<DiaryImageRenderResult> render({
    required Diary diary,
    required DiaryImageOptions options,
    void Function(int band, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final widthDp = options.widthDp.clamp(240.0, 720.0);
    final scale = options.scale.clamp(1, 3);
    final brightness = _resolveBrightness(options.brightness);
    final workDir = _workDir();

    try {
      // previewDocs resolves category names and places through getIt itself,
      // so the app container has to be up, which it always is by the time the
      // MCP server can be started.
      final docs = await ExportService.previewDocs([
        diary,
      ], includePosition: false);
      await workDir.create(recursive: true);
      final style = ImageCardStyle.resolve(
        brightness: brightness,
        fallback: brightness,
        widthDp: widthDp,
        watermark: options.watermark,
      );

      final ImageComposeResult composed;
      try {
        composed = await ImageComposer.composeToFile(
          docs: docs,
          // The default media policy stays at `embed`: the card shows the
          // diary images exactly like the share sheet does.
          common: ExportCommon(
            includeTitle: options.includeTitle,
            includeMeta: options.includeMeta,
          ),
          options: ImageExportOptions(
            brightness: brightness,
            widthDp: widthDp,
            scale: scale,
            watermark: options.watermark,
          ),
          style: style,
          outPath: '${workDir.path}/diary.png',
          isCancelled: isCancelled,
          onProgress: onProgress,
        );
      } catch (e) {
        // The composer's cancel marker is private to the export package, so the
        // only reliable signal is the callback the caller handed in.
        if (isCancelled?.call() ?? false) {
          throw const DiaryImageRenderException(
            DiaryImageRenderFailure.cancelled,
          );
        }
        throw DiaryImageRenderException(DiaryImageRenderFailure.failed, '$e');
      }

      return DiaryImageRenderResult(
        pngBytes: await File(composed.path).readAsBytes(),
        widthPx: composed.widthPx,
        heightPx: composed.heightPx,
        skippedImages: composed.skippedImages,
      );
    } on DiaryImageRenderException {
      rethrow;
    } catch (e) {
      // Setup failures (conversion, missing temporary directory) reach the
      // client as one readable rendering error instead of a raw exception.
      throw DiaryImageRenderException(DiaryImageRenderFailure.failed, '$e');
    } finally {
      try {
        if (workDir.existsSync()) await workDir.delete(recursive: true);
      } on FileSystemException {
        // Best effort: a leftover file in the protected export cache workspace
        // is harmless, and the next call uses a fresh directory anyway.
      }
    }
  }

  /// Per-call scratch directory under `export/`, which `AppFiles` keeps across
  /// cache clears because a share sheet may still hold its files.
  ///
  /// The path is built by hand because `mobile` does not depend on `path`;
  /// Dart's file APIs accept `/` on every platform.
  Directory _workDir() => Directory(
    '${PlatformService.get().applicationCachePath}/export/mcp/'
    '${DateTime.now().microsecondsSinceEpoch}',
  );

  /// Resolves the card scheme.
  ///
  /// `null` means the tool's `theme=system`: the app theme wins, which is the
  /// light/dark setting when one is forced and the current platform brightness
  /// while the app follows the system.
  Brightness _resolveBrightness(DiaryImageBrightness? brightness) =>
      switch (brightness) {
        DiaryImageBrightness.light => Brightness.light,
        DiaryImageBrightness.dark => Brightness.dark,
        null => switch (MoodiaryKVs.themeMode.get()) {
          1 => Brightness.light,
          2 => Brightness.dark,
          _ => PlatformDispatcher.instance.platformBrightness,
        },
      };
}
