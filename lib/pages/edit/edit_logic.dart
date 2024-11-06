import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:mood_diary/api/api.dart';
import 'package:mood_diary/common/models/isar/diary.dart';
import 'package:mood_diary/common/values/keyboard_state.dart';
import 'package:mood_diary/router/app_routes.dart';
import 'package:mood_diary/utils/utils.dart';
import 'package:uuid/uuid.dart';

import 'edit_state.dart';

class EditLogic extends GetxController with WidgetsBindingObserver {
  final EditState state = EditState();

  //分类控制器
  late TextEditingController tagTextEditingController = TextEditingController();

  //标题
  late TextEditingController titleTextEditingController = TextEditingController();

  late PageController pageController = PageController();

  //编辑器控制器
  late QuillController quillController = QuillController.basic();

  //聚焦对象
  late FocusNode contentFocusNode = FocusNode();
  late FocusNode titleFocusNode = FocusNode();
  List<double> heightList = [];

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      var height = MediaQuery.viewInsetsOf(Get.context!).bottom;
      if (heightList.isNotEmpty && height != heightList.last) {
        if (height > heightList.last && state.keyboardState != KeyboardState.opening) {
          state.keyboardState = KeyboardState.opening;
          //正在打开
        } else if (height < heightList.last && state.keyboardState != KeyboardState.closing) {
          state.keyboardState = KeyboardState.closing;
          //正在关闭
          unFocus();
        }
      }
      // 只在高度变化时记录高度
      if (heightList.isEmpty || height != heightList.last) {
        heightList.add(height);
      }
      // 当高度为0且键盘经历了开启关闭过程时，认为键盘已完全关闭
      if (height == 0 && state.keyboardState != KeyboardState.closed) {
        state.keyboardState = KeyboardState.closed;
        heightList.clear();
        //已经关闭
      }
    });
    super.didChangeMetrics();
  }

  @override
  void onInit() {
    //如果是新增
    WidgetsBinding.instance.addObserver(this);
    if (Get.arguments == 'new') {
      state.currentDiary = Diary();
      if (Utils().prefUtil.getValue<bool>('autoWeather') == true) {
        unawaited(getWeather());
      }
    } else {
      //如果是编辑，将日记对象赋值
      state.isNew = false;
      var oldDiary = Get.arguments as Diary;
      state.currentDiary = oldDiary;
      // 初始化quill控制器
      quillController = QuillController(
          document: Document.fromJson(jsonDecode(oldDiary.content)),
          selection: const TextSelection.collapsed(offset: 0));
      // 获取分类名称
      if (oldDiary.categoryId != null) {
        state.categoryName = Utils().isarUtil.getCategoryName(oldDiary.categoryId!)!.categoryName;
      }
      // 初始化标题控制器
      titleTextEditingController = TextEditingController(text: oldDiary.title);
      //临时拷贝一份图片数据
      for (var name in oldDiary.imageName) {
        state.imageFileList.add(XFile(Utils().fileUtil.getRealPath('image', name)));
      }
      //临时拷贝一份拷贝音频数据到缓存目录
      for (var name in oldDiary.audioName) {
        File(Utils().fileUtil.getRealPath('audio', name)).copy(Utils().fileUtil.getCachePath(name));
      }
      //临时拷贝一份视频数据，别忘记了缩略图
      for (var name in oldDiary.videoName) {
        state.videoFileList.add(XFile(Utils().fileUtil.getRealPath('video', name)));
        state.videoThumbnailFileList.add(XFile(Utils().fileUtil.getRealPath('thumbnail', name)));
      }
      state.totalCount = quillController.document.toPlainText().trim().length;
    }
    update(['All']);
    super.onInit();
  }

  @override
  void onReady() {
    listenCount();
    super.onReady();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    tagTextEditingController.dispose();
    titleTextEditingController.dispose();
    titleFocusNode.dispose();
    contentFocusNode.dispose();
    pageController.dispose();
    quillController.dispose();
    super.onClose();
  }

  void listenCount() {
    quillController.addListener(() {
      state.totalCount = quillController.document.toPlainText().trim().length;
      update(['Count']);
    });
  }

  Future<void> addNewImage(XFile xFile) async {
    //图片列表中新增一个
    state.imageFileList.add(xFile);
    update(['Image']);
  }

  //单张照片
  Future<void> pickPhoto(ImageSource imageSource) async {
    //获取一张图片
    final XFile? photo = await Utils().mediaUtil.pickPhoto(imageSource);
    if (photo != null) {
      //关闭dialog
      Get.backLegacy();
      await addNewImage(photo);
    } else {
      //关闭dialog
      Get.backLegacy();
      //弹出一个提示
      Utils().noticeUtil.showToast('取消图片选择');
    }
  }

  //画图照片
  Future<void> pickDraw(Uint8List dataList) async {
    var path = Utils().fileUtil.getCachePath('${const Uuid().v7()}.jpg');
    await addNewImage(XFile.fromData(dataList, path: path)..saveTo(path));
  }

  //网络图片
  Future<void> networkImage() async {
    //关闭dialog
    Get.backLegacy();
    Utils().noticeUtil.showToast('图片获取中');
    var imageUrl = await Api().updateImageUrl();
    if (imageUrl != null) {
      var imageData = await Api().getImageData(imageUrl.first);
      if (imageData != null) {
        var path = Utils().fileUtil.getCachePath('${const Uuid().v7()}.jpg');
        addNewImage(XFile.fromData(imageData, path: path)..saveTo(path));
      }
    }
  }

  //相册选择多张照片
  Future<void> pickMultiPhoto() async {
    //获取一堆照片,最多10张
    List<XFile> photoList = await Utils().mediaUtil.pickMultiPhoto(10);
    if (photoList.isNotEmpty) {
      //关闭dialog
      Get.backLegacy();
      if (photoList.length > 10 - state.imageFileList.length) {
        photoList = photoList.sublist(0, 10 - state.imageFileList.length);
      }
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
    //获取缩略图
    String fileName = '${const Uuid().v7()}.jpeg';
    if (await Utils().mediaUtil.getVideoThumbnail(xFile, Utils().fileUtil.getCachePath(fileName))) {
      state.videoThumbnailFileList.add(XFile(Utils().fileUtil.getCachePath(fileName)));
    }
    //视频list中新增一个
    state.videoFileList.add(xFile);
    update(['Video']);
  }

  //选择视频
  Future<void> pickVideo(ImageSource imageSource) async {
    XFile? video = await Utils().mediaUtil.pickVideo(imageSource);
    if (video != null) {
      //关闭dialog
      Get.backLegacy();
      await addNewVideo(video);
    } else {
      //关闭dialog
      Get.backLegacy();
      //弹出一个提示
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
  void deleteImage(index) async {
    var imageFile = state.imageFileList.removeAt(index);
    await Utils().fileUtil.deleteFile(imageFile.path);
    Get.backLegacy();
    Utils().noticeUtil.showToast('删除成功');
    update(['Image']);
  }

  //删除视频
  void deleteVideo(index) async {
    var videoFile = state.videoFileList.removeAt(index);
    var thumbnailFile = state.videoThumbnailFileList.removeAt(index);
    await Utils().fileUtil.deleteFile(videoFile.path);
    await Utils().fileUtil.deleteFile(thumbnailFile.path);
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
    Get.dialog(SimpleDialog(
      children: [
        Lottie.asset(
          'assets/lottie/file_process.json',
          addRepaintBoundary: true,
          width: 200,
          height: 200,
          frameRate: FrameRate.max,
        ),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [Text('处理中')],
        )
      ],
    ));
    //保存图片
    var imageNameList = await Utils().mediaUtil.saveImages(imageFileList: state.imageFileList);
    //保存视频
    var videoNameList = await Utils()
        .mediaUtil
        .saveVideo(videoFileList: state.videoFileList, videoThumbnailFileList: state.videoThumbnailFileList);
    //保存录音
    await Utils().mediaUtil.saveAudio(state.audioNameList);
    state.currentDiary
      ..title = titleTextEditingController.text
      ..content = jsonEncode(quillController.document.toDelta().toJson())
      ..contentText = quillController.document.toPlainText().trim()
      ..audioName = state.audioNameList
      ..imageName = imageNameList
      ..videoName = videoNameList
      ..imageColor = await getCoverColor()
      ..aspect = await getCoverAspect();
    await Utils().isarUtil.updateADiary(state.currentDiary);
    Get.close();
    state.isNew ? Get.backLegacy(result: state.currentDiary.categoryId ?? '') : Get.backLegacy(result: 'changed');
    Utils().noticeUtil.showToast(state.isNew ? '保存成功' : '修改成功');
  }

  // void handleBack() {
  //   DateTime currentTime = DateTime.now();
  //   if (state.oldTime != null && currentTime.difference(state.oldTime!) < const Duration(seconds: 3)) {
  //     Get.backLegacy();
  //   } else {
  //     state.oldTime = currentTime;
  //     Utils().noticeUtil.showToast('再滑一次退出');
  //   }
  // }

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
    Get.backLegacy();
    Get.toNamed(AppRoutes.drawPage);
  }

  void changeRate(value) {
    state.currentDiary.mood = value;
    update(['Mood']);
  }

  //获取天气
  Future<void> getWeather() async {
    var key = Utils().prefUtil.getValue<String>('qweatherKey');
    if (key != null) {
      state.isProcessing = true;
      update();
      var res = await Api().updateWeather();
      if (res != null) {
        state.currentDiary.weather = res;
        state.isProcessing = false;
        Utils().noticeUtil.showToast('获取成功');
        update(['Weather']);
      }
    }
  }

  //获取音频名称
  void setAudioName(String name) {
    state.audioNameList.add(name);
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
    Utils().logUtil.printInfo(id);
    if (id == null) {
      state.categoryName = '';
    } else {
      var category = Utils().isarUtil.getCategoryName(id);
      if (category != null) {
        state.categoryName = category.categoryName;
        update(['Category']);
      }

      Utils().logUtil.printInfo(state.categoryName);
    }
    update(['Category']);
  }

  void selectTabView(index) {
    state.tabIndex = index;
    update(['NavigationBar']);
    pageController.jumpToPage(index);
  }
}
