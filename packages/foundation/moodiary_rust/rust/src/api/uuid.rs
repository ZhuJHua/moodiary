use flutter_rust_bridge::frb;
use uuid::Uuid;

/// 随机 UUID v4，小写带连字符，与 Dart `package:uuid` 输出格式一致。
#[frb(sync)]
pub fn uuid_v4() -> String {
    Uuid::new_v4().to_string()
}

/// 基于当前时间的 UUID v7，前 48 位为毫秒时间戳（可按时间排序，
/// Dart 侧 `MediaUtil.extractDateFromUUID` 依赖此布局）。
#[frb(sync)]
pub fn uuid_v7() -> String {
    Uuid::now_v7().to_string()
}
