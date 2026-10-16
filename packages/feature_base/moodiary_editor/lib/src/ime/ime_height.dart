import 'dart:math';

import 'package:moodiary_storage/moodiary_storage.dart';

const defaultImeHeight = 300.0;

double? validImeHeight(double? height) =>
    height != null && height > 0 ? height : null;

double resolveImeHeight(double? height) =>
    validImeHeight(height) ?? defaultImeHeight;

double maxImePanelHeight(double screenHeight) => max(0, screenHeight / 2 - 48);

double resolveImePanelHeight(double? imeHeight, double screenHeight) =>
    min(resolveImeHeight(imeHeight), maxImePanelHeight(screenHeight));

abstract final class ImeHeightCache {
  static MoodiaryKVs<double> _key(bool landscape) => landscape
      ? MoodiaryKVs.editorImeHeightLandscape
      : MoodiaryKVs.editorImeHeightPortrait;

  static double? read({required bool landscape}) =>
      validImeHeight(_key(landscape).get());

  static void write(double height, {required bool landscape}) {
    if (height <= 0 || height == _key(landscape).get()) return;
    _key(landscape).set(height);
  }
}
