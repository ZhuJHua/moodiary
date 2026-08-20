/// 强调色来源。持久化的是 index，改动顺序会改掉老用户的配色。
///
/// 配色生成本身已经搬进 `package:mui`（[resolveColorScheme]）；留在 core 的
/// 只有这个「用户选了哪一档」的业务枚举 —— 它绑着 KV 的存储格式，不属于组件库。
enum ThemeAccentMode {
  /// 纯灰度。默认档。
  neutral,

  /// 取自系统壁纸。仅 Android 12+ 拿得到，其余平台该档不可选。
  system,

  /// 用户在取色器里挑的颜色。
  custom,
}
