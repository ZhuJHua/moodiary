import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:moodiary_core/src/files/app_files.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_rust/moodiary_rust.dart' as rust;
import 'package:path/path.dart';

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
        ..addFont(Future.value(ByteData.view(fontData.buffer)));
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

  static Future<XFile?> pickFont() async {
    final res = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['ttf', 'otf'],
    );
    return res?.xFile;
  }

  static Future<List<Font>> getAllFonts() async {
    final fontFileList = await AppFiles.getDirFilePath('font');
    final fontList = <Font>[];
    for (final fontFile in fontFileList) {
      final fontName = await getFontName(filePath: fontFile);
      final fontFileName = '$fontName${extension(fontFile)}';
      if (fontName != null) {
        final font = Font(
          fontFileName: fontFileName,
          fontWghtAxisMap: await getFontWghtAxis(filePath: fontFile),
        );
        fontList.add(font);
      }
    }
    return fontList;
  }
}
