import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

const _png1x1 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/q842iQAAAABJRU5ErkJggg==';

void main() {
  late Directory dir;
  late String pngPath;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('image_size_test');
    pngPath = '${dir.path}/a.png';
    await File(pngPath).writeAsBytes(base64Decode(_png1x1));
  });

  tearDownAll(() async {
    await dir.delete(recursive: true);
  });

  test('getSizeAsync matches sync getSize', () async {
    ImageSizeManager().clear();
    expect(await ImageSizeManager().getSizeAsync(pngPath), (1, 1));
    expect(ImageSizeManager().getSize(pngPath), (1, 1));
  });

  test('getAspectRatioAsync computes and caches', () async {
    ImageSizeManager().clear();
    expect(await ImageSizeManager().getAspectRatioAsync(pngPath), 1.0);
    await File(pngPath).delete();
    expect(await ImageSizeManager().getAspectRatioAsync(pngPath), 1.0);
    await File(pngPath).writeAsBytes(base64Decode(_png1x1));
  });
}
