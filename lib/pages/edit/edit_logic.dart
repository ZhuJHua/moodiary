import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:mood_diary/api/api.dart';
import 'package:mood_diary/common/models/isar/diary.dart';
import 'package:mood_diary/common/values/diary_type.dart';
import 'package:mood_diary/components/keyboard_listener/keyboard_listener.dart';
import 'package:mood_diary/components/quill_embed/text_indent.dart';
import 'package:mood_diary/components/quill_embed/video_embed.dart';
import 'package:mood_diary/router/app_routes.dart';
import 'package:mood_diary/src/rust/api/kmp.dart';
import 'package:mood_diary/utils/utils.dart';
import 'package:uuid/uuid.dart';

import '../../common/values/keyboard_state.dart';
import '../../components/quill_embed/audio_embed.dart';
import '../../components/quill_embed/image_embed.dart';
import 'edit_state.dart';

class EditLogic extends GetxController {
  final EditState state = EditState();

  //标签控制器
  late TextEditingController tagTextEditingController = TextEditingController();

  //标题
  late TextEditingController titleTextEditingController = TextEditingController();

  //编辑器控制器
  late QuillController quillController;

  //聚焦对象
  late FocusNode contentFocusNode = FocusNode();
  late FocusNode titleFocusNode = FocusNode();
  Timer? _timer;

  late final KeyboardObserver keyboardObserver;

  @override
  void onInit() {
    if (state.showWriteTime) _calculateDuration();
    keyboardObserver = KeyboardObserver(
        onHeightChanged: (_) {},
        onStateChanged: (state) {
          switch (state) {
            case KeyboardState.opening:
              break;
            case KeyboardState.closing:
              unFocus();
              break;
            case KeyboardState.closed:
              break;
            case KeyboardState.unknown:
              break;
          }
        });
    keyboardObserver.start();
    super.onInit();
  }

  @override
  void onReady() async {
    await _initEdit();
    quillController.addListener(_listenCount);
    if (state.firstLineIndent) {
      quillController.document.changes.listen((change) {
        var operations = change.change.operations;
        var lastOperation = operations.last;
        if (lastOperation.key == 'insert' && lastOperation.value == '\n') {
          insertNewLine();
        }
      });
    }
    super.onReady();
  }

  @override
  void onClose() {
    keyboardObserver.stop();
    tagTextEditingController.dispose();
    titleTextEditingController.dispose();
    titleFocusNode.dispose();
    contentFocusNode.dispose();
    quillController.dispose();
    _timer?.cancel();
    _timer = null;
    super.onClose();
  }

  Future<void> _initEdit() async {
    //如果是新增，更具不同的分类展示不同的操作
    if (Get.arguments.runtimeType == List<Object?>) {
      // 配置日记类型
      state.type = Get.arguments[0] as DiaryType;
      quillController = QuillController.basic();
      state.currentDiary = Diary();
      if (state.firstLineIndent) insertNewLine();
      if (state.autoWeather) {
        unawaited(getPositionAndWeather());
      }
      if (state.autoCategory) selectCategory(Get.arguments[1] as String?);
    } else {
      //如果是编辑，将日记对象赋值
      state.isNew = false;
      var oldDiary = Get.arguments as Diary;
      state.type = DiaryType.values.firstWhere((type) => type.value == oldDiary.type);
      state.currentDiary = oldDiary;
      // 获取分类名称
      if (oldDiary.categoryId != null) {
        state.categoryName = Utils().isarUtil.getCategoryName(oldDiary.categoryId!)!.categoryName;
      }
      // 初始化标题控制器
      titleTextEditingController.text = oldDiary.title;
      // 待替换的字符串map
      Map<String, String> replaceMap = {};
      //临时拷贝一份图片数据
      for (var name in oldDiary.imageName) {
        // 生成一个临时文件
        var xFile = XFile(Utils().fileUtil.getRealPath('image', name));
        replaceMap[name] = xFile.path;
        state.imageFileList.add(xFile);
      }
      //临时拷贝一份拷贝音频数据到缓存目录
      for (var name in oldDiary.audioName) {
        state.audioNameList.add(name);
        await File(Utils().fileUtil.getRealPath('audio', name)).copy(Utils().fileUtil.getCachePath(name));
      }
      //临时拷贝一份视频数据，别忘记了缩略图
      for (var name in oldDiary.videoName) {
        // 生成一个临时文件
        var videoXFile = XFile(Utils().fileUtil.getRealPath('video', name));
        replaceMap[name] = videoXFile.path;
        state.videoFileList.add(videoXFile);
      }
      quillController = QuillController(
          document:
              Document.fromJson(jsonDecode(await Kmp.replaceWithKmp(text: oldDiary.content, replacements: replaceMap))),
          selection: const TextSelection.collapsed(offset: 0));
      state.totalCount.value = _toPlainText().length;
    }
    state.isInit = true;
    update(['body']);
  }

