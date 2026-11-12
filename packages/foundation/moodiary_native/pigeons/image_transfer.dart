import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/image_transfer.g.dart',
    dartPackageName: 'moodiary_native',
    kotlinOut:
        'android/src/main/kotlin/cn/yooss/moodiary_native/ImageTransfer.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'cn.yooss.moodiary_native',
      includeErrorClass: false,
    ),
    swiftOut:
        'ios/moodiary_native/Sources/moodiary_native/ImageTransfer.g.swift',
    swiftOptions: SwiftOptions(includeErrorClass: false),
  ),
)
class TransferredImage {
  TransferredImage({
    required this.bytes,
    required this.mime,
    required this.name,
  });
  Uint8List bytes;
  String mime;
  String name;
}

@HostApi()
abstract class ImageTransferApi {
  @async
  Uint8List? readContentUri(String uri);
  @async
  TransferredImage? readClipboardImage();
}
