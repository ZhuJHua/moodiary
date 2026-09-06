import 'package:mui/mui.dart';

class MLazyIndexedStack extends StatefulWidget {
  final int? index;

  final List<Widget> children;

  final List<int> preloadIndexes;

  final List<int> disposeWhenHidden;

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
