import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
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
  Future<XFile?> takePhoto() => MAssetPicker.takePhoto();

  @override
  Future<XFile?> pickAudio() => _pick(.audio);

  @override
  Future<XFile?> pickFile({List<String>? allowedExtensions}) =>
      _pick(allowedExtensions == null ? .any : .custom, allowedExtensions);

  Future<XFile?> _pick(fp.FileType type, [List<String>? extensions]) async {
    try {
      final file = await fp.FilePicker.pickFile(
        type: type,
        allowedExtensions: extensions,
      );
      return file?.xFile;
    } on PlatformException catch (error) {
      if (error.code != 'load_failed') rethrow;
      toast.error(message: l10n.picker.fileLoadFailed);
      return null;
    }
  }
}
