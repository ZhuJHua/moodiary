import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mood_diary/api/api.dart';
import 'package:mood_diary/common/models/isar/diary.dart';
import 'package:mood_diary/common/values/keyboard_state.dart';
import 'package:mood_diary/router/app_routes.dart';
import 'package:mood_diary/utils/utils.dart';
import 'package:uuid/uuid.dart';

import 'edit_state.dart';

class EditLogic extends GetxController with GetSingleTickerProviderStateMixin, WidgetsBindingObserver {
  final EditState state = EditState();

  //分类控制器
  late TextEditingController tagTextEditingController = TextEditingController();

  //标题
  late TextEditingController titleTextEditingController = TextEditingController();

  late TabController tabController = TabController(length: 2, vsync: this);

  //编辑器控制器
  late QuillController quillController = QuillController.basic();

  //聚焦对象
  late FocusNode focusNode = FocusNode();
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
  void onInit() async {
    // TODO: implement onInit
    //如果是新增
    WidgetsBinding.instance.addObserver(this);
    if (Get.arguments == 'new') {
      state.isNew = true;
    } else {
      //如果是编辑
      state.oldDiary = Get.arguments;
      state.content = state.oldDiary!.content;
      quillController = QuillController(
          document: Document.fromJson(jsonDecode(state.content)), selection: const TextSelection.collapsed(offset: 0));
      state.currentDateTime = state.oldDiary!.time;
      state.currentMoodRate = state.oldDiary!.mood.obs;
      state.currentWeather = state.oldDiary!.weather;
      state.audioNameList = state.oldDiary!.audioName;
      state.videoNameList = state.oldDiary!.videoName;
      state.tagList = state.oldDiary!.tags;
      state.imageNameList = state.oldDiary!.imageName;
      state.categoryId = state.oldDiary!.categoryId;
      titleTextEditingController = TextEditingController(text: state.oldDiary!.title);
      if (state.categoryId != null) {
        state.categoryName = (await Utils().isarUtil.getCategoryName(state.categoryId!))!.categoryName;
      }
      //拷贝图片数据
      for (var name in state.imageNameList) {
        state.imageList.add(File(Utils().fileUtil.getRealPath('image', name)).readAsBytesSync());
      }
      //拷贝音频数据
      for (var name in state.audioNameList) {
        File(Utils().fileUtil.getRealPath('audio', name)).copy(Utils().fileUtil.getCachePath(name));
      }
    }
    update();
    super.onInit();
  }

  @override
  void onReady() {
    // TODO: implement onReady

    super.onReady();
  }

  @override
  void onClose() {
    // TODO: implement onClose
    WidgetsBinding.instance.removeObserver(this);
    tagTextEditingController.dispose();
    titleTextEditingController.dispose();
    tabController.dispose();
    quillController.dispose();
    super.onClose();
  }

  Future<void> addNewImage(Uint8List data) async {
    Utils().noticeUtil.showToast('图片处理中');
    //压缩图片
    var newImage = await Utils().mediaUtil.compressImage(data);
    //图片列表中新增一个
    state.imageList.add(newImage);
    //名称列表中新增一个，使用 uuid 作为名称
    state.imageNameList.add('image-${const Uuid().v7()}.webp');
    update();
    Utils().noticeUtil.showToast('处理完成');
  }

  //单张照片
  Future<void> pickPhoto(ImageSource imageSource) async {
    //获取一张图片
    final XFile? photo = await Utils().mediaUtil.pickPhoto(imageSource);
    if (photo != null) {
      //关闭dialog
      Get.backLegacy();
      await addNewImage(await photo.readAsBytes());
    } else {
      //关闭dialog
      Get.backLegacy();
      //弹出一个提示
      Utils().noticeUtil.showToast('取消图片选择');
    }
  }

  //画图照片
  Future<void> pickDraw(dataList) async {
    await addNewImage(dataList);
  }

  //网络图片
  Future<void> networkImage() async {
    //关闭dialog
    Get.backLegacy();
    Utils().noticeUtil.showToast('图片获取中');
    var imageUrl = await Api().updateImageUrl();
    if (imageUrl != null) {
      var imageData = await Api().getImageData(imageUrl.first);
      addNewImage(imageData!);
    }
  }

