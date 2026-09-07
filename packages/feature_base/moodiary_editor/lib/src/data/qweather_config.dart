import 'package:moodiary_storage/moodiary_storage.dart';

typedef QweatherCredentials = ({String host, String key});

Future<QweatherCredentials?> qweatherCredentials() async {
  final host = MoodiaryKVs.qweatherApiHost.get();
  if (host == null || host.isEmpty) return null;
  final key = await MoodiarySecureKVs.qweatherKey.get();
  if (key == null || key.isEmpty) return null;
  return (host: host, key: key);
}
