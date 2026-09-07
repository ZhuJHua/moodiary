import 'package:heif_converter/heif_converter.dart';
import 'package:injectable/injectable.dart';
import 'package:moodiary_files/moodiary_files.dart';

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
