import 'package:moodiary_storage/moodiary_storage.dart';

/// 和风天气的凭据。**host 是 per-key 专属的**，两者缺一整套就不可用（2.8.0 新增
/// 配置，升级用户为空），拼出来的 `https://null/...` 只会白打一发必败请求。
typedef QweatherCredentials = ({String host, String key});

/// 取和风凭据；任一缺失返回 null。天气与位置两条链路都在动手前先问它一次 ——
/// 放在权限请求**之前**，否则没配 key 的用户会先被要一遍定位权限再失败。
Future<QweatherCredentials?> qweatherCredentials() async {
  final host = MoodiaryKVs.qweatherApiHost.get();
  if (host == null || host.isEmpty) return null;
  final key = await MoodiarySecureKVs.qweatherKey.get();
  if (key == null || key.isEmpty) return null;
  return (host: host, key: key);
}
