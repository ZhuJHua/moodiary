import 'package:moodiary_di/moodiary_di.dart';

/// HEIC/HEIF 转码端口。这是 core 里唯一一件 android/ios 专属能力——抽成端口是
/// 为了不让 heif_converter 把整棵依赖树钉在移动端。实现由各 app 组合根注册
/// （mobile 走 heif_converter；桌面实现可直接返回 null，调用方自带失败降级）。
abstract class IHeifDecoder {
  static IHeifDecoder get() => getIt.get<IHeifDecoder>();

  /// 把 [srcPath] 的 HEIC/HEIF 解码写到 [outputPath]。[format] 为 `png` / `jpg`
  /// （移动实现按输出后缀选编码器，非 jpg 即 PNG——含 alpha）。
  /// 成功返回输出路径；解码失败返回 null 或抛出，调用方按既有降级处理。
  Future<String?> convert(
    String srcPath, {
    required String outputPath,
    required String format,
  });
}
