import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:isar/isar.dart';
import 'package:latlong2/latlong.dart';
import 'package:moodiary/common/models/isar/category.dart';
import 'package:moodiary/common/models/isar/diary.dart';
import 'package:moodiary/common/models/isar/sync_record.dart';
import 'package:moodiary/common/models/map.dart';
import 'package:moodiary/common/values/diary_type.dart';
import 'package:moodiary/components/quill_embed/audio_embed.dart';
import 'package:moodiary/components/quill_embed/image_embed.dart';
import 'package:moodiary/components/quill_embed/video_embed.dart';
import 'package:moodiary/presentation/pref.dart';
import 'package:moodiary/utils/file_util.dart';
import 'package:moodiary/utils/webdav_util.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

class IsarUtil {
  static late final Isar _isar;

  static Future<void> initIsar() async {
    _isar = await Isar.openAsync(
      schemas: [
        DiarySchema,
        CategorySchema,
      ],
      directory: FileUtil.getRealPath('database', ''),
    );
  }

  static Future<void> dataMigration(String path) async {
    var oldIsar = await Isar.openAsync(
        schemas: [DiarySchema, CategorySchema], directory: path, name: 'old');
    List<Diary> oldDiaryList = await oldIsar.diarys.where().findAllAsync();
    List<Category> oldCategoryList =
        await oldIsar.categorys.where().findAllAsync();

    await _isar.writeAsync((isar) {
      isar.clear();
      isar.diarys.putAll(oldDiaryList);
      isar.categorys.putAll(oldCategoryList);
    });
    oldIsar.close(deleteFromDisk: true);
  }

  //清空数据
  static Future<void> clearIsar() async {
    await _isar.writeAsync((isar) {
      isar.clear();
    });
  }

  static Map<String, dynamic> getSize() {
    return FileUtil.bytesToUnits(_isar.diarys.getSize(includeIndexes: true));
  }

  //导出数据
  static Future<void> exportIsar(
      String dir, String path, String fileName) async {
    var isar = Isar.open(
      schemas: [DiarySchema, CategorySchema],
      directory: join(dir, 'database'),
    );
    isar.copyToFile(join(path, fileName));
    isar.close();
  }

  //插入一条日记
  static Future<void> insertADiary(Diary diary) async {
    await _isar.writeAsync((isar) {
      isar.diarys.put(diary);
    });
  }

  //根据月份获取日记
  static Future<List<Diary>> getDiaryByMonth(int year, int month) async {
    return await _isar.diarys
        .where()
        .showEqualTo(true)
        .yMEqualTo('${year.toString()}/${month.toString()}')
        .sortByTimeDesc()
        .findAllAsync();
  }

  //根据id获取日记
  static Future<Diary?> getDiaryByID(int isarId) async {
    return await _isar.diarys.getAsync(isarId);
  }

  //根据日期范围获取日记
  static Future<List<Diary>> getDiariesByDateRange(DateTime start, DateTime end,
      {bool all = true}) async {
    return await _isar.diarys
        .where()
        .timeBetween(start, end)
        .showEqualTo(all)
        .findAllAsync();
  }

  //获取全部日记
  static Future<List<Diary>> getAllDiaries() async {
    return await _isar.diarys.where().findAllAsync();
  }

  /// 获取全部日记
  static Future<List<Diary>> getAllDiariesSorted() async {
    return _isar.diarys
        .where()
        .showEqualTo(true)
        .sortByTimeDesc()
        .findAllAsync();
  }

  //获取指定范围内的天气
  static Future<List<List<String>>> getWeatherByDateRange(
      DateTime start, DateTime end) async {
    return (await _isar.diarys
            .where()
            .showEqualTo(true)
            .timeBetween(start, end)
            .distinctByYMd()
            .weatherProperty()
            .findAllAsync())
        .cast<List<String>>();
  }

