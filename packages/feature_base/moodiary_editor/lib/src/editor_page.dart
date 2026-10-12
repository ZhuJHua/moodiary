import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:moodiary_platform/moodiary_platform.dart';
import 'package:path/path.dart' as p;

const _assetKey = 'packages/moodiary_editor/assets/editor/index.html';

sealed class EditorPage {
  const EditorPage();
}

final class EditorAssetPage extends EditorPage {
  const EditorAssetPage(this.assetKey);

  final String assetKey;
}

final class EditorFilePage extends EditorPage {
  const EditorFilePage({required this.path, required this.readAccessDir});

  final String path;

  final String readAccessDir;
}

Future<EditorPage>? _filePage;

// 安卓的 file:// 页面能读数据目录，直接从 APK 加载；WebKit 只给一个目录签读权限，
// 页面得和媒体、字体同在 Application Support 下，所以按内容拷一份过去
Future<EditorPage> resolveEditorPage() {
  if (Platform.isAndroid) return Future.value(const EditorAssetPage(_assetKey));
  return _filePage ??= _copyIntoSupport().catchError((Object e) {
    _filePage = null;
    throw e;
  });
}

Future<EditorPage> _copyIntoSupport() async {
  final support = PlatformService.get().applicationSupportPath;
  final file = File(p.join(support, 'editor', 'index.html'));
  final data = await rootBundle.load(_assetKey);
  final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  if (!await _sameContent(file, bytes)) {
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(file.path);
  }
  return EditorFilePage(path: file.path, readAccessDir: support);
}

Future<bool> _sameContent(File file, List<int> bytes) async {
  if (!await file.exists() || await file.length() != bytes.length) return false;
  final existing = await file.readAsBytes();
  for (var i = 0; i < bytes.length; i++) {
    if (existing[i] != bytes[i]) return false;
  }
  return true;
}
