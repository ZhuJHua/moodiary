import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ImageState {
  late List<String> imagePathList;

  //当前图片的的位置
  late int imageIndex;

  //控制器
  late PageController pageController;

  ImageState() {
    imagePathList = Get.arguments[0];
    imageIndex = Get.arguments[1];
    pageController = PageController(initialPage: imageIndex);

    ///Initialize variables
  }
}