  //获取指定范围的心情指数
  static Future<List<double>> getMoodByDateRange(
      DateTime start, DateTime end) async {
    return (await _isar.diarys
            .where()
            .showEqualTo(true)
            .timeBetween(start, end)
            .distinctByYMd()
            .moodProperty()
            .findAllAsync())
        .cast<double>();
  }

  //删除某篇日记
  static Future<bool> deleteADiary(int isarId) async {
    return await _isar.writeAsync((isar) {
      return isar.diarys.delete(isarId);
    });
  }

  //回收站日记
  static Future<List<Diary>> getRecycleBinDiaries() async {
    return await _isar.diarys
        .where()
        .showEqualTo(false)
        .sortByTimeDesc()
        .findAllAsync();
  }

  //更新日记
  static Future<void> updateADiary(
      {Diary? oldDiary, required Diary newDiary}) async {
    // 如果没有旧日记，说明是新增日记
    newDiary.lastModified = DateTime.now();
    await _isar.writeAsync((isar) {
      isar.diarys.put(newDiary);
    });
    // 更新日记, 旧日记不为空，说明是更新日记, 需要清理旧日记的媒体文件
    if (oldDiary != null) {
      // 清理本地媒体文件
      await FileUtil.cleanUpOldMediaFiles(oldDiary, newDiary);
      if (WebDavUtil().hasOption &&
          PrefUtil.getValue<bool>('autoSyncAfterChange') == true) {
        unawaited(WebDavUtil()
            .updateSingleDiary(oldDiary: oldDiary, newDiary: newDiary));
      }
    } else {
      if (WebDavUtil().hasOption &&
          PrefUtil.getValue<bool>('autoSyncAfterChange') == true) {
        unawaited(WebDavUtil().uploadSingleDiary(newDiary));
      }
    }
  }

  //查询日记
  static Future<List<Diary>> searchDiaries(String value) async {
    var contentResults = await _isar.diarys
        .where()
        .showEqualTo(true)
        .contentTextContains(value)
        .findAllAsync();
    var titleResults = await _isar.diarys
        .where()
        .showEqualTo(true)
        .titleContains(value)
        .findAllAsync();

    // 合并并去重
    var combinedResults = {...contentResults, ...titleResults}.toList();

    // 按时间排序
    combinedResults.sort((a, b) => b.time.compareTo(a.time));

    return combinedResults;
  }

  static Future<List<Diary>> searchDiariesByTag(String value) async {
    return await _isar.diarys
        .where()
        .showEqualTo(true)
        .tagsElementContains(value)
        .findAllAsync();
  }

  //获取不在回收站的日记总数
  static Future<int> countShowDiary() async {
    return await _isar.diarys.where().showEqualTo(true).countAsync();
  }

  static int countAllDiary() {
    return _isar.diarys.count();
  }

  //获取分类总数
  static int countCategories() {
    return _isar.categorys.count();
  }

  //获取分类名称
  static Category? getCategoryName(String id) {
    return _isar.categorys.get(id);
  }

  // 插入一个分类
  static Future<bool> insertACategory(Category category) async {
    return await _isar.writeAsync((isar) {
      // 查询数据库中是否有同名但 ID 不同的分类
      final existingCategory = isar.categorys
          .where()
          .categoryNameEqualTo(category.categoryName)
          .findFirst();
      if (existingCategory != null && existingCategory.id != category.id) {
        // 如果同名但 ID 不同，则修改分类名称并添加随机后缀
        category.categoryName =
            '${category.categoryName}_${const Uuid().v4().substring(0, 4)}';
      }
      // 为分类分配新的唯一 ID
      category.id = const Uuid().v7();
      // 将分类保存到数据库中
      isar.categorys.put(category);
      // 返回是否是新名称（true 表示没有冲突）
      return existingCategory == null;
    });
  }

