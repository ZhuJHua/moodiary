import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:get/get.dart';
import 'package:isar/isar.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import '../common/models/isar/category.dart';
import '../common/models/isar/diary.dart';
import '../common/values/media_type.dart';
import '../components/audio_player/audio_player_logic.dart';
import 'data/isar.dart';
import 'data/pref.dart';

class FileUtil {
  static final String _filePath = PrefUtil.getValue<String>('supportPath')!;

  static final String _cachePath = PrefUtil.getValue<String>('cachePath')!;

  // 删除文件
  static Future<bool> deleteFile(String path) async {
    File file = File(path);
    if (await file.exists()) {
      await file.delete();
      return true; // 返回删除成功
    } else {
      // 文件不存在，返回失败
      return false;
    }
  }

  static String getErrorLogFilePath() {
    //打开文件
    return join(_filePath, 'error.log');
  }

  //删除指定文件夹
  static Future<void> deleteDir(String path) async {
    Directory directory = Directory(path);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  static Future<void> initCreateDir() async {
    await createDir(join(_filePath, 'database'));
    await createDir(join(_filePath, 'image'));
    await createDir(join(_filePath, 'audio'));
    await createDir(join(_filePath, 'video'));

    // 字体文件夹
    await createDir(join(_filePath, 'font'));
  }

  static Future<void> createDir(String path) async {
    Directory directory = Directory(path);
    await directory.create(recursive: true);
  }

  //计算指定路径下文件的大小
  static Future<Map<String, dynamic>> countSize() async {
    var cacheDir = await getApplicationCacheDirectory();
    var bytes = 0;
    var fileList = cacheDir.listSync(recursive: true);
    // 计算文件总大小（字节）
    for (var file in fileList) {
      if (file is File) {
        bytes += file.lengthSync();
      }
    }
    // 根据文件总大小选择合适的单位
    return bytesToUnits(bytes);
  }

  static Map<String, dynamic> bytesToUnits(int bytes) {
    // 根据文件总大小选择合适的单位
    if (bytes < 1024) {
      return {'size': bytes.toString(), 'unit': 'B', 'bytes': bytes};
    } else if (bytes < 1024 * 1024) {
      return {
        'size': (bytes / 1024).toStringAsFixed(2),
        'unit': 'KB',
        'bytes': bytes
      };
    } else if (bytes < 1024 * 1024 * 1024) {
      return {
        'size': (bytes / (1024 * 1024)).toStringAsFixed(2),
        'unit': 'MB',
        'bytes': bytes
      };
    } else {
      return {
        'size': (bytes / (1024 * 1024 * 1024)).toStringAsFixed(2),
        'unit': 'GB',
        'bytes': bytes
      };
    }
  }

  static Future<void> clearCache() async {
    var cacheDir = await getApplicationCacheDirectory();
    if (await cacheDir.exists()) {
      await cacheDir.delete(recursive: true);
    }
  }

  //文件导出
  static Future<String> zipFile(Map<String, dynamic> params) async {
    var zipPath = params['zipPath'] as String;
    var dataPath = params['dataPath'] as String;
    var zipEncoder = ZipFileEncoder();
    var datetime = DateTime.now();
    var fileName =
        join(zipPath, '心绪日记${datetime.toString().split(' ')[0]}备份.zip');
    final outputStream = OutputFileStream(fileName);
    zipEncoder.createWithBuffer(outputStream);
    //备份照片
    await zipEncoder.addDirectory(Directory(join(dataPath, 'image')));
    //备份音频
    await zipEncoder.addDirectory(Directory(join(dataPath, 'audio')));
    //备份视频
    await zipEncoder.addDirectory(Directory(join(dataPath, 'video')));
    //备份数据库
    await IsarUtil.exportIsar(
        dataPath, zipPath, '${datetime.millisecondsSinceEpoch}.isar');
    await zipEncoder.addFile(
        File(join(zipPath, '${datetime.millisecondsSinceEpoch}.isar')));
    await zipEncoder.close();
    return fileName;
  }

  //导入文件
  static Future<void> extractFile(String path) async {
    final inputStream = InputFileStream(path);
    //删除图片文件夹
    await deleteDir(join(_filePath, 'image'));
    //删除音频文件夹
    await deleteDir(join(_filePath, 'audio'));
    //删除视频文件夹
    await deleteDir(join(_filePath, 'video'));
    //重新创建图片文件夹
    await createDir(join(_filePath, 'image'));
    //重新创建音频文件夹
    await createDir(join(_filePath, 'audio'));
    //重新创建视频文件夹
    await createDir(join(_filePath, 'video'));
    var archive = ZipDecoder().decodeBuffer(inputStream);
    for (var file in archive.files) {
      //如果是数据库
      if (file.name.endsWith('.isar')) {
        final outputStream = OutputFileStream(join(_cachePath, 'old.isar'));
        file.writeContent(outputStream);
      } else {
        //图片
        final outputStream = OutputFileStream(join(_filePath, file.name));
        file.writeContent(outputStream);
      }
    }
    //复制数据库
    await IsarUtil.dataMigration(_cachePath);
  }

  static String getRealPath(String fileType, String fileName) {
    if (fileType == 'thumbnail') {
      var thumbnailName = 'thumbnail-${fileName.substring(6, 42)}.jpeg';
      return join(_filePath, 'video', thumbnailName);
    }
    return join(_filePath, fileType, fileName);
  }

  // 媒体库
  static Future<List<String>> getDirFilePath(String fileType) async {
    var path = join(_filePath, fileType);
    List<String> filePaths = [];
    Directory directory = Directory(path);
    if (await directory.exists()) {
      await for (var entity in directory.list()) {
        if (entity is File) {
          filePaths.add(entity.path);
        }
      }
    }
    return filePaths;
  }

  static Future<List<String>> getDirFileName(String fileType) async {
    var path = join(_filePath, fileType);
    List<String> fileNames = [];
    Directory directory = Directory(path);
    if (await directory.exists()) {
      await for (var entity in directory.list()) {
        if (entity is File) {
          fileNames.add(basename(entity.path));
        }
      }
    }
    return fileNames;
  }

  static Future<void> deleteMediaFiles(
      Set<String> files, String mediaType) async {
    for (var name in files) {
      final filePath = getRealPath(mediaType, name);
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  static String getCachePath(String fileName) {
    return join(_cachePath, fileName);
  }

  static String getErrorLogPath() {
    return join(_filePath, 'error.log');
  }

  static Future<void> cleanUpOldMediaFiles(
      Diary oldDiary, Diary newDiary) async {
    // 通用删除方法
    Future<void> deleteMediaFiles(
        List<String> oldFiles, List<String> newFiles, String type) async {
      final tasks = oldFiles
          .where((file) => !newFiles.contains(file))
          .map((file) => deleteFile(getRealPath(type, file)))
          .toList();
      await Future.wait(tasks);
    }

    // 删除旧的图片、视频和音频文件
    await deleteMediaFiles(oldDiary.imageName, newDiary.imageName, 'image');
    await deleteMediaFiles(oldDiary.videoName, newDiary.videoName, 'video');
    await deleteMediaFiles(oldDiary.audioName, newDiary.audioName, 'audio');
    await deleteMediaFiles(oldDiary.videoName, newDiary.videoName, 'thumbnail');
  }

  static Future<void> cleanFile(String dir) async {
    var isar = Isar.open(
      schemas: [DiarySchema, CategorySchema],
      directory: dir,
    );
    // 获取各类型的所有文件路径并转换为Set以提高查找效率
    final imageFiles =
        (await FileUtil.getDirFileName(MediaType.image.value)).toSet();
    final audioFiles =
        (await FileUtil.getDirFileName(MediaType.audio.value)).toSet();
    final videoFiles =
        (await FileUtil.getDirFileName(MediaType.video.value)).toSet();

    // 用于存储日记中引用的文件名的Set
    final usedImages = <String>{};
    final usedAudios = <String>{};
    final usedVideos = <String>{};

    // 获取日记总数
    final count = isar.diarys.count();

    // 分批获取日记并收集引用的文件名
    const batchSize = 50;
    for (int i = 0; i < count; i += batchSize) {
      final diaryList =
          await isar.diarys.where().findAllAsync(offset: i, limit: batchSize);
      for (var diary in diaryList) {
        usedImages.addAll(diary.imageName);
        usedAudios.addAll(diary.audioName);
        usedVideos.addAll(diary.videoName);
        for (var name in diary.videoName) {
          var thumbnailName = 'thumbnail-${name.substring(6, 42)}.jpeg';
          usedVideos.add(thumbnailName);
        }
      }
    }

    // 计算需要删除的文件
    final imagesToDelete = imageFiles.difference(usedImages);
    final audiosToDelete = audioFiles.difference(usedAudios);
    final videosToDelete = videoFiles.difference(usedVideos);

    // delete controller when need
    for (var path in audiosToDelete) {
      if (Bind.isRegistered<AudioPlayerLogic>(tag: path)) {
        Bind.delete<AudioPlayerLogic>(tag: path);
      }

      // 并行删除文件
      await Future.wait([
        FileUtil.deleteMediaFiles(imagesToDelete, MediaType.image.value),
        FileUtil.deleteMediaFiles(audiosToDelete, MediaType.audio.value),
        FileUtil.deleteMediaFiles(videosToDelete, MediaType.video.value),
      ]);
    }
  }
}
