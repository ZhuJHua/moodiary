import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mood_diary/common/values/webdav.dart';
import 'package:mood_diary/utils/utils.dart';

class WebDavState {
  final formKey = GlobalKey<FormState>();

  RxBool hasOption = Utils().webDavUtil.hasOption.obs;
  List<String> currentOptions = Utils().webDavUtil.options;

  Rx<WebDavConnectivityStatus> connectivityStatus = WebDavConnectivityStatus.connecting.obs;

  WebDavState();
}