  //相册选择多张照片
  Future<void> pickMultiPhoto() async {
    //获取一堆照片,最多10张
    List<XFile> photoList = await Utils().mediaUtil.pickMultiPhoto(10);
    if (photoList.isNotEmpty) {
      //关闭dialog
      Get.backLegacy();
      if (photoList.length > 10 - state.imageList.length) {
        photoList = photoList.sublist(0, 10 - state.imageList.length);
      }
      for (var photo in photoList) {
        addNewImage(await photo.readAsBytes());
      }
    } else {
      //关闭dialog
      Get.backLegacy();
      //弹出一个提示
      Utils().noticeUtil.showToast('取消图片选择');
      update();
    }
  }

  //删除图片
  void deleteImage(index) {
    //如果是封面，还要删掉封面
    if (state.coverImageName == state.imageNameList[index]) {
      state.coverImage = null;
      state.coverImageName = null;
    }
    state.imageList.removeAt(index);
    var fileName = state.imageNameList.removeAt(index);
    //如果不是新增，还要删除源文件
    if (state.isNew == false) {
      Utils().fileUtil.deleteFile(Utils().fileUtil.getRealPath('image', fileName));
    }
    Get.backLegacy();
    Utils().noticeUtil.showToast('删除成功');
    update();
  }

  //长按设置封面
  void setCover(int index) {
    state.coverImage = state.imageList[index];
    state.coverImageName = state.imageNameList[index];
    Utils().noticeUtil.showToast('设置第${index + 1}张图片为封面');
    update();
  }

  void checkCover() {
    //如果没有手动指定封面,默认第一张

    if (state.coverImage == null) {
      //如果图片都没有，从默认封面获取颜色
      if (state.imageList.isEmpty) {
        return;
      } else {
        state.coverImage = state.imageList.first;
        state.coverImageName = state.imageNameList.first;
      }
    } else {
      //如果不为空，说明手动指定了，那么替换位置到首部
      state.imageList
        ..remove(state.coverImage)
        ..insert(0, state.coverImage!);
      state.imageNameList
        ..remove(state.coverImageName)
        ..insert(0, state.coverImageName!);
    }
  }

  //获取封面颜色
  Future<int?> getCoverColor() async {
    if (state.imageList.isNotEmpty) {
      return (await Utils().mediaUtil.getColorScheme(MemoryImage(state.imageList.first))).value;
    } else {
      return null;
    }
  }

  //获取封面比例
  Future<double?> getCoverAspect() async {
    //如果有封面就获取
    if (state.imageList.isNotEmpty) {
      return await Utils().mediaUtil.getImageAspectRatio(MemoryImage(state.imageList.first));
    } else {
      return null;
    }
  }

  //保存日记
  Future<void> saveDiary() async {
    if (checkIsNotEmpty()) {
      //检查封面
      checkCover();
      var diary = Diary(
        id: '',
        categoryId: state.categoryId,
        title: state.title,
        content: state.content,
        contentText: quillController.document.toPlainText().trim(),
        time: state.currentDateTime,
        show: true,
        mood: state.currentMoodRate.value,
        weather: [],
        imageName: state.imageNameList,
        audioName: state.audioNameList,
        videoName: state.videoNameList,
        tags: state.tagList,
        imageColor: await getCoverColor(),
        aspect: await getCoverAspect(),
      );
      //先把日记插入到数据库中
      await Utils().isarUtil.insertADiary(diary);
      //保存图片
      await Utils().mediaUtil.saveImages(Map.fromIterables(state.imageNameList, state.imageList));
      //保存录音
      await Utils().mediaUtil.savaAudio(state.audioNameList);
      Get.backLegacy();
      Utils().noticeUtil.showToast('保存成功');
    } else {
      Utils().noticeUtil.showToast('还有东西没有填写');
    }
  }

