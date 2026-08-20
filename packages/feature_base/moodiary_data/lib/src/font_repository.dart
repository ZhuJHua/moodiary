import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_theme/moodiary_theme.dart';

class FontRepository {
  FontRepository._(this._isar);

  factory FontRepository.get() => _instance;

  static final FontRepository _instance = ._(IsarDatabase.get().isar);

  final Isar _isar;

  Future<List<Font>> getAllFonts() {
    return _isar.fonts.where().findAllAsync();
  }

  /// 扫磁盘上的字体文件并装配成 [Font]。
  ///
  /// core 的 [FontManager.scanFontFiles] 只吐原始描述（它够不着 `Font`），
  /// 领域装配在这一层做。
  Future<List<Font>> scanDiskFonts() async {
    final scanned = await FontManager.scanFontFiles();
    return [
      for (final f in scanned)
        Font(fontFileName: f.fileName, fontWghtAxisMap: f.wghtAxis),
    ];
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

extension FontThemeDescriptor on Font {
  /// 喂给 `ThemeManager.buildTheme` 的原始描述。core 不认识 `Font`，转换在这里。
  ActiveFontDescriptor get themeDescriptor =>
      (family: fontFamily, fileName: fontFileName, wghtAxis: fontWghtAxisMap);
}
