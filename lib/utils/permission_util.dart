import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

import 'notice_util.dart';

class PermissionUtil {
  //权限申请
  static Future<bool> checkPermission(Permission permission) async {
    if (Platform.isMacOS) {
      return true;
    }
    //检查当前权限
    final status = await permission.status;
    //如果还没有授权或者拒绝过
    if (status.isDenied) {
      //尝试申请权限
      final permissionStatus = await permission.request();
      if (permissionStatus.isDenied || permissionStatus.isPermanentlyDenied) {
        toast.info(message: '请授予相关权限');
        return false;
      } else {
        return true;
      }
    } else if (status.isPermanentlyDenied) {
      toast.error(message: '相关权限被禁用，请去设置中手动开启');
      Future.delayed(const Duration(seconds: 2), () => openAppSettings());
      return false;
    } else {
      return true;
    }
  }
}
