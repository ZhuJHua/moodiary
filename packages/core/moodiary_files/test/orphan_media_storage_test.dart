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
      final report = await AppFiles.scanOrphanMedia(
        usedImages: {'live.jpg'},
        usedAudios: {},
        usedVideos: {},
        usedFiles: {},
      );
      expect(report.bytes, 5);
      expect(report.paths.length, 2);
      await AppFiles.deleteOrphanMedia(report);
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
