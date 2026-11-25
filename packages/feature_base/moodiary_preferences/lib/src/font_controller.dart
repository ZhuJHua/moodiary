import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_theme/moodiary_theme.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_settings_controller.dart';

part 'font_controller.g.dart';

@riverpod
class FontController extends _$FontController {
  @override
  Future<List<Font>> build() async {
    final list = await ref.watch(fontRepositoryProvider).getAllFonts();
    await Future.wait([
      for (final f in list)
        FontManager.loadFont(
          fontName: f.fontFamily,
          fontPath: AppFiles.getRealPath('font', f.fontFileName),
        ),
    ]);
    return list;
  }

  Future<String?> addFont() async {
    final operationRef = ref;
    final repository = ref.read(fontRepositoryProvider);
    final xFile = await FontManager.pickFont(ref.read(filePickerProvider));
    if (xFile == null) return null;
    final fontName = await FontManager.getFontName(filePath: xFile.path);
    if (fontName == null || fontName.isEmpty) return l10n.app.fontNameFailed;
    if (!operationRef.mounted) return null;
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
    await repository.insertFont(newFont);
    await FontManager.loadFont(fontName: newFont.fontFamily, fontPath: newPath);
    if (operationRef.mounted) state = .data([...?state.value, newFont]);
    return '';
  }

  Future<void> removeFont(Font font) async {
    final operationRef = ref;
    final repository = ref.read(fontRepositoryProvider);
    if (MoodiaryKVs.customFont.get() == font.fontFamily) {
      await setActive(null);
    }
    await repository.deleteFontByFamily(font.fontFamily);
    await AppFiles.deleteFile(AppFiles.getRealPath('font', font.fontFileName));
    if (!operationRef.mounted) return;
    final next = (state.value ?? const <Font>[])
        .where((e) => e.fontFamily != font.fontFamily)
        .toList();
    state = .data(next);
  }

  Future<void> setActive(Font? font) async {
    MoodiaryKVs.customFont.set(font?.fontFamily ?? '');
    await ref.read(appSettingsControllerProvider.notifier).bumpTheme();
  }
}
