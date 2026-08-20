import 'package:flutter/rendering.dart';
import 'package:mui/mui.dart';

/// 在**离屏**的渲染树里量出 [widget] 的尺寸，同步返回，不占一帧。
///
/// 用来回答「这个东西如果展开会有多高」——而不必先把它真的展开一帧再去量。
/// 那种「先渲染再补偿」的做法必然闪一下：中间那一帧内容已经变了、补偿还没来。
///
/// [viewSize] 是给根节点的约束。典型用法是宽度已知、高度不限：
/// `Size(availableWidth, double.infinity)`。
///
/// **只有 [InheritedTheme] 会被带过去**（`Theme` / `DefaultTextStyle` / `IconTheme`
/// 这些），加上 [Directionality] 与 [MediaQuery]。别的都带不过去 —— `Localizations`
/// 与 slang 的 `TranslationProvider` 都不是 [InheritedTheme]。子树里要是有谁取串，
/// **调用方得自己在 [widget] 外面补上那一层**：`context.l10n` 缺了会抛，
/// `context.muiL10n` 缺了是 debug 断言、release 回落 base 语种（量出来的宽度会不准）。
///
/// 代价是一次完整的 build + layout。别放进每帧都会走的路径。
Size getWidgetSizeOffScreen({
  required BuildContext context,
  required Widget widget,
  required Size viewSize,
}) {
  final root = _MeasureRoot(
    BoxConstraints(maxWidth: viewSize.width, maxHeight: viewSize.height),
  );

  final pipelineOwner = PipelineOwner();
  final buildOwner = BuildOwner(focusManager: FocusManager());
  pipelineOwner.rootNode = root;
  root.scheduleInitialLayout();

  final element = RenderObjectToWidgetAdapter<RenderBox>(
    container: root,
    child: InheritedTheme.captureAll(
      context,
      Directionality(
        textDirection: Directionality.of(context),
        child: MediaQuery(
          data: MediaQuery.of(context),
          child: Builder(builder: (_) => widget),
        ),
      ),
    ),
  ).attachToRenderTree(buildOwner);

  try {
    pipelineOwner.flushLayout();
    return root.size;
  } finally {
    // 拆掉这棵临时树，否则它的 element 会一直挂在 buildOwner 上。
    element.update(RenderObjectToWidgetAdapter<RenderBox>(container: root));
    buildOwner.finalizeTree();
  }
}

/// 根节点：拿给定约束量孩子，然后把自己的尺寸设成孩子的尺寸。
class _MeasureRoot extends RenderBox
    with RenderObjectWithChildMixin<RenderBox> {
  _MeasureRoot(this.childConstraints);

  final BoxConstraints childConstraints;

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = Size.zero;
      return;
    }
    child.layout(childConstraints, parentUsesSize: true);
    size = child.size;
  }

  /// 离屏树没有父级给约束，尺寸由孩子决定 —— 常规的约束校验在这里不适用。
  @override
  void debugAssertDoesMeetConstraints() {}
}
