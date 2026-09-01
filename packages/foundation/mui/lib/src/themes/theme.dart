import 'package:material_ui/material_ui.dart';
import 'package:mui/src/themes/theme_data.dart';

/// 派生视图的缓存，键是 [ThemeData] 实例本身。
///
/// `ThemeData` 不可变，且 `AnimatedTheme` 在补间时每帧新建一个 —— 所以静止时永久
/// 命中、动画时每帧算一次，正好是想要的成本曲线。[MuiThemeData] 本身只读两个字段，
/// 真正省下的是重复解析 [MuiTokens] 的开销。
final Expando<MuiThemeData> _views = Expando<MuiThemeData>('mui theme view');

/// 主题注入点 —— 现在只是 material [Theme] 的一层语义包装。
///
/// 配色与排版的真源是 `ThemeData`，mui 不再自建一棵主题树，所以这里没有
/// `InheritedWidget`，也就不存在两棵树漂移的问题。
class MuiTheme extends StatelessWidget {
  const MuiTheme({super.key, required this.data, required this.child});

  final ThemeData data;
  final Widget child;

  /// 组件内部取主题的唯一写法。
  ///
  /// 直接建在 `Theme.of` 上，因此**依赖关系与深度都由框架管**：子树里任何一层
  /// 换了 `Theme`（第三方 picker 会这么干），这里取到的就是那一层的值。
  static MuiThemeData of(BuildContext context) => viewOf(Theme.of(context));

  /// 把一份 [ThemeData] 包成 mui 门面。缓存命中时零分配。
  static MuiThemeData viewOf(ThemeData raw) =>
      _views[raw] ??= MuiThemeData(raw);

  @override
  Widget build(BuildContext context) => Theme(data: data, child: child);
}

extension MuiThemeContext on BuildContext {
  /// mui 主题的取用入口。
  ///
  /// ```dart
  /// context.theme.typography.titleLarge.onSurfaceVariant
  /// context.theme.typography.bodyMedium.emphasized.primary
  /// context.theme.colors.surfaceContainerHigh
  /// ```
  MuiThemeData get theme => MuiTheme.of(this);

  double get safeBottom => MediaQuery.paddingOf(this).bottom;
}
