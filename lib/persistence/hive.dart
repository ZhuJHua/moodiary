import 'package:hive_ce/hive.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:moodiary/utils/file_util.dart';

class HiveUtil {
  HiveUtil._();

  static final HiveUtil _instance = HiveUtil._();

  factory HiveUtil() => _instance;

  late LazyBox<bool> _imageCacheBox;

  late LazyBox<double> _imageAspectBox;

  LazyBox<bool> get imageCacheBox => _imageCacheBox;

  LazyBox<double> get imageAspectBox => _imageAspectBox;

  Future<void> init() async {
    Hive.init(
      FileUtil.getRealPath('hive', ''),
      backendPreference: HiveStorageBackendPreference.native,
    );
    _imageCacheBox = await Hive.openLazyBox<bool>('image_cache');
    _imageAspectBox = await Hive.openLazyBox<double>('image_aspect');
  }

  Future<void> clear() async {
    await _imageCacheBox.clear();
    await _imageAspectBox.clear();
  }

  Future<void> close() async {
    await Hive.close();
  }
}
