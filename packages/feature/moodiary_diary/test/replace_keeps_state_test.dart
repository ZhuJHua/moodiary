import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:mui/mui.dart';

final _mui = buildMuiTheme(brightness: Brightness.light);

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
    await tester.pumpWidget(
      MuiTheme(
        data: _mui,
        child: MaterialApp.router(routerConfig: router),
      ),
    );

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
      Text('probe-${widget.id}', textDirection: .ltr);
}
