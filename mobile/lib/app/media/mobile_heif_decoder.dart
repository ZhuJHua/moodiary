import 'package:heif_converter/heif_converter.dart';
import 'package:injectable/injectable.dart';
import 'package:moodiary_files/moodiary_files.dart';

/// heif_converter 只有 android/ios 实现，所以住在组合根（同 MobileFilePicker）。
@LazySingleton(as: IHeifDecoder)
class MobileHeifDecoder implements IHeifDecoder {
  @override
  Future<String?> convert(
    String srcPath, {
    required String outputPath,
    required String format,
  }) {
    return HeifConverter.convert(srcPath, output: outputPath, format: format);
  }
}
