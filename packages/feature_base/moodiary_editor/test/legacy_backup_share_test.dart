import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_editor/moodiary_editor.dart';
import 'package:moodiary_migration/moodiary_migration.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  test(
    'checks space for the actual ZIP before opening the share sheet',
    () async {
      final cache = await Directory.systemTemp.createTemp('share-backup-');
      addTearDown(() => cache.delete(recursive: true));
      final archive = await File('${cache.path}/backup.zip')
          .writeAsBytes(List.filled(101, 0));
      final sharedPaths = <String>[];
      Future<ShareResult> attempt(int available) => shareLegacyBackup(
        archive.path,
        availableBytes: () async => available,
        share: (params) async {
          sharedPaths.add(params.files!.single.path);
          return ShareResult.unavailable;
        },
      );

      await expectLater(
        attempt(106),
        throwsA(isA<LegacyExportInsufficientSpace>()),
      );
      expect(sharedPaths, isEmpty);
      expect(await attempt(107), ShareResult.unavailable);
      expect(sharedPaths, [archive.path]);
    },
  );
}
