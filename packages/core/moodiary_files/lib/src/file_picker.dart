import 'package:cross_file/cross_file.dart';
import 'package:flutter/widgets.dart';

abstract class IFilePicker {
  Future<List<XFile>> pickImages(BuildContext context, {int maxAssets = 9});

  Future<XFile?> pickVideo(BuildContext context);

  Future<XFile?> pickAudio();

  Future<XFile?> pickFile({List<String>? allowedExtensions});
}
