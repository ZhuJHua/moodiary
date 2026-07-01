import 'package:isar_plus/isar_plus.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_core/src/utils/file_util.dart';
import 'package:path/path.dart';

final class IsarDatabase {
  static final _instance = IsarDatabase._();

  IsarDatabase._();

  factory IsarDatabase.get() => _instance;

  late final Isar _isar;

  Isar get isar => _isar;

  static final _schemas = [
    DiarySchema,
    CategorySchema,
    FontSchema,
    DiarySearchIndexSchema,
    DiaryLinkIndexSchema,
    ReindexQueueSchema,
    LlmProviderSchema,
    ChatSessionSchema,
    ChatMessageSchema,
  ];

  Future<void> init() async {
    _isar = await Isar.openAsync(
      schemas: _schemas,
      directory: FileUtil.getRealPath('database', ''),
    );
  }

  Future<void> clear() async {
    await _isar.writeAsync((isar) {
      isar.clear();
    });
  }

  Map<String, dynamic> getSize() {
    return FileUtil.bytesToUnits(_isar.diarys.getSize(includeIndexes: true));
  }

  /// 重新 open 一份共享同目录的 Isar 做 copyToFile——isar_plus 推荐姿势，避开写事务冲突。
  Future<void> export(String dir, String path, String fileName) async {
    final isar = Isar.open(schemas: _schemas, directory: join(dir, 'database'));
    isar.copyToFile(join(path, fileName));
    isar.close();
  }

  /// 从 [path] 读取旧备份，把 diary/category/font 搬到当前 Isar 后清除旧文件。
  Future<void> dataMigration(String path) async {
    final oldIsar = await Isar.openAsync(
      schemas: _schemas,
      directory: path,
      name: 'old',
    );
    final List<Diary> oldDiaryList = await oldIsar.diarys
        .where()
        .findAllAsync();
    final List<Category> oldCategoryList = await oldIsar.categorys
        .where()
        .findAllAsync();
    final List<Font> oldFontList = await oldIsar.fonts.where().findAllAsync();

    await _isar.writeAsync((isar) {
      isar.clear();
      isar.diarys.putAll(oldDiaryList);
      isar.categorys.putAll(oldCategoryList);
      isar.fonts.putAll(oldFontList);
    });
    oldIsar.close(deleteFromDisk: true);
  }

  Future<Font?> getFontByFontFamily(String fontFamily) async {
    return await _isar.fonts
        .where()
        .fontFamilyEqualTo(fontFamily)
        .findFirstAsync();
  }

  Future<List<Font>> getAllFonts() async {
    return _isar.fonts.where().findAllAsync();
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
}
