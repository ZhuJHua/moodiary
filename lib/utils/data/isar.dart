import 'package:isar/isar.dart';
import 'package:mood_diary/common/models/isar/category.dart';
import 'package:mood_diary/common/models/isar/diary.dart';
import 'package:mood_diary/utils/utils.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

class IsarUtil {
  late final Isar _isar;

  Future<void> initIsar() async {
    _isar = await Isar.openAsync(
      schemas: [
        DiarySchema,
        CategorySchema,
      ],
      directory: Utils().fileUtil.getRealPath('database', ''),
    );
  }

  Future<void> dataMigration(String path) async {
    var oldIsar = await Isar.openAsync(schemas: [DiarySchema, CategorySchema], directory: path, name: 'old');
    List<Diary> oldDiaryList = await oldIsar.diarys.where().findAllAsync();
    List<Category> oldCategoryList = await oldIsar.categorys.where().findAllAsync();

    await _isar.writeAsync((isar) {
      isar.clear();
      isar.diarys.putAll(oldDiaryList);
      isar.categorys.putAll(oldCategoryList);
    });
    oldIsar.close(deleteFromDisk: true);
  }

  //清空数据
  Future<void> clearIsar() async {
    await _isar.writeAsync((isar) {
      isar.clear();
    });
  }

  Map<String, dynamic> getSize() {
    return Utils().fileUtil.bytesToUnits(_isar.diarys.getSize(includeIndexes: true));
  }

  //导出数据
  Future<void> exportIsar(String dir, String path, String fileName) async {
    var isar = Isar.open(
      schemas: [DiarySchema, CategorySchema],
      directory: join(dir, 'database'),
    );
    isar.copyToFile(join(path, fileName));
    isar.close();
  }

  //插入一条日记
  Future<void> insertADiary(Diary diary) async {
    await _isar.writeAsync((isar) {
      diary.id = const Uuid().v7();
      isar.diarys.put(diary);
    });
  }

  //根据月份获取包含日记的日期
  Future<List<DateTime>> getDiaryDateByMonth(int year, int month) async {
    return await _isar.diarys
        .where()
        .yMEqualTo('${year.toString()}/${month.toString()}')
        .showEqualTo(true)
        .timeProperty()
        .findAllAsync();
  }

  //根据id获取日记
  Future<Diary?> getDiaryByID(String id) async {
    return await _isar.diarys.getAsync(id);
  }

  //根据日期范围获取日记
  Future<List<Diary>> getDiariesByDateRange(DateTime start, DateTime end) async {
    return await _isar.diarys.where().timeBetween(start, end).showEqualTo(true).findAllAsync();
  }

  //获取指定范围内的天气
  Future<List<List<String>>> getWeatherByDateRange(DateTime start, DateTime end) async {
    return await _isar.diarys
        .where()
        .showEqualTo(true)
        .timeBetween(start, end)
        .distinctByYMd()
        .weatherProperty()
        .findAllAsync();
  }

  //获取指定范围的心情指数
  Future<List<double>> getMoodByDateRange(DateTime start, DateTime end) async {
    return await _isar.diarys
        .where()
        .showEqualTo(true)
        .timeBetween(start, end)
        .distinctByYMd()
        .moodProperty()
        .findAllAsync();
  }

  //删除某篇日记
  Future<bool> deleteADiary(String id) async {
    return await _isar.writeAsync((isar) {
      return isar.diarys.delete(id);
    });
  }

  //回收站日记
  Future<List<Diary>> getRecycleBinDiaries() async {
    return await _isar.diarys.where().showEqualTo(false).sortByTimeDesc().findAllAsync();
  }

  //更新日记
  Future<void> updateADiary(Diary diary) async {
    await _isar.writeAsync((isar) {
      isar.diarys.put(diary);
    });
  }

  //查询日记
  Future<List<Diary>> searchDiaries(String value) async {
    return await _isar.diarys.where().showEqualTo(true).contentTextContains(value).findAllAsync();
  }

