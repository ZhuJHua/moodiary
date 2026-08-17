import 'package:mui/mui.dart';

/// 按需建子节点的 [IndexedStack]：没被选中过的那一格先放占位，第一次切过去才真正建，
/// 之后一直留着（State 不丢）。
///
/// 裸 [IndexedStack] **会把全部 children 都 build 出来** —— 底栏三个 tab 就是冷启动时
/// 一起建三份，哪怕用户只看第一个。
///
/// ## 为什么只记下标、不存 widget
///
/// 社区有两份现成实现，做法正好相反，值得记一笔。
///
/// `lazy_load_indexed_stack` 把 `List<Widget>` 存进 State，`didUpdateWidget` 里只把
/// **当前**那一格换成新的：
///
/// ```dart
/// _children[widget.index] = widget.children[widget.index];
/// ```
///
/// 于是**已经建过但此刻隐藏的格子，永远拿不到父级传下来的新 widget**。而
/// [IndexedStack] 的隐藏子树是活的（`RenderIndexedStack` 没覆写 `performLayout`，
/// 全部子节点照常布局），拿着旧 widget 就意味着旧的回调、旧的 listenable、旧的数据。
/// 它另外还把占位默认成 `Container()`（在 Stack 里会撑满、参与尺寸计算），
/// 并在 children 长度一变时整体重置（连当前可见那格的 State 一起丢）。
///
/// `lazy_indexed_stack` 的做法才是对的：State 里只留一个 `Set<int>`，children 每帧从
/// `widget.children` 现取。本组件沿用它的骨架，补三样：[preloadIndexes]、
/// [disposeWhenHidden]、以及可空的 [index]（与 [IndexedStack] 对齐，null = 一格都不显示）。
///
/// ## 两个用得着的性质
///
/// * 隐藏的格子**照常布局**。这是 [IndexedStack] 保住 State 的代价，不是本组件引入的。
///   真的不想让它留着就用 [disposeWhenHidden]。
/// * 子节点内部可以用 `Visibility.of(context)` 问自己现在可不可见 —— [IndexedStack]
///   给每个 child 挂了 `_VisibilityScope`（Flutter 3.47 起）。页面因此能自己决定
///   「重新可见时刷新」，不需要外层壳反过来知道页面里有什么、再去回调它。
class MLazyIndexedStack extends StatefulWidget {
  /// 要显示的下标。null = 一格都不显示（与 [IndexedStack] 一致）。
  final int? index;

  /// **按位置寻址**，和 [IndexedStack] 一样：中途往中间插一格会让后面的下标全错位。
  /// 顺序不稳定的列表别用 [MLazyIndexedStack]。
  final List<Widget> children;

  /// 第一帧就建好的下标。用于「切过去必须是暖的」那一两格。
  final List<int> preloadIndexes;

  /// 切走就销毁、切回来重建的下标（State 不保留）。给那些留着代价太大的页面。
  final List<int> disposeWhenHidden;

  /// 还没建的格子放什么。默认 [SizedBox.shrink] —— 占位也会参与 [IndexedStack] 的
  /// 尺寸计算，撑满的占位会把整个 stack 撑大。
  ///
  /// 同一个实例会被放进多个空格子，所以**别带 GlobalKey**。
  final Widget placeholder;

  final AlignmentGeometry alignment;
  final TextDirection? textDirection;
  final Clip clipBehavior;
  final StackFit sizing;

  const MLazyIndexedStack({
    super.key,
    this.index = 0,
    this.children = const [],
    this.preloadIndexes = const [],
    this.disposeWhenHidden = const [],
    this.placeholder = const SizedBox.shrink(),
    this.alignment = AlignmentDirectional.topStart,
    this.textDirection,
    this.clipBehavior = Clip.hardEdge,
    this.sizing = StackFit.loose,
  });

  @override
  State<MLazyIndexedStack> createState() => _MLazyIndexedStackState();
}

class _MLazyIndexedStackState extends State<MLazyIndexedStack> {
  /// **只存下标，不存 widget** —— 见类注释里那条坑。
  final Set<int> _built = <int>{};

  @override
  void initState() {
    super.initState();
    assert(() {
      final both = widget.preloadIndexes.toSet().intersection(
        widget.disposeWhenHidden.toSet(),
      );
      return both.isEmpty;
    }(), '同一个下标不能既 preloadIndexes 又 disposeWhenHidden：它会在第一帧建好、第一次切走时立刻销毁。');
    _sync();
  }

  @override
  void didUpdateWidget(MLazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 只丢越界的那些。**不能整体重置** —— 那会把当前可见那格的 State 也一起丢掉。
    if (widget.children.length < oldWidget.children.length) {
      _built.removeWhere((i) => i >= widget.children.length);
    }
    _sync();
  }

  void _sync() {
    final count = widget.children.length;
    final index = widget.index;
    if (index != null && index >= 0 && index < count) _built.add(index);
    for (final i in widget.preloadIndexes) {
      if (i >= 0 && i < count) _built.add(i);
    }
    if (widget.disposeWhenHidden.isNotEmpty) {
      _built.removeWhere(
        (i) => i != index && widget.disposeWhenHidden.contains(i),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index,
      alignment: widget.alignment,
      textDirection: widget.textDirection,
      clipBehavior: widget.clipBehavior,
      sizing: widget.sizing,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          if (_built.contains(i)) widget.children[i] else widget.placeholder,
      ],
    );
  }
}
