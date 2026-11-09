/// Transport free contract of the app's native "export as long image" renderer.
///
/// `moodiary_mcp` is a feature package and may not import `moodiary_export`,
/// which is another feature package. The renderer is therefore declared here
/// in plain primitives, implemented by the app composition root (the only
/// layer allowed to see both packages) and installed on
/// `McpService.imageRenderer`. Tests replace it with a fake.
///
/// Rendering is transient by design: it never writes into the diary database,
/// the media directories or the gallery, and the PNG lives only in memory.
library;

import 'package:flutter/foundation.dart';
import 'package:moodiary_models/moodiary_models.dart';

/// Colour scheme an implementation has to draw the card with.
///
/// The tool's `theme=system` maps to `null` in [DiaryImageOptions.brightness]
/// instead of an enum value: only the composition root knows whether the app is
/// currently light or dark, so the adapter resolves that case itself.
enum DiaryImageBrightness { light, dark }

/// Rendering knobs of one long-image export.
///
/// The tool clamps every value into the range its schema documents before it
/// builds the options, so an implementation may treat them as valid; it still
/// has to be defensive about the composer's own limits.
@immutable
class DiaryImageOptions {
  const DiaryImageOptions({
    this.brightness,
    this.widthDp = 360,
    this.scale = 3,
    this.watermark = true,
    this.includeTitle = true,
    this.includeMeta = true,
  });

  /// Card colour scheme, or `null` to follow the current app theme.
  final DiaryImageBrightness? brightness;

  /// Logical card width in dp. The PNG is [widthDp] * [scale] pixels wide.
  final double widthDp;

  /// Pixel density from 1 to 3. The composer lowers it on its own when the
  /// content would exceed its texture limits, so the finished width can be
  /// smaller than `widthDp * scale`.
  final int scale;

  /// Whether the card carries the Moodiary brand mark.
  final bool watermark;

  /// Whether the diary title is part of the card.
  final bool includeTitle;

  /// Whether the time, mood, weather, place, tags and category line is part of
  /// the card.
  final bool includeMeta;
}

/// One finished render: the PNG bytes plus the geometry the composer settled
/// on.
@immutable
class DiaryImageRenderResult {
  const DiaryImageRenderResult({
    required this.pngBytes,
    required this.widthPx,
    required this.heightPx,
    this.skippedImages = 0,
  });

  /// Encoded PNG, ready to be returned as an MCP `image` content item.
  final Uint8List pngBytes;

  /// Width of the PNG in pixels; it reflects the effective scale, which the
  /// composer may have lowered for very tall cards.
  final int widthPx;

  /// Height of the PNG in pixels.
  final int heightPx;

  /// Inline images the composer could not decode and left out of the card.
  final int skippedImages;
}

/// Why a [DiaryImageRenderer.render] call failed.
enum DiaryImageRenderFailure {
  /// The client cancelled the request while the composer was working.
  cancelled,

  /// This build or platform cannot rasterise the card at all, e.g. an adapter
  /// whose native image runtime is missing. The tool answers with a clear
  /// "unavailable in this build" error for it.
  unavailable,

  /// The composer failed for any other reason.
  failed,
}

/// Failure reported by [DiaryImageRenderer.render].
///
/// [message] is diagnostic detail only; the tool composes its own English
/// message so a model always gets actionable text.
class DiaryImageRenderException implements Exception {
  const DiaryImageRenderException(this.failure, [this.message]);

  final DiaryImageRenderFailure failure;

  /// Underlying error text, if the renderer has one.
  final String? message;

  @override
  String toString() => switch (message) {
    final message? => 'DiaryImageRenderException(${failure.name}: $message)',
    null => 'DiaryImageRenderException(${failure.name})',
  };
}

/// Renders one diary as the PNG the app's "export as long image" page shows.
abstract interface class DiaryImageRenderer {
  /// Composes [diary] with [options] and returns the PNG in memory.
  ///
  /// [onProgress] receives the number of finished bands and the band total,
  /// which the tool forwards as `notifications/progress`. [isCancelled] is
  /// polled while composing; once it returns `true` the call throws
  /// [DiaryImageRenderException] with [DiaryImageRenderFailure.cancelled]
  /// instead of returning a partial image.
  ///
  /// The implementation must not write anything that outlives the call: the
  /// temporary file the composer needs is deleted before this future
  /// completes.
  Future<DiaryImageRenderResult> render({
    required Diary diary,
    required DiaryImageOptions options,
    void Function(int band, int total)? onProgress,
    bool Function()? isCancelled,
  });
}
