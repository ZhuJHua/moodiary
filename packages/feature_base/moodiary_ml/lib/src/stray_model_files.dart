import 'dart:io';
import 'dart:isolate';

import 'package:moodiary_files/moodiary_files.dart';

import 'embedding_models.dart';

/// Semantic names are localized by the app, never stored in the filesystem layer.
enum StrayModelKind { retiredMood, unused, partial }

class StrayModelFile {
  final String path;
  final int bytes;
  final StrayModelKind kind;
  const StrayModelFile({
    required this.path,
    required this.bytes,
    required this.kind,
  });
}

const _retiredModels = {'qwen3-0.6b-int8': StrayModelKind.retiredMood};

/// Add future live catalogs here, so detection always uses a whitelist.
Set<String> _liveModelFiles() => {
  for (final model in embeddingModelCatalog) ...[
    model.modelFileName,
    model.tokenizerFileName,
  ],
};

Future<List<StrayModelFile>> strayModelFiles({String? modelPath}) {
  final path = modelPath ?? AppFiles.getRealPath('model', '');
  final live = _liveModelFiles();
  return Isolate.run(() {
    final directory = Directory(path);
    if (!directory.existsSync()) return <StrayModelFile>[];
    final result = <StrayModelFile>[];
    for (final entity in directory.listSync(followLinks: false)) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (live.contains(name)) continue;
      var kind = StrayModelKind.unused;
      if (name.endsWith('.part')) {
        kind = .partial;
      } else {
        for (final entry in _retiredModels.entries) {
          if (name == entry.key || name.startsWith('${entry.key}.'))
            kind = entry.value;
        }
      }
      try {
        result.add(
          StrayModelFile(
            path: entity.path,
            bytes: entity.lengthSync(),
            kind: kind,
          ),
        );
      } on PathNotFoundException {
        // A download may finish between listing and stat.
      }
    }
    return result;
  });
}
