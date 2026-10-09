import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:platform_image_converter/platform_image_converter.dart';

@LazySingleton(as: IHeifDecoder)
class MobileHeifDecoder implements IHeifDecoder {
  @override
  Future<String?> convert(String srcPath, {required String outputPath}) async {
    final jpeg = await ImageConverter.convert(
      inputData: await File(srcPath).readAsBytes(),
      quality: 90,
    );
    await File(outputPath).writeAsBytes(jpeg);
    return outputPath;
  }
}
