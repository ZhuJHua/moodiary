import 'package:file_picker/file_picker.dart' as fp;
import 'package:injectable/injectable.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_picker/moodiary_picker.dart';
import 'package:mui/mui.dart';

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
