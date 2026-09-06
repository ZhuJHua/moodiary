import 'package:flutter_test/flutter_test.dart';
import 'package:mui/mui.dart';

class _Probe extends StatefulWidget {
  final String name;
  final String label;

  const _Probe({required this.name, this.label = ''});

  static final built = <String, int>{};
  static final disposed = <String, int>{};

  static void reset() {
    built.clear();
    disposed.clear();
  }

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    _Probe.built.update(widget.name, (v) => v + 1, ifAbsent: () => 1);
  }

  @override
  void dispose() {
    _Probe.disposed.update(widget.name, (v) => v + 1, ifAbsent: () => 1);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Text('${widget.name}:${widget.label}', textDirection: TextDirection.ltr);
}

Widget _host({
  required int index,
  String label = '',
  List<int> preload = const [],
  List<int> disposeWhenHidden = const [],
  int count = 3,
}) => Directionality(
  textDirection: TextDirection.ltr,
  child: MLazyIndexedStack(
    index: index,
    preloadIndexes: preload,
    disposeWhenHidden: disposeWhenHidden,
    children: [
      for (var i = 0; i < count; i++) _Probe(name: 'p$i', label: label),
    ],
  ),
);

void main() {
  setUp(_Probe.reset);

  testWidgets('只建当前那一格，切过去才建，切回来不重建', (tester) async {
    await tester.pumpWidget(_host(index: 0));
    expect(_Probe.built, {'p0': 1});

    await tester.pumpWidget(_host(index: 2));
    expect(_Probe.built, {'p0': 1, 'p2': 1});
    expect(_Probe.disposed, isEmpty, reason: '切走不该销毁，State 要留着');

    await tester.pumpWidget(_host(index: 0));
    expect(_Probe.built, {'p0': 1, 'p2': 1}, reason: '切回来不该重建');
  });

  testWidgets('已建但隐藏的格子照样收到父级传下来的新 widget', (tester) async {
    await tester.pumpWidget(_host(index: 0, label: 'v1'));
    await tester.pumpWidget(_host(index: 1, label: 'v1'));
    expect(find.text('p1:v1'), findsOneWidget);

    await tester.pumpWidget(_host(index: 1, label: 'v2'));
    await tester.pumpWidget(_host(index: 0, label: 'v2'));

    expect(find.text('p0:v2'), findsOneWidget);
    expect(find.text('p0:v1'), findsNothing);
    expect(_Probe.built['p0'], 1, reason: '拿到新 widget 靠的是更新，不是重建');
  });

  testWidgets('preloadIndexes 第一帧就建', (tester) async {
    await tester.pumpWidget(_host(index: 0, preload: const [2]));
    expect(_Probe.built, {'p0': 1, 'p2': 1});
    expect(find.text('p2:'), findsNothing);
    expect(find.text('p2:', skipOffstage: false), findsOneWidget);
  });

  testWidgets('disposeWhenHidden 切走即销毁，切回来是全新的', (tester) async {
    await tester.pumpWidget(_host(index: 1, disposeWhenHidden: const [1]));
    expect(_Probe.built['p1'], 1);

    await tester.pumpWidget(_host(index: 0, disposeWhenHidden: const [1]));
    expect(_Probe.disposed['p1'], 1);

    await tester.pumpWidget(_host(index: 1, disposeWhenHidden: const [1]));
    expect(_Probe.built['p1'], 2, reason: '回来要重建');
  });

  testWidgets('children 变短只丢越界的，当前那格的 State 留着', (tester) async {
    await tester.pumpWidget(_host(index: 0, count: 3));
    await tester.pumpWidget(_host(index: 1, count: 3));
    expect(_Probe.built, {'p0': 1, 'p1': 1});

    await tester.pumpWidget(_host(index: 1, count: 2));
    expect(_Probe.built, {'p0': 1, 'p1': 1});
    expect(_Probe.disposed, isEmpty);
  });

  testWidgets('占位不参与撑大尺寸', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: MLazyIndexedStack(
            index: 0,
            children: [
              SizedBox(width: 50, height: 50),
              SizedBox(width: 400, height: 400),
            ],
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(MLazyIndexedStack)), const Size(50, 50));
  });

  testWidgets('子节点能用 Visibility.of 知道自己可不可见', (tester) async {
    final seen = <bool>[];
    Widget host(int index) => Directionality(
      textDirection: TextDirection.ltr,
      child: MLazyIndexedStack(
        index: index,
        preloadIndexes: const [1],
        children: [
          const SizedBox(),
          Builder(
            builder: (context) {
              seen.add(Visibility.of(context));
              return const SizedBox();
            },
          ),
        ],
      ),
    );

    await tester.pumpWidget(host(0));
    expect(seen.last, isFalse);
    await tester.pumpWidget(host(1));
    expect(seen.last, isTrue);
  });
}
