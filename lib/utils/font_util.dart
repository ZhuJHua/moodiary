import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:moodiary/src/rust/api/font.dart';
import 'package:moodiary/utils/lru.dart';

class FontUtil {
  static final HashSet<String> _loadedFonts = HashSet();

  static final _fontNameCache = AsyncLRUCache<String, String>(maxSize: 100);
  static final _fontWghtAxisCache =
      AsyncLRUCache<String, Map<String, double>>(maxSize: 100);

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
    final cacheName = await _fontNameCache.get(filePath);
    if (cacheName != null) {
      return cacheName;
    }
    final fontName = await FontReader.getFontNameFromTtf(ttfFilePath: filePath);
    if (fontName != null) {
      await _fontNameCache.put(filePath, fontName);
    }
    return fontName;
  }

  static Future<Map<String, double>> getFontWghtAxis(
      {required String filePath}) async {
    final cacheWghtAxis = await _fontWghtAxisCache.get(filePath);
    if (cacheWghtAxis != null) {
      return cacheWghtAxis;
    }
    final wghtAxis =
        await FontReader.getWghtAxisFromVfFont(ttfFilePath: filePath);
    if (wghtAxis.isNotEmpty) {
      await _fontWghtAxisCache.put(filePath, wghtAxis);
    }
    return wghtAxis;
  }
}
