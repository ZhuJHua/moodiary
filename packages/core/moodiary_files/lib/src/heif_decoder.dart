abstract class IHeifDecoder {
  Future<String?> convert(
    String srcPath, {
    required String outputPath,
    required String format,
  });
}
