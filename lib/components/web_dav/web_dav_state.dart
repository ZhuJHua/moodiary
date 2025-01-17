import 'package:flutter/material.dart';
import 'package:mood_diary/common/values/webdav.dart';
import 'package:refreshed/refreshed.dart';

import '../../utils/data/pref.dart';
import '../../utils/webdav_util.dart';

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
