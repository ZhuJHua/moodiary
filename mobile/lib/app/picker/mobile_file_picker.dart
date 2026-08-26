import 'package:file_picker/file_picker.dart' as fp;
import 'package:injectable/injectable.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_picker/moodiary_picker.dart';
import 'package:mui/mui.dart';

/// [IFilePicker] 移动端实现。
///
/// 相册与相机都走自建的 [MAssetPicker]（moodiary_picker），音频与任意文件走
/// file_picker 的系统入口。权限被拒时由选择器/相机页自己给出提示页。
/// 拍照/录像不在端口上——相机入口是选择器网格的第一格，不经 IFilePicker；
/// 真需要独立入口时另开窄端口 ICameraCapture，桌面不实现即可。
@LazySingleton(as: IFilePicker)
class MobileFilePicker implements IFilePicker {
  @override
  Future<List<XFile>> pickImages(BuildContext context, {int maxAssets = 9}) {
    return MAssetPicker.pickImages(context, maxAssets: maxAssets);
  }

  @override
  Future<XFile?> pickVideo(BuildContext context) {
    return MAssetPicker.pickVideo(context);
  }

  @override
  Future<XFile?> pickAudio() async {
    final res = await fp.FilePicker.pickFile(type: .audio);
    return res?.xFile;
  }

  @override
  Future<XFile?> pickFile({List<String>? allowedExtensions}) async {
    final res = await fp.FilePicker.pickFile(
      type: allowedExtensions == null ? .any : .custom,
      allowedExtensions: allowedExtensions,
    );
    return res?.xFile;
  }
}
