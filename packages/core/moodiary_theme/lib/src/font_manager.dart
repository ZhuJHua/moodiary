import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_rust/foundation.dart' as rust;
import 'package:path/path.dart';

typedef ActiveFontDescriptor = ({
  String family,
  String fileName,
  Map<String, dynamic> wghtAxis,
});

class FontManager {
  static final HashSet<String> _loadedFonts = HashSet();

  static Future<bool> loadFont({
    required String fontName,
    required String fontPath,
  }) async {
    final fontFile = File(fontPath);
    if (!(await fontFile.exists())) {
      return false;
    }

    if (_loadedFonts.contains(fontName)) {
      return true;
    }

    try {
      final Uint8List fontData = await fontFile.readAsBytes();
      final fontLoader = FontLoader(fontName)
        ..addFont(.value(ByteData.view(fontData.buffer)));
      await fontLoader.load();
      _loadedFonts.add(fontName);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<String?> getFontName({required String filePath}) async {
    return await rust.FontReader.getFontNameFromTtf(ttfFilePath: filePath);
  }

  static Future<Map<String, dynamic>> getFontWghtAxis({
    required String filePath,
  }) async {
    try {
      final axis = await rust.FontReader.getWghtAxisFromVfFont(
        ttfFilePath: filePath,
      );
      return Map<String, dynamic>.from(axis);
    } catch (_) {
      return {};
    }
  }

  static Future<XFile?> pickFont() {
    // 走端口：全仓选文件收敛到 IFilePicker 一个入口（实现由 app 组合根注册），
    // 桌面换实现时字体导入不会成为被漏掉的第二条路。
    return IFilePicker.get().pickFile(allowedExtensions: ['ttf', 'otf']);
  }

  static Future<List<({String fileName, Map<String, dynamic> wghtAxis})>>
  scanFontFiles() async {
    final fontFileList = await AppFiles.getDirFilePath('font');
    final result = <({String fileName, Map<String, dynamic> wghtAxis})>[];
    for (final fontFile in fontFileList) {
      final fontName = await getFontName(filePath: fontFile);
      if (fontName == null) continue;
      result.add((
        fileName: '$fontName${extension(fontFile)}',
        wghtAxis: await getFontWghtAxis(filePath: fontFile),
      ));
    }
    return result;
  }
}