  // 更新一个分类
  static Future<bool> updateACategory(Category category) async {
    return await _isar.writeAsync((isar) {
      // 查询数据库中是否有同名但 ID 不同的分类
      final existingCategory = isar.categorys
          .where()
          .categoryNameEqualTo(category.categoryName)
          .findFirst();
      if (existingCategory != null && existingCategory.id != category.id) {
        // 如果同名但 ID 不同，则修改分类名称并添加随机后缀
        category.categoryName =
            '${category.categoryName}_${const Uuid().v4().substring(0, 4)}';
      }
      // 将分类保存到数据库中
      isar.categorys.put(category);
      // 返回是否是新名称（true 表示没有冲突）
      return existingCategory == null;
    });
  }

  static Future<bool> deleteACategory(String id) async {
    return await _isar.writeAsync((isar) {
      if (isar.diarys.where().categoryIdEqualTo(id).isEmpty()) {
        return isar.categorys.delete(id);
      } else {
        return false;
      }
    });
  }

  // 获取所有日记内容
  static Future<List<String>> getContentList() async {
    return (await _isar.diarys
            .where()
            .showEqualTo(true)
            .contentTextProperty()
            .findAllAsync())
        .cast<String>();
  }

  //获取所有分类，这是个同步方法，用于第一次初始化，要怪就怪 TabBar
  static List<Category> getAllCategory() {
    return _isar.categorys.where().sortById().findAll();
  }

  static Future<List<Category>> getAllCategoryAsync() async {
    return _isar.categorys.where().sortById().findAllAsync();
  }

