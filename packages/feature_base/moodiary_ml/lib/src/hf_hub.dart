import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:moodiary_storage/moodiary_storage.dart';

abstract final class HfHub {
  static const officialEndpoint = 'https://huggingface.co';

  static String resolve(String hfPath) =>
      resolveWith(MoodiaryKVs.modelDownloadEndpoint.get() ?? '', hfPath);

  @visibleForTesting
  static String resolveWith(String endpoint, String hfPath) {
    var base = endpoint.trim();
    if (base.isEmpty) base = officialEndpoint;
    if (!base.contains('://')) base = 'https://$base';
    base = base.replaceFirst(RegExp(r'/+$'), '');
    return '$base/$hfPath';
  }
}
