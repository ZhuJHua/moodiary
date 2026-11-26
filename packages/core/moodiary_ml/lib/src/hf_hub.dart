import 'package:moodiary_storage/moodiary_storage.dart';

abstract final class HfHub {
  static const officialEndpoint = 'https://huggingface.co';

  /// The base URL downloads go to for a stored endpoint value; blank means
  /// the official site.
  static String normalize(String endpoint) {
    var base = endpoint.trim();
    if (base.isEmpty) return officialEndpoint;
    if (!base.contains('://')) base = 'https://$base';
    return base.replaceFirst(RegExp(r'/+$'), '');
  }

  static String resolve(String hfPath) =>
      '${normalize(MoodiaryKVs.modelDownloadEndpoint.get() ?? '')}/$hfPath';
}