  //计算写作时长
  void _calculateDuration() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      state.duration += const Duration(seconds: 1);
      state.durationString.value = state.duration.toString().split('.')[0].padLeft(8, '0');
    });
  }

  String _toPlainText() {
    return quillController.document.toPlainText([
      ImageEmbedBuilder(isEdit: true),
      VideoEmbedBuilder(isEdit: true),
      AudioEmbedBuilder(isEdit: true),
      TextIndentEmbedBuilder(isEdit: true),
    ]).trim();
  }

  void _listenCount() {
    state.totalCount.value = _toPlainText().length;
  }

  // 插入换行时自动首行缩进
  void insertNewLine() {
    final index = quillController.selection.baseOffset;
    final length = quillController.selection.extentOffset - index;
    quillController.replaceText(index, length, const TextIndentEmbed('2'), TextSelection.collapsed(offset: index + 1));
  }

  void insertNewImage({required String imagePath}) {
    final imageBlock = ImageBlockEmbed.fromName(imagePath);
    final index = quillController.selection.baseOffset;
    final length = quillController.selection.extentOffset - index;
    quillController.replaceText(index, length, imageBlock, TextSelection.collapsed(offset: index + 1));
  }

  void insertNewVideo({required String videoPath}) {
    final videoBlock = VideoBlockEmbed.fromName(videoPath);
    final index = quillController.selection.baseOffset;
    final length = quillController.selection.extentOffset - index;
    quillController.replaceText(index, length, videoBlock, TextSelection.collapsed(offset: index + 1));
  }

  Future<void> addNewImage(XFile xFile) async {
    state.imageFileList.add(xFile);
    insertNewImage(imagePath: xFile.path);
    update(['Image']);
  }

  //单张照片
  Future<void> pickPhoto(ImageSource imageSource) async {
    //获取一张图片
    final XFile? photo = await Utils().mediaUtil.pickPhoto(imageSource);
    if (photo != null) {
      Get.backLegacy();
      await addNewImage(photo);
    } else {
      Utils().noticeUtil.showToast('取消图片选择');
    }
  }

  //画图照片
  Future<void> pickDraw(Uint8List dataList) async {
    Get.backLegacy();
    var path = Utils().fileUtil.getCachePath('${const Uuid().v7()}.png');
    addNewImage(XFile.fromData(dataList, path: path)..saveTo(path));
  }

  //网络图片
  Future<void> networkImage() async {
    Get.backLegacy();
    Utils().noticeUtil.showToast('图片获取中');
    var imageUrl = await Api().updateImageUrl();
    if (imageUrl == null) {
      Utils().noticeUtil.showToast('图片获取失败');
      return;
    }
    var imageData = await Api().getImageData(imageUrl.first);
    if (imageData == null) {
      Utils().noticeUtil.showToast('图片获取失败');
      return;
    }
    var path = Utils().fileUtil.getCachePath('${const Uuid().v7()}.png');
    addNewImage(XFile.fromData(imageData, path: path)..saveTo(path));
  }

  //相册选择多张照片
  Future<void> pickMultiPhoto() async {
    //获取一堆照片
    List<XFile> photoList = await Utils().mediaUtil.pickMultiPhoto(null);
    if (photoList.isNotEmpty) {
      //关闭dialog
      Get.backLegacy();
      // if (photoList.length > 10 - state.imageFileList.length) {
      //   photoList = photoList.sublist(0, 10 - state.imageFileList.length);
      // }
      for (var photo in photoList) {
        addNewImage(photo);
      }
    } else {
      //关闭dialog
      Get.backLegacy();
      //弹出一个提示
      Utils().noticeUtil.showToast('取消图片选择');
    }
  }

  Future<void> addNewVideo(XFile xFile) async {
    //视频list中新增一个
    state.videoFileList.add(xFile);
    insertNewVideo(videoPath: xFile.path);
    update(['Video']);
  }

  //选择视频
  Future<void> pickVideo(ImageSource imageSource) async {
    // 获取一个视频
    XFile? video = await Utils().mediaUtil.pickVideo(imageSource);
    if (video != null) {
      Get.backLegacy();
      await addNewVideo(video);
    } else {
      Utils().noticeUtil.showToast('取消视频选择');
    }
  }

  //预览图片
  void toPhotoView(List<String> imagePath, int index) {
    Get.toNamed(AppRoutes.photoPage, arguments: [imagePath, index]);
  }

  //预览视频
  void toVideoView(List<String> videoPath, int index) {
    Get.toNamed(AppRoutes.videoPage, arguments: [videoPath, index]);
  }

  //删除图片
  void deleteImage({required String path}) async {
    // 移除这个图片
    state.imageFileList.removeWhere((file) => file.path == path);
    await Utils().fileUtil.deleteFile(path);
    //Get.backLegacy();
    Utils().noticeUtil.showToast('删除成功');
    update(['Image']);
  }

  //删除视频
  void deleteVideo(index) async {
    var videoFile = state.videoFileList.removeAt(index);
    await Utils().fileUtil.deleteFile(videoFile.path);
    Get.backLegacy();
    Utils().noticeUtil.showToast('删除成功');
    update(['Video']);
  }

  //长按设置封面
  void setCover(int index) {
    var coverFile = state.imageFileList[index];
    state.imageFileList
      ..removeAt(index)
      ..insert(0, coverFile);
    Utils().noticeUtil.showToast('设置第${index + 1}张图片为封面');
    update(['Image']);
  }

  //获取封面颜色
  Future<int?> getCoverColor() async {
    if (state.imageFileList.isNotEmpty) {
      return await Utils().mediaUtil.getColorScheme(FileImage(File(state.imageFileList.first.path)));
    } else {
      return null;
    }
  }

  //获取封面比例
  Future<double?> getCoverAspect() async {
    //如果有封面就获取
    if (state.imageFileList.isNotEmpty) {
      return await Utils().mediaUtil.getImageAspectRatio(FileImage(File(state.imageFileList.first.path)));
    } else {
      return null;
    }
  }

  //保存日记
  Future<void> saveDiary() async {
    state.isSaving = true;
    update(['modal']);
    // 根据文本中的实际内容移除不需要的资源
    var originContent = jsonEncode(quillController.document.toDelta().toJson());
    var needImage = await Kmp.findMatches(text: originContent, patterns: state.imagePathList);
    var needVideo = await Kmp.findMatches(text: originContent, patterns: state.videoPathList);
    var needAudio = await Kmp.findMatches(text: originContent, patterns: state.audioNameList);
    state.imageFileList.removeWhere((file) => !needImage.contains(file.path));
    state.videoFileList.removeWhere((file) => !needVideo.contains(file.path));
    state.audioNameList.removeWhere((name) => !needAudio.contains(name));
    // 保存图片
    var imageNameMap = await Utils().mediaUtil.saveImages(imageFileList: state.imageFileList);
    // 保存视频
    var videoNameMap = await Utils().mediaUtil.saveVideo(videoFileList: state.videoFileList);
    //保存录音
    var audioNameMap = await Utils().mediaUtil.saveAudio(state.audioNameList);
    var content = await Kmp.replaceWithKmp(
        text: originContent, replacements: {...imageNameMap, ...videoNameMap, ...audioNameMap});
    state.currentDiary
      ..title = titleTextEditingController.text
      ..content = content
      ..type = state.type.value
      ..lastModified = DateTime.now()
      ..contentText = _toPlainText()
      ..audioName = state.audioNameList
      ..imageName = imageNameMap.values.toList()
      ..videoName = videoNameMap.values.toList()
      ..imageColor = await getCoverColor()
      ..aspect = await getCoverAspect();

    await Utils().isarUtil.updateADiary(state.currentDiary);
    state.isNew ? Get.backLegacy(result: state.currentDiary.categoryId ?? '') : Get.backLegacy(result: 'changed');
    if (Utils().webDavUtil.hasOption) unawaited(Utils().webDavUtil.uploadSingleDiary(state.currentDiary));
    Utils().noticeUtil.showToast(state.isNew ? '保存成功' : '修改成功');
  }

  DateTime? oldTime;

  void handleBack() {
    DateTime currentTime = DateTime.now();
    if (oldTime != null && currentTime.difference(oldTime!) < const Duration(seconds: 3)) {
      Get.backLegacy();
    } else {
      oldTime = currentTime;
      Utils().noticeUtil.showToast('再滑一次退出');
    }
  }

  Future<void> changeDate() async {
    var nowDateTime = await showDatePicker(
      context: Get.context!,
      initialDate: state.currentDiary.time,
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.day,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      firstDate: DateTime.now().subtract(const Duration(days: 31)),
    );
    if (nowDateTime != null) {
      state.currentDiary.time =
          state.currentDiary.time.copyWith(year: nowDateTime.year, month: nowDateTime.month, day: nowDateTime.day);
      update(['Date']);
    }
  }

  Future<void> changeTime() async {
    var nowTime =
        await showTimePicker(context: Get.context!, initialTime: TimeOfDay.fromDateTime(state.currentDiary.time));
    if (nowTime != null) {
      state.currentDiary.time = state.currentDiary.time.copyWith(hour: nowTime.hour, minute: nowTime.minute);
      update(['Date']);
    }
  }

  void unFocus() {
    titleFocusNode.unfocus();
    contentFocusNode.unfocus();
  }

  //去画画
  void toDrawPage() {
    Get.toNamed(AppRoutes.drawPage);
  }

  void changeRate(value) {
    state.currentDiary.mood = value;
    update(['Mood']);
  }

  //获取天气，同时获取定位
  Future<void> getPositionAndWeather() async {
    var key = Utils().prefUtil.getValue<String>('qweatherKey');
    if (key == null) return;

    state.isProcessing = true;
    update(['Weather']);

    // 获取定位
    var position = await Api().updatePosition();
    if (position == null) {
      _handleError('定位失败');
      return;
    }

    state.currentDiary.position = position;

    // 获取天气
    var weather = await Api().updateWeather(
      position: LatLng(double.parse(position[0]), double.parse(position[1])),
    );

    if (weather == null) {
      _handleError('天气获取失败');
      return;
    }

    state.currentDiary.weather = weather;
    state.isProcessing = false;
    Utils().noticeUtil.showToast('获取成功');
    update(['Weather']);
  }

  void _handleError(String message) {
    state.isProcessing = false;
    Utils().noticeUtil.showToast(message);
    update(['Weather']);
  }

  //获取音频名称
  void setAudioName(String name) {
    state.audioNameList.add(name);
    final audioBlock = AudioBlockEmbed.fromName(name);
    final index = quillController.selection.baseOffset;
    final length = quillController.selection.extentOffset - index;
    // 插入音频 Embed
    quillController.replaceText(index, length, audioBlock, TextSelection.collapsed(offset: index + 1));
    update(['Audio']);
  }

  //删除音频
  Future<void> deleteAudio(String path) async {
    // 删除文件
    await Utils().fileUtil.deleteFile(path);
    // 删除对应的组件
    state.audioNameList.removeWhere((name) => path.endsWith(name));
    update(['Audio']);
    Utils().noticeUtil.showToast('删除成功');
  }

  void cancelAddTag() {
    Get.backLegacy();
    tagTextEditingController.clear();
  }

  //添加一个标签
  void addTag() {
    Get.backLegacy();
    if (tagTextEditingController.text.isNotEmpty) {
      state.currentDiary.tags.add(tagTextEditingController.text);
      tagTextEditingController.clear();
      update(['Tag']);
    }
  }

  //移除一个标签
  void removeTag(index) {
    state.currentDiary.tags.removeAt(index);
    update(['Tag']);
  }

  void selectCategory(String? id) {
    state.currentDiary.categoryId = id;
    if (id == null) {
      state.categoryName = '';
    } else {
      var category = Utils().isarUtil.getCategoryName(id);
      if (category != null) {
        state.categoryName = category.categoryName;
      }
    }
    update(['CategoryName']);
  }
}
