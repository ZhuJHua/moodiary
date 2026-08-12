import 'package:flutter/foundation.dart';

/// 组件级主题的基类。**组件名不出现在 [MuiThemeData] 的字段里** ——
/// 全部按类型键存进一张 map，新增组件只要新建一个 `MuiXxxTheme` 文件，
/// foundation 的核心文件一行不动。
///
/// 组件取值走三级回落：
/// ```
/// effectiveX = widget.x ?? theme.component<MuiXTheme>()?.x ?? <从 token 现场算>
/// ```
/// 第三级**必须存在** —— 组件在 `components` 为空时也要画对，主题类不是组件的前置依赖。
/// 第二级**必须完整** —— 组件里出现的每个 `effectiveX`，主题类上都要有对应字段，
/// 否则「集中改一处、全仓生效」就退化成了偶然性。
@immutable
abstract class MuiComponentTheme<T extends MuiComponentTheme<T>> {
  const MuiComponentTheme({this.canMerge = true});

  /// false = 我是终态，整块顶掉父层而不是当补丁叠上去。
  ///
  /// 纯 merge 语义下写不出「我就是要完全没边框」（null 会被父层的值填回来），
  /// 这个开关是唯一的逃生舱。
  final bool canMerge;

  Object get typeKey => T;

  /// 把 [other] 当补丁叠在自己之上；[other] 的 [canMerge] 为 false 时直接返回它。
  T merge(covariant T? other);

  T lerpTo(covariant T other, double t);
}

/// 包外扩展槽位。业务语义色（分类哈希色板、心情渐变、视频暗室皮肤）挂这里 ——
/// foundation 不该认识它们。
@immutable
abstract class MuiThemeExtension<T extends MuiThemeExtension<T>> {
  const MuiThemeExtension();

  Object get typeKey => T;

  T lerpTo(covariant T other, double t);
}
