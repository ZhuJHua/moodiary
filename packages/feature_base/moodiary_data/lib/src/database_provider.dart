import 'dart:async';

import 'package:moodiary_files/moodiary_files.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'db/database.dart';

part 'database_provider.g.dart';

@Riverpod(keepAlive: true)
Future<MoodiaryDatabase> moodiaryDatabaseAsync(Ref ref) async {
  final db = await MoodiaryDatabase.open(
    path: AppFiles.getRealPath('database', 'moodiary.db'),
    jiebaDictDir: AppFiles.getRealPath('database', 'jieba'),
  );
  if (ref.mounted) {
    ref.onDispose(() => unawaited(db.close()));
  } else {
    await db.close();
  }
  return db;
}

@Riverpod(keepAlive: true)
MoodiaryDatabase moodiaryDatabase(Ref ref) =>
    ref.watch(moodiaryDatabaseAsyncProvider).requireValue;
