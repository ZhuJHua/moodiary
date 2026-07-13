import 'dart:convert';
import 'dart:io';

import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_sync/src/data/sync.dart';

/// JSON 文件备份后端：把所有日记 + 分类导出为单一 JSON 文件 / 从其导入。
///
/// 文件格式：
/// ```json
/// {
///   "version": 1,
///   "exportedAt": "<ISO 8601>",
///   "diaries": [ ... ],
///   "categories": [ ... ]
/// }
/// ```
class JsonFileSyncBackend implements SyncBackend {
  final String filePath;

  JsonFileSyncBackend({required this.filePath});

  @override
  String get displayName => 'JSON 备份（$filePath）';

  @override
  bool get isReady => filePath.isNotEmpty;

  static const int currentVersion = 1;

  @override
  Future<SyncReport> pushAll() async {
    final sw = Stopwatch()..start();
    final diaryRepo = DiaryRepository.get();
    final categoryRepo = CategoryRepository.get();

    final diaries = await diaryRepo.getAllDiaries();
    final cats = await categoryRepo.getAllCategories().run();
    final categories = cats.getOrElse((_) => <Category>[]);

    final payload = {
      'version': currentVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'diaries': diaries.map((d) => d.toJson()).toList(),
      'categories': categories.map((c) => c.toJson()).toList(),
    };

    final file = File(filePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(payload));

    sw.stop();
    return SyncReport(
      diaryCount: diaries.length,
      categoryCount: categories.length,
      elapsed: sw.elapsed,
    );
  }

  @override
  Future<SyncReport> pullAll() async {
    final sw = Stopwatch()..start();
    final file = File(filePath);
    if (!await file.exists()) {
      throw SyncException('备份文件不存在：$filePath');
    }
    final text = await file.readAsString();
    final dynamic decoded;
    try {
      decoded = jsonDecode(text);
    } catch (e) {
      throw SyncException('备份文件格式不正确：$e');
    }
    if (decoded is! Map) {
      throw const SyncException('备份文件根节点必须是对象');
    }
    final version = decoded['version'] as int? ?? 0;
    if (version > currentVersion) {
      throw SyncException(
        '备份文件版本 $version 高于当前支持的 $currentVersion，请升级 Moodiary',
      );
    }

    final diaryJsonList = (decoded['diaries'] as List? ?? const []);
    final categoryJsonList = (decoded['categories'] as List? ?? const []);

    final diaryRepo = DiaryRepository.get();
    final categoryRepo = CategoryRepository.get();

    // 解析容错逐条，落库走批量：逐篇 insert 会对高频词 posting 行产生 O(N²) 重写，
    // 几千篇的恢复从几十秒降到秒级。分块以限制分词结果的内存峰值。
    final diaries = <Diary>[];
    for (final raw in diaryJsonList) {
      if (raw is! Map<String, dynamic>) continue;
      try {
        diaries.add(Diary.fromJson(raw));
      } catch (_) {}
    }
    int diaryCount = 0;
    const chunkSize = 500;
    for (var i = 0; i < diaries.length; i += chunkSize) {
      final chunk = diaries.sublist(
        i,
        (i + chunkSize).clamp(0, diaries.length),
      );
      await diaryRepo.insertDiaries(chunk);
      diaryCount += chunk.length;
    }

    int categoryCount = 0;
    for (final raw in categoryJsonList) {
      if (raw is! Map<String, dynamic>) continue;
      try {
        final category = Category.fromJson(raw);
        final ok = await categoryRepo.insertACategory(category).run();
        if (ok.isRight()) categoryCount += 1;
      } catch (_) {}
    }

    sw.stop();
    return SyncReport(
      diaryCount: diaryCount,
      categoryCount: categoryCount,
      elapsed: sw.elapsed,
      warning: (diaryJsonList.length - diaryCount) +
                  (categoryJsonList.length - categoryCount) >
              0
          ? '部分记录解析失败已跳过'
          : null,
    );
  }
}
