import 'package:flutter/material.dart';
import 'package:moodiary/common/values/webdav.dart';
import 'package:moodiary/presentation/pref.dart';
import 'package:moodiary/utils/webdav_util.dart';
import 'package:refreshed/refreshed.dart';

class WebDavState {
  final formKey = GlobalKey<FormState>();

  RxBool hasOption = WebDavUtil().hasOption.obs;
  List<String> currentOptions = WebDavUtil().options;

  Rx<WebDavConnectivityStatus> connectivityStatus =
      WebDavConnectivityStatus.connecting.obs;

  RxBool autoSync = PrefUtil.getValue<bool>('autoSync')!.obs;

  RxBool autoSyncAfterChange =
      PrefUtil.getValue<bool>('autoSyncAfterChange')!.obs;

  WebDavState();
}
