import 'package:fast_image/fast_image.dart';
import 'package:path/path.dart' as p;

import 'app_files.dart';
import 'media_type.dart';

/// Protects media written by this process, including unsaved compositions.
///
/// Holds last for the process lifetime: there is deliberately no release. Files
/// become eligible for unused-media cleanup after the next launch. Reserve the
/// name before starting a write, so cleanup also protects in-flight writes.
/// Read this registry on the main isolate; pass [snapshot] to worker isolates.
class MediaHolds {
  MediaHolds._();

  static final _names = <MediaType, Set<String>>{};
  static final _imageStems = <String>{};

  static void add(MediaType type, String name) {
    final names = _names.putIfAbsent(type, () => <String>{})..add(name);
    if (type == .image) _imageStems.add(p.basenameWithoutExtension(name));
    if (type == .video) {
      if (AppFiles.thumbnailNameOf(name) case final thumb?) names.add(thumb);
    }
  }

  /// Includes derivatives of held images and thumbnails of held videos.
  static bool contains(MediaType type, String name) =>
      (_names[type]?.contains(name) ?? false) ||
      (type == .image &&
          _imageStems.contains(FastImageDerivatives.sourceStem(name)));

  static Map<MediaType, Set<String>> snapshot() => {
    for (final entry in _names.entries) entry.key: Set.of(entry.value),
  };
}