  //更新日记
  Future<void> updateDiary() async {
    if (checkIsNotEmpty()) {
      //检查封面
      checkCover();
      var diary = Diary(
        id: state.oldDiary!.id,
        categoryId: state.categoryId,
        title: state.title,
        content: state.content,
        contentText: quillController.document.toPlainText(),
        time: state.currentDateTime,
        show: true,
        mood: state.currentMoodRate.value,
        weather: [],
        imageName: state.imageNameList,
        audioName: state.audioNameList,
        videoName: state.videoNameList,
        tags: state.tagList,
        imageColor: await getCoverColor(),
        aspect: await getCoverAspect(),
      );
      //更新数据库中的日记
      await Utils().isarUtil.updateADiary(diary);
      //保存图片
      await Utils().mediaUtil.saveImages(Map.fromIterables(state.imageNameList, state.imageList));
      //保存录音
      await Utils().mediaUtil.savaAudio(state.audioNameList);
      Get.backLegacy(result: 'changed');
      Utils().noticeUtil.showToast('修改成功');
    }
  }

  void handleBack() {
    DateTime currentTime = DateTime.now();
    if (state.oldTime != null && currentTime.difference(state.oldTime!) < const Duration(seconds: 3)) {
      Get.backLegacy();
    } else {
      state.oldTime = currentTime;
      Utils().noticeUtil.showToast('再滑一次退出');
    }
  }

  //日期选择器
  void selectedDate(DateTime now) {
    //如果选择的是当天，变回去
    if (state.oldDateTime.year == now.year &&
        state.oldDateTime.month == now.month &&
        state.oldDateTime.day == now.day) {
      state.currentDateTime = state.oldDateTime;
    } else {
      state.currentDateTime = state.currentDateTime.copyWith(year: now.year, month: now.month, day: now.day);
    }
    update();
  }

  Future<void> changeDate() async {
    var nowDateTime = await showDatePicker(
      context: Get.context!,
      initialDate: state.currentDateTime,
      lastDate: state.oldDateTime,
      initialDatePickerMode: DatePickerMode.day,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      firstDate: state.oldDateTime.subtract(const Duration(days: 31)),
    );
    if (nowDateTime != null) {
      selectedDate(nowDateTime);
    }
  }

  //时间选择器
  void selectedTime(TimeOfDay now) {
    state.currentDateTime = state.currentDateTime.copyWith(hour: now.hour, minute: now.minute);
    update();
  }

  Future<void> changeTime() async {
    var nowTime =
        await showTimePicker(context: Get.context!, initialTime: TimeOfDay.fromDateTime(state.currentDateTime));
    if (nowTime != null) {
      selectedTime(nowTime);
    }
  }

  //监听文本输入
  void updateContent(String value) {
    state.content = value;
    update();
  }

  bool checkIsNotEmpty() {
    if (quillController.document.isEmpty()) {
      return false;
    } else {
      //内容序列化为json
      state.content = jsonEncode(quillController.document.toDelta().toJson());
      //如果有title保存到数据库
      if (titleTextEditingController.text.isNotEmpty) {
        state.title = titleTextEditingController.text;
      }
      return true;
    }
  }

  //点击其他地方失去焦点
  void unFocus() {
    focusNode.unfocus();
  }

  //去画画
  void toDrawPage() {
    Get.backLegacy();
    Get.toNamed(AppRoutes.drawPage);
  }

  void changeRate(value) {
    state.currentMoodRate.value = value;
  }

  void changeColor(value) {}

  //获取天气
  Future<void> getWeather() async {
    state.isProcessing = true;
    update();
    var res = await Api().updateWeather();
    if (res != null) {
      state.currentWeather = res;
      state.isProcessing = false;
      Utils().noticeUtil.showToast('获取成功');
      update();
    }
  }

  //获取音频名称
  void setAudioName(String name) {
    state.audioNameList.add(name);
    update();
  }

  //删除音频
  Future<void> deleteAudio(int index) async {
    await Utils().fileUtil.deleteFile(Utils().fileUtil.getRealPath('audio', state.audioNameList[index]));
    state.audioNameList.removeAt(index);
    update();
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
      state.tagList.add(tagTextEditingController.text);
      tagTextEditingController.clear();
      update();
    }
  }

  //移除一个标签
  void removeTag(index) {
    state.tagList.removeAt(index);
    update();
  }

  void selectCategory(String id) async {
    state.categoryId = id;
    var category = await Utils().isarUtil.getCategoryName(id);
    if (category != null) {
      state.categoryName = category.categoryName;
    }
    update();
  }

  void selectTabView(index) {
    state.tabIndex.value = index;
    tabController.animateTo(index, duration: const Duration(milliseconds: 100), curve: Curves.easeInOut);
  }
}
