import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_theme/moodiary_theme.dart';

Future<List<Font>> scanDiskFonts() async {
  final scanned = await FontManager.scanFontFiles();
  return [
    for (final f in scanned)
      Font(fontFileName: f.fileName, fontWghtAxisMap: f.wghtAxis),
  ];
}

extension FontThemeDescriptor on Font {
  ActiveFontDescriptor get themeDescriptor =>
      (family: fontFamily, fileName: fontFileName, wghtAxis: fontWghtAxisMap);
}
