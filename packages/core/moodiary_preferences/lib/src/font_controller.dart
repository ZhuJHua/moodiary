import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_settings_controller.dart';

part 'font_controller.g.dart';

@riverpod
class FontController extends _$FontController {
  @override
  Future<List<Font>> build() async {
    final list = await FontRepository.get().getAllFonts();
    await Future.wait([
      for (final f in list)
        FontManager.loadFont(
          fontName: f.fontFamily,
          fontPath: AppFiles.getRealPath('font', f.fontFileName),
        ),
    ]);
    return list;
  }

  /// 返回 `null`=用户取消、非空错误 message=失败、空字符串=成功。
  Future<String?> addFont() async {
    final xFile = await FontManager.pickFont();
    if (xFile == null) return null;
    final fontName = await FontManager.getFontName(filePath: xFile.path);
    if (fontName == null || fontName.isEmpty) return l10n.app.fontNameFailed;
    final current = state.value ?? const <Font>[];
    if (current.any((e) => e.fontFamily == fontName)) {
      return l10n.app.fontExists;
    }
    final fontFileName = '$fontName${p.extension(xFile.path)}';
    final newPath = AppFiles.getRealPath('font', fontFileName);
    final newFont = Font(
      fontFileName: fontFileName,
      fontWghtAxisMap: await FontManager.getFontWghtAxis(filePath: xFile.path),
    );
    await xFile.saveTo(newPath);
    await FontRepository.get().insertFont(newFont);
    await FontManager.loadFont(fontName: newFont.fontFamily, fontPath: newPath);
    state = .data([...current, newFont]);
    return '';
  }

  /// 若正在使用，先切回系统字体再删，避免引用已删除文件。
  Future<void> removeFont(Font font) async {
    if (MoodiaryKVs.customFont.get() == font.fontFamily) {
      await setActive(null);
    }
    await FontRepository.get().deleteFontById(font.id);
    await AppFiles.deleteFile(AppFiles.getRealPath('font', font.fontFileName));
    final next = (state.value ?? const <Font>[])
        .where((e) => e.fontFamily != font.fontFamily)
        .toList();
    state = .data(next);
  }

  Future<void> setActive(Font? font) async {
    await MoodiaryKVs.customFont.set(font?.fontFamily ?? '');
    await ref.read(appSettingsControllerProvider.notifier).bumpTheme();
  }
}
