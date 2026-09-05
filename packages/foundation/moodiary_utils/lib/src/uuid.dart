import 'package:uuid/uuid.dart';

const _uuid = Uuid();

String uuidV4() => _uuid.v4();

/// UUID v7，前 48 位为毫秒时间戳（可按时间排序，
/// MediaManager.extractDateFromUUID 依赖此布局）。
String uuidV7() => _uuid.v7();

/// 名字派生的确定性 id（RFC 4122 v5）：同一 [namespace] + [name] 在任何设备上都得到
/// 同一个 id，给「多台设备各自从旧数据生成同一实体」的场景用，同步时自然合并。
String uuidV5(String namespace, String name) => _uuid.v5(namespace, name);
