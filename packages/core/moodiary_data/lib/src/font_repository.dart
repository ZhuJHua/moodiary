import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_models/moodiary_models.dart';

class FontRepository {
  FontRepository._(this._isar);

  factory FontRepository.get() => _instance;

  static final FontRepository _instance = FontRepository._(
    IsarDatabase.get().isar,
  );

  final Isar _isar;

  Future<List<Font>> getAllFonts() {
    return _isar.fonts.where().findAllAsync();
  }

  Future<Font?> getFontByFontFamily(String fontFamily) {
    return _isar.fonts.where().fontFamilyEqualTo(fontFamily).findFirstAsync();
  }

  Future<void> insertFont(Font font) async {
    await _isar.writeAsync((isar) {
      isar.fonts.put(font);
    });
  }

  Future<void> deleteFontById(int id) async {
    await _isar.writeAsync((isar) {
      isar.fonts.delete(id);
    });
  }

  /// 当前激活的自定义字体（[MoodiaryKVs.customFont]）；未设置或记录缺失返回 null。
  Future<Font?> getActiveFont() async {
    final family = MoodiaryKVs.customFont.get();
    if (family == null || family.isEmpty) return null;
    return getFontByFontFamily(family);
  }
}