  Future<List<Diary>> searchDiariesByTag(String value) async {
    return await _isar.diarys.where().showEqualTo(true).tagsElementContains(value).findAllAsync();
  }

  //获取不在回收站的日记总数
  Future<int> countShowDiary() async {
    return await _isar.diarys.where().showEqualTo(true).countAsync();
  }

  int countAllDiary() {
    return _isar.diarys.count();
  }

  //获取分类总数
  Future<int> countCategories() async {
    return await _isar.categorys.where().countAsync();
  }

  //获取分类名称
  Category? getCategoryName(String id) {
    return _isar.categorys.get(id);
  }

  Future<bool> insertACategory(Category category) async {
    return await _isar.writeAsync((isar) {
      if (isar.categorys.where().categoryNameEqualTo(category.categoryName).isEmpty()) {
        category.id = const Uuid().v7();
        isar.categorys.put(category);
        return true;
      } else {
        return false;
      }
    });
  }

  Future<void> updateACategory(Category category) async {
    await _isar.writeAsync((isar) {
      isar.categorys.put(category);
    });
  }

  Future<bool> deleteACategory(String id) async {
    return await _isar.writeAsync((isar) {
      if (isar.diarys.where().categoryIdEqualTo(id).isEmpty()) {
        return isar.categorys.delete(id);
      } else {
        return false;
      }
    });
  }

  // 获取所有日记内容
  Future<List<String>> getContentList() async {
    return await _isar.diarys.where().showEqualTo(true).contentTextProperty().findAllAsync();
  }

  //获取所有分类，这是个同步方法，用于第一次初始化，要怪就怪 TabBar
  List<Category> getAllCategory() {
    return _isar.categorys.where().sortById().findAll();
  }

  Future<List<Category>> getAllCategoryAsync() async {
    return _isar.categorys.where().sortById().findAllAsync();
  }

  //获取对应分类的日记,如果为空，返回全部日记
  Future<List<Diary>> getDiaryByCategory(String? categoryId, int offset, int limit) async {
    if (categoryId == null) {
      return await _isar.diarys.where().showEqualTo(true).sortByTimeDesc().findAllAsync(offset: offset, limit: limit);
    } else {
      return await _isar.diarys
          .where()
          .showEqualTo(true)
          .categoryIdEqualTo(categoryId)
          .sortByTimeDesc()
          .findAllAsync(offset: offset, limit: limit);
    }
  }

  //获取某一天的日记
  Future<List<Diary>> getDiaryByDay(DateTime time) async {
    return await _isar.diarys
        .where()
        .showEqualTo(true)
        .yMdEqualTo('${time.year.toString()}/${time.month.toString()}/${time.day.toString()}')
        .sortByTimeDesc()
        .findAllAsync();
  }

  Future<List<Diary>> getDiary(int offset, int limit) async {
    return await _isar.diarys.where().findAllAsync(offset: offset, limit: limit);
  }

  //构建搜索
  void buildSearch(String dir) async {
    var isar = Isar.open(
      schemas: [DiarySchema, CategorySchema],
      directory: dir,
    );
    final countDiary = isar.diarys.where().count();
    var result = <Diary>[];
    for (var i = 0; i < countDiary; i += 50) {
      var diaries = isar.diarys.where().findAll(offset: i, limit: 50);
      for (var diary in diaries) {
        //获取封面比例
        // if (diary.imageName.isNotEmpty) {
        //   diary.aspect = await Utils()
        //       .mediaUtil
        //       .getImageAspectRatio(FileImage(File(Utils().fileUtil.getRealPath('image', diary.imageName.first))));
        //   result.add(diary);
        // }
        diary.contentText = diary.contentText.trim();
        result.add(diary);
      }
      //final categorys = isar.categorys.where().findAll();
      isar.write((isar) {
        isar.diarys.putAll(result);
      });
    }
  }
}
