import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_models/moodiary_models.dart' show Font;
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_theme/moodiary_theme.dart';
import 'package:path/path.dart' as p;

enum LegacyDatabaseState { none, pending, abandoning, probeFailed }

abstract final class LegacyDatabaseGuard {
  static const _databaseName = 'default.isar';
  static LegacyDatabaseState _state = .none;
  static String? _sourceVersion;
  static Future<void>? _activeAbandon;

  static LegacyDatabaseState get state => _state;
  static String? get sourceVersion => _sourceVersion;

  static Future<LegacyDatabaseState> probe() async {
    _sourceVersion = null;
    try {
      if (defaultTargetPlatform != TargetPlatform.android) {
        return _state = .none;
      }
      _sourceVersion = MoodiaryKVs.appVersion.get();
      if (MoodiaryKVs.legacyAbandonJournal.get()?.isNotEmpty ?? false) {
        return _state = .abandoning;
      }
      if (MoodiaryKVs.dbEngineMigrated.get() == true) return _state = .none;
      final file = File(AppFiles.getRealPath('database', _databaseName));
      try {
        return _state = await file.length() > 0 ? .pending : .none;
      } on PathNotFoundException {
        return _state = .none;
      }
    } catch (error, stack) {
      logger.e('Legacy database probe failed', error: error, stackTrace: stack);
      return _state = .probeFailed;
    }
  }

  static Future<void> abandon({
    DiaryRepository? diaries,
    FontRepository? fonts,
  }) => _activeAbandon ??= _abandon(
    diaries,
    fonts,
  ).whenComplete(() => _activeAbandon = null);

  static Future<void> _abandon(
    DiaryRepository? diaries,
    FontRepository? fontRepository,
  ) async {
    switch (await probe()) {
      case .none:
        return;
      case .probeFailed:
        throw StateError('Cannot determine the legacy database state');
      case .pending:
      case .abandoning:
        break;
    }

    final root = AppFiles.getRealPath(legacyAbandonedDirName, '');
    final journal = MoodiaryKVs.legacyAbandonJournal.get();
    late final String destination;
    if (journal == null || journal.isEmpty) {
      final stamp = DateTime.now()
          .toIso8601String()
          .split('.')
          .first
          .replaceAll(RegExp('[-:]'), '')
          .replaceFirst('T', '-');
      destination = p.join(root, stamp);
      if (await FileSystemEntity.type(destination) !=
          FileSystemEntityType.notFound) {
        throw FileSystemException(
          'Quarantine directory already exists',
          destination,
        );
      }
      MoodiaryKVs.legacyAbandonJournal.set(destination);
      if (MoodiaryKVs.legacyAbandonJournal.get() != destination) {
        throw StateError('Could not persist legacy quarantine journal');
      }
    } else {
      destination = journal;
      if (p.dirname(destination) != root ||
          !RegExp(r'^\d{8}-\d{6}$').hasMatch(p.basename(destination))) {
        throw const FormatException('Invalid legacy quarantine destination');
      }
    }
    _state = .abandoning;
    await Directory(destination).create(recursive: true);
    final references = await (diaries ?? getIt<DiaryRepository>())
        .collectReferencedMedia();
    if (references.images.isEmpty &&
        references.audios.isEmpty &&
        references.videos.isEmpty &&
        references.files.isEmpty) {
      for (final name in const ['image', 'audio', 'video']) {
        await _move(Directory(AppFiles.getRealPath(name, '')), destination);
      }
    }
    await _move(
      File(AppFiles.getRealPath('database', _databaseName)),
      destination,
      requiredSource: true,
    );
    await _move(
      File(AppFiles.getRealPath('database', '$_databaseName.lock')),
      destination,
    );
    await AppFiles.initCreateDir();
    final fonts = fontRepository ?? getIt<FontRepository>();
    // 字体登记是尽力而为：坏字体文件会让整次扫描抛错，不能因此把放弃卡死在拦截页。
    // 文件本身留在 font/ 目录不动；SQLite 写入失败仍然抛出，保留 journal 重试。
    List<Font> diskFonts;
    try {
      diskFonts = [
        for (final file in await FontManager.scanFontFiles())
          Font(fontFileName: file.fileName, fontWghtAxisMap: file.wghtAxis),
      ];
    } catch (error, stack) {
      logger.e('Legacy font scan failed', error: error, stackTrace: stack);
      diskFonts = const [];
    }
    for (final font in diskFonts) {
      await fonts.insertFont(font);
    }
    MoodiaryKVs.dbEngineMigrated.set(true);
    MoodiaryKVs.searchIndexBackfilled.set(true);
    if (MoodiaryKVs.dbEngineMigrated.get() != true ||
        MoodiaryKVs.searchIndexBackfilled.get() != true) {
      throw StateError('Could not finalize legacy quarantine');
    }
    MoodiaryKVs.legacyAbandonJournal.remove();
    if (MoodiaryKVs.legacyAbandonJournal.get() != null) {
      throw StateError('Could not clear legacy quarantine journal');
    }
    _state = .none;
  }

  static Future<void> _move(
    FileSystemEntity source,
    String directory, {
    bool requiredSource = false,
  }) async {
    final target = p.join(directory, p.basename(source.path));
    final targetType = await FileSystemEntity.type(target, followLinks: false);
    if (targetType != FileSystemEntityType.notFound) {
      if (targetType !=
          (source is Directory
              ? FileSystemEntityType.directory
              : FileSystemEntityType.file)) {
        throw FileSystemException('Unexpected quarantine entry', target);
      }
      return;
    }
    try {
      await source.rename(target);
    } on PathNotFoundException {
      if (requiredSource) rethrow;
    }
  }
}
