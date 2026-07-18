import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_router/moodiary_router.dart';

/// 升级保险丝：页内双链跳转依赖 go_router 的一个关键行为——对命令式 push 的路由做
/// `replace` 时沿用原 pageKey（parser 的 NavigatingType.replace 分支），因此 Navigator
/// 的 Page 身份不变，页面 State 存活、新参数经 didUpdateWidget 进入，且栈深不变。
/// 若 go_router 升级破坏此契约，本测试会先失败（webview 将被重建、页内历史失效）。
void main() {
  testWidgets('replace 同路由不同参数：State 存活、栈深不变', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Text('home')),
        GoRoute(
          path: '/probe/:id',
          builder: (_, state) => _Probe(state.pathParameters['id']!),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    unawaited(router.push<void>('/probe/a'));
    await tester.pumpAndSettle();
    final before = tester.state<_ProbeState>(find.byType(_Probe));
    expect(before.widget.id, 'a');

    router.replace('/probe/b');
    await tester.pumpAndSettle();
    final after = tester.state<_ProbeState>(find.byType(_Probe));
    expect(identical(before, after), isTrue, reason: 'State 必须跨 replace 存活');
    expect(after.widget.id, 'b');
    expect(after.updates, 1, reason: '新参数应经 didUpdateWidget 送达');

    // 栈深不变：一次 pop 即回 home，而不是回到 /probe/a。
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(find.byType(_Probe), findsNothing);
  });
}

class _Probe extends StatefulWidget {
  final String id;
  const _Probe(this.id);

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  int updates = 0;

  @override
  void didUpdateWidget(covariant _Probe oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) updates++;
  }

  @override
  Widget build(BuildContext context) =>
      Text('probe-${widget.id}', textDirection: TextDirection.ltr);
}
