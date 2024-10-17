import 'package:mood_diary/utils/utils.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionUtil {
  //权限申请
  Future<bool> checkPermission(Permission permission) async {
    //检查当前权限
    final status = await permission.status;
    //如果还没有授权或者拒绝过
    if (status.isDenied) {
      //尝试申请权限
      final permissionStatus = await permission.request();
      if (permissionStatus.isDenied || permissionStatus.isPermanentlyDenied) {
        Utils().noticeUtil.showToast('请授予相关权限');
        return false;
      } else {
        return true;
      }
    } else if (status.isPermanentlyDenied) {
      Utils().noticeUtil.showToast('相关权限被禁用，请去设置中手动开启');
      Future.delayed(const Duration(seconds: 2), () => openAppSettings());
      return false;
    } else {
      return true;
    }
  }
}
