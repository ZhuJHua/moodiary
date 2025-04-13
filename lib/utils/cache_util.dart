import 'dart:async';

import 'package:moodiary/persistence/pref.dart';

class CacheUtil {
  static Future<List<String>?> getCacheList(
    String key,
    Future<List<String>?> Function() fetchData, {
    int maxAgeMillis = 900000,
  }) async {
    var cachedData = PrefUtil.getValue<List<String>>(key);
    // 检查缓存是否有效，如果无效则更新缓存
    if (cachedData == null || _isCacheExpired(cachedData, maxAgeMillis)) {
      await _updateCacheList(key, fetchData);

      cachedData = PrefUtil.getValue<List<String>>(key); // 获取更新后的缓存数据
    }
    return cachedData;
  }

  static bool _isCacheExpired(List<String> cachedData, int maxAgeMillis) {
    if (cachedData.length < 2) {
      return true; // 缓存数据格式不正确，视为过期
    }
    final int timestamp = int.parse(cachedData.last);
    return DateTime.now().millisecondsSinceEpoch - timestamp >= maxAgeMillis;
  }

  static Future<void> _updateCacheList(
    String key,
    Future<List<String>?> Function() fetchData,
  ) async {
    final newData = await fetchData();
    if (newData != null) {
      await PrefUtil.setValue<List<String>>(
        key,
        newData..add(DateTime.now().millisecondsSinceEpoch.toString()),
      );
    }
  }
}