  //获取对应分类的日记,如果为空，返回全部日记
  static Future<List<Diary>> getDiaryByCategory(
      String? categoryId, int offset, int limit) async {
    if (categoryId == null) {
      return await _isar.diarys
          .where()
          .showEqualTo(true)
          .sortByTimeDesc()
          .findAllAsync(offset: offset, limit: limit);
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
  static Future<List<Diary>> getDiaryByDay(DateTime time) async {
    return await _isar.diarys
        .where()
        .showEqualTo(true)
        .yMdEqualTo(
            '${time.year.toString()}/${time.month.toString()}/${time.day.toString()}')
        .sortByTimeDesc()
        .findAllAsync();
  }

  static Future<List<Diary>> getDiary(int offset, int limit) async {
    return await _isar.diarys
        .where()
        .findAllAsync(offset: offset, limit: limit);
  }

  /// 2.4.8 版本变更
  /// 新增字段
  /// 1.position 用于记录位置
  static void mergeToV2_4_8(String dir) {
    var isar = Isar.open(
      schemas: [DiarySchema, CategorySchema],
      directory: dir,
    );
    final countDiary = isar.diarys.where().count();
    for (var i = 0; i < countDiary; i += 50) {
      var diaries = isar.diarys.where().findAll(offset: i, limit: 50);
      isar.write((isar) {
        isar.diarys.putAll(diaries);
      });
    }
    isar.close();
  }

  /// 2.6.0 版本变更
  /// 新增字段
  /// 1.type 类型字段，用于表示是纯文本还是富文本
  /// 2.lastModified 最后修改时间
  /// 变更
  /// 1.将时间字段修改为最后修改时间
  /// 2.将类型字段修改为富文本
  static void mergeToV2_6_0(String dir) {
    var isar = Isar.open(
      schemas: [DiarySchema, CategorySchema],
      directory: dir,
    );
    final countDiary = isar.diarys.where().count();

    for (var i = 0; i < countDiary; i += 50) {
      var diaries = isar.diarys.where().findAll(offset: i, limit: 50);

      isar.write((isar) {
        // 公共quillController
        final quillController = QuillController.basic();

        for (var diary in diaries) {
          // 更新字段类型和修改时间
          diary.type = DiaryType.richText.value;
          diary.lastModified = diary.time; // 设置最后修改时间
          // 遍历资源文件，将资源文件插入到富文本中
          quillController.document =
              Document.fromJson(jsonDecode(diary.content));

          for (var image in diary.imageName) {
            insertNewImage(imageName: image, quillController: quillController);
          }
          for (var video in diary.videoName) {
            insertNewVideo(videoName: video, quillController: quillController);
          }
          for (var audio in diary.audioName) {
            insertAudio(audioName: audio, quillController: quillController);
          }

          // 更新富文本内容
          diary.content =
              jsonEncode(quillController.document.toDelta().toJson());

          // 保存更新后的日记
          isar.diarys.put(diary);

          // 清理quillController
          quillController.clear();
        }
      });
    }

    isar.close();
  }

  /// 2.6.3 修复
  /// 修复之前webdav同步时，没有同步分类的问题
  /// 遍历所有日记，如果本地没有日记的分类，就创建一个分类，名称为分类名
  static void fixV2_6_3(String dir) {
    var isar = Isar.open(
      schemas: [DiarySchema, CategorySchema],
      directory: dir,
    );
    final countDiary = isar.diarys.where().count();
    for (var i = 0; i < countDiary; i += 50) {
      var diaries = isar.diarys.where().findAll(offset: i, limit: 50);
      isar.write((isar) {
        for (var diary in diaries) {
          // 如果日记有分类，但是本地没有这个分类，就创建一个分类，名称为“修复分类+数字”
          final id = diary.categoryId;
          if (id != null && isar.categorys.where().idEqualTo(id).isEmpty()) {
            isar.categorys.put(
              Category()
                ..id = id
                ..categoryName = '已修复${const Uuid().v4().substring(0, 4)}',
            );
          }
        }
      });
    }
    isar.close();
  }

  static void insertNewImage(
      {required String imageName, required QuillController quillController}) {
    final imageBlock = ImageBlockEmbed.fromName(imageName);
    final index = quillController.selection.baseOffset;
    final length = quillController.selection.extentOffset - index;
    quillController.replaceText(
        index, length, imageBlock, TextSelection.collapsed(offset: index + 1));
  }

  static void insertNewVideo(
      {required String videoName, required QuillController quillController}) {
    final videoBlock = VideoBlockEmbed.fromName(videoName);
    final index = quillController.selection.baseOffset;
    final length = quillController.selection.extentOffset - index;
    quillController.replaceText(
        index, length, videoBlock, TextSelection.collapsed(offset: index + 1));
  }

  static void insertAudio(
      {required String audioName, required QuillController quillController}) {
    final audioBlock = AudioBlockEmbed.fromName(audioName);
    final index = quillController.selection.baseOffset;
    final length = quillController.selection.extentOffset - index;
    quillController.replaceText(
        index, length, audioBlock, TextSelection.collapsed(offset: index + 1));
  }

  // 获取用于地图显示的对象
  static Future<List<DiaryMapItem>> getAllMapItem() async {
    List<DiaryMapItem> res = [];

    /// 所有的日记
    /// 要满足以下条件
    /// 1. 有定位坐标
    /// 2. show
    var diaries = await _isar.diarys
        .where()
        .showEqualTo(true)
        .positionIsNotEmpty()
        .findAllAsync();
    for (var diary in diaries) {
      res.add(DiaryMapItem(
          LatLng(
              double.parse(diary.position[0]), double.parse(diary.position[1])),
          diary.isarId,
          diary.imageName.isEmpty ? '' : diary.imageName.first));
    }
    return res;
  }

  //构建搜索
  static void buildSearch(String dir) async {
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
        //       .getImageAspectRatio(FileImage(File(FileUtil.getRealPath('image', diary.imageName.first))));
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

  // 添加sync任务
  static Future<void> addSyncRecord(SyncRecord record) async {
    await _isar.writeAsync((isar) {
      isar.syncRecords.put(record);
    });
  }

  // 获取sync任务
  static Future<List<SyncRecord>> getSyncRecords() async {
    return await _isar.syncRecords.where().findAllAsync();
  }

  // 删除sync任务
  static Future<void> deleteSyncRecord(int id) async {
    await _isar.writeAsync((isar) {
      isar.syncRecords.delete(id);
    });
  }
}
