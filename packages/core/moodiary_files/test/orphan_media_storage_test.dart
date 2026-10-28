import 'dart:io';

import 'package:fast_image/fast_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_platform/moodiary_platform.dart';

void main() {
  test(
    'orphan estimate includes derivatives and deletion preserves live images',
    () async {
      final root = Directory.systemTemp.createTempSync('orphan-storage-');
      addTearDown(() => root.deleteSync(recursive: true));
      PlatformService.get().applicationSupportPath = root.path;
      FastImageRuntime.configure(
        imageDir: '${root.path}/image',
        thumbDir: '${root.path}/image/thumb',
      );
      void write(String name, int bytes) {
        final file = File('${root.path}/image/$name');
        file.parent.createSync(recursive: true);
        file.writeAsBytesSync(List.filled(bytes, 0));
      }

      write('orphan.jpg', 3);
      write('thumb/orphan_512.jpg', 2);
      write('live.jpg', 7);
      write('thumb/live_512.jpg', 5);
      final result =
          await StorageScanner(
                supportPath: root.path,
                cachePath: '${root.path}/cache',
              )
              .scan(
                StorageScanInput(
                  referencedMedia: (
                    images: {'live.jpg'},
                    audios: {},
                    videos: {},
                    files: {},
                  ),
                ),
              )
              .last;
      final candidates = result.candidates[StorageCleanupKind.unusedMedia]!;
      expect(candidates.bytes, 5);
      expect(candidates.files, hasLength(2));
      for (final candidate in candidates.files) {
        await AppFiles.deleteFile(candidate.path);
      }
      expect(File('${root.path}/image/orphan.jpg').existsSync(), isFalse);
      expect(
        File('${root.path}/image/thumb/orphan_512.jpg').existsSync(),
        isFalse,
      );
      expect(File('${root.path}/image/live.jpg').existsSync(), isTrue);
      expect(
        File('${root.path}/image/thumb/live_512.jpg').existsSync(),
        isTrue,
      );
    },
  );
}
