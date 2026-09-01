import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_theme/moodiary_theme.dart';

import 'db/database.dart';

class FontRepository {
  FontRepository._(this._db);

  factory FontRepository.get() => _instance;

  @visibleForTesting
  FontRepository.forTesting(this._db);

  static final FontRepository _instance = ._(MoodiaryDatabase.get());

  final MoodiaryDatabase _db;

  static Font _toFont(FontRow r) => Font(
    fontFileName: r.fontFileName,
    fontWghtAxisMap: (jsonDecode(r.wghtAxisJson) as Map)
        .cast<String, dynamic>(),
  );

  Future<List<Font>> getAllFonts() async {
    final rows = await _db.select(_db.fonts).get();
    return [for (final r in rows) _toFont(r)];
  }

  Future<List<Font>> scanDiskFonts() async {
    final scanned = await FontManager.scanFontFiles();
    return [
      for (final f in scanned)
        Font(fontFileName: f.fileName, fontWghtAxisMap: f.wghtAxis),
    ];
  }

  Future<Font?> getFontByFontFamily(String fontFamily) async {
    final row = await (_db.select(
      _db.fonts,
    )..where((f) => f.fontFamily.equals(fontFamily))).getSingleOrNull();
    return row == null ? null : _toFont(row);
  }

  Future<void> insertFont(Font font) async {
    await _db
        .into(_db.fonts)
        .insertOnConflictUpdate(
          FontsCompanion.insert(
            fontFamily: font.fontFamily,
            fontFileName: font.fontFileName,
            wghtAxisJson: Value(jsonEncode(font.fontWghtAxisMap)),
          ),
        );
  }

  Future<void> deleteFontByFamily(String fontFamily) async {
    await (_db.delete(
      _db.fonts,
    )..where((f) => f.fontFamily.equals(fontFamily))).go();
  }

  /// 当前激活的自定义字体（[MoodiaryKVs.customFont]）；未设置或记录缺失返回 null。
  Future<Font?> getActiveFont() async {
    final family = MoodiaryKVs.customFont.get();
    if (family == null || family.isEmpty) return null;
    return getFontByFontFamily(family);
  }
}

extension FontThemeDescriptor on Font {
  ActiveFontDescriptor get themeDescriptor =>
      (family: fontFamily, fileName: fontFileName, wghtAxis: fontWghtAxisMap);
}
