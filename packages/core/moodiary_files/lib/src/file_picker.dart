import 'package:cross_file/cross_file.dart';
import 'package:flutter/widgets.dart';
import 'package:moodiary_di/moodiary_di.dart';

/// 平台文件/媒体选取服务。移动端实现走应用内选择器（wechat_assets_picker /
/// wechat_camera_picker + file_picker），桌面端实现走系统对话框；由各 app 在 DI 注册。
/// 统一返回 [XFile] 对接 MediaManager 存盘管线；取消返回空列表 / null。
abstract class IFilePicker {
  static IFilePicker get() => getIt.get<IFilePicker>();

  /// 相册多选图片。
  Future<List<XFile>> pickImages(BuildContext context, {int maxAssets = 9});

  /// 相册选单个视频。
  Future<XFile?> pickVideo(BuildContext context);

  /// 拍照。
  Future<XFile?> takePhoto(BuildContext context);

  /// 录像。
  Future<XFile?> recordVideo(BuildContext context);

  /// 选单个音频文件。
  Future<XFile?> pickAudio();

  /// 选单个任意文件；[allowedExtensions] 为空则不限类型。
  Future<XFile?> pickFile({List<String>? allowedExtensions});
}
