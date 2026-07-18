import 'package:uuid/uuid.dart';

const _uuid = Uuid();

String uuidV4() => _uuid.v4();

/// UUID v7，前 48 位为毫秒时间戳（可按时间排序，
/// MediaUtil.extractDateFromUUID 依赖此布局）。
String uuidV7() => _uuid.v7();
