import 'dart:async';

import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mui/mui.dart';

Widget _host({
  MRefreshCallback? refresh,
  bool enabled = true,
  bool still = false,
  Future<bool> Function()? loadMore,
  Object? paginationKey,
  int rows = 30,
}) => MaterialApp(
  theme: buildMuiTheme(brightness: .light),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: still),
    child: child!,
  ),
  localizationsDelegates: const [
    ...GlobalMaterialLocalizations.delegates,
    GlobalMuiLocalizations.delegate,
  ],
  home: Scaffold(
    body: MRefresh(
      onRefresh: refresh,
      refreshEnabled: enabled,
      onLoadMore: loadMore,
      paginationKey: paginationKey,
      child: ListView.builder(
        itemExtent: 60,
        itemCount: rows,
        itemBuilder: (_, index) => Text('Row $index'),
      ),
    ),
  ),
);

IndicatorController _indicator(WidgetTester tester) => tester
    .widget<CustomRefreshIndicator>(find.byType(CustomRefreshIndicator))
    .controller!;

Future<void> _pull(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, 180));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  await tester.pump();
}

void main() {
  for (final status in MRefreshStatus.values) {
    testWidgets(
      'parks at 52px and displays ${status.name} through completion',
      (tester) async {
        final pending = Completer<MRefreshOutcome?>();
        var calls = 0;
        await tester.pumpWidget(
          _host(
            refresh: () {
              calls++;
              return pending.future;
            },
          ),
        );
        final list = find.byType(ListView);
        final resting = tester.getTopLeft(list);
        await _pull(tester);
        expect(calls, 1);
        expect(_indicator(tester).isLoading, isTrue);
        expect(tester.getTopLeft(list), resting + const Offset(0, 52));
        pending.complete(MRefreshOutcome(status: status, message: status.name));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));
        expect(find.text(status.name), findsOneWidget);
        expect(tester.getTopLeft(list), resting + const Offset(0, 52));
        await tester.pump(const Duration(milliseconds: 51));
        await tester.pumpAndSettle();
        expect(_indicator(tester).isIdle, isTrue);
        expect(find.text(status.name), findsNothing);
        expect(tester.getTopLeft(list), resting);
      },
    );
  }

  testWidgets('silent completion immediately finalizes', (tester) async {
    final pending = Completer<MRefreshOutcome?>();
    await tester.pumpWidget(_host(refresh: () => pending.future));
    await _pull(tester);
    pending.complete(null);
    await tester.pump();
    expect(_indicator(tester).isFinalizing, isTrue);
    await tester.pump(const Duration(milliseconds: 251));
    expect(_indicator(tester).isIdle, isTrue);
  });

  testWidgets(
    'reduced motion drops the dwell and a throwing callback settles',
    (tester) async {
      final failed = Completer<MRefreshOutcome?>();
      await tester.pumpWidget(_host(refresh: () => failed.future));
      await _pull(tester);
      failed.completeError(StateError('refresh failed'));
      await tester.pump();
      await tester.pump();
      final l10n = tester.element(find.byType(MRefresh)).muiL10n;
      expect(find.text(l10n.toastError), findsOneWidget);
      expect(find.text(l10n.refreshComplete), findsNothing);
      await tester.pump(const Duration(milliseconds: 851));
      await tester.pumpAndSettle();

      final pending = Completer<MRefreshOutcome?>();
      await tester.pumpWidget(
        _host(refresh: () => pending.future, still: true),
      );
      await _pull(tester);
      expect(_indicator(tester).isLoading, isTrue);
      pending.completeError(StateError('refresh failed'));
      await tester.pump();
      await tester.pump(Duration.zero);
      await tester.pump();
      expect(_indicator(tester).isIdle, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'metrics and scroll end during a top pull cannot start pagination',
    (tester) async {
      final pending = Completer<MRefreshOutcome?>();
      var loads = 0;
      await tester.pumpWidget(_host(refresh: () => pending.future, rows: 1));
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        _host(
          refresh: () => pending.future,
          rows: 1,
          loadMore: () async {
            loads++;
            return true;
          },
        ),
      );
      await _pull(tester);
      final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
      final metrics = scroll.position.copyWith();
      ScrollMetricsNotification(
        metrics: metrics,
        context: scroll.context,
      ).dispatch(scroll.context);
      ScrollEndNotification(
        metrics: metrics,
        context: scroll.context,
      ).dispatch(scroll.context);
      await tester.pump();
      expect(loads, 0);
      pending.complete(null);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'disabling during refresh preserves the header and scroll position',
    (tester) async {
      final pending = Completer<MRefreshOutcome?>();
      var calls = 0;
      Future<MRefreshOutcome?> refresh() {
        calls++;
        return pending.future;
      }

      await tester.pumpWidget(_host(refresh: refresh));
      await _pull(tester);
      final indicator = _indicator(tester);
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      position.jumpTo(120);
      await tester.pumpWidget(_host(refresh: refresh, enabled: false));
      expect(_indicator(tester), same(indicator));
      expect(indicator.isLoading, isTrue);
      expect(
        tester.state<ScrollableState>(find.byType(Scrollable)).position,
        same(position),
      );
      expect(position.pixels, 120);
      pending.complete(const MRefreshOutcome(message: 'Done'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Done'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 851));
      await tester.pumpAndSettle();
      position.jumpTo(0);
      await _pull(tester);
      expect(calls, 1);
      expect(indicator.isIdle, isTrue);
      await tester.pumpWidget(_host());
      await _pull(tester);
      expect(indicator.isRefreshEnabled, isFalse);
      expect(indicator.isIdle, isTrue);
    },
  );

  testWidgets(
    'both platforms receive leading-edge clamping physics',
    (tester) async {
      await tester.pumpWidget(_host());
      final physics = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position
          .physics;
      expect(physics, isA<AlwaysScrollableScrollPhysics>());
      ScrollPhysics? ancestor = physics.parent;
      while (ancestor != null && ancestor is! ClampingScrollPhysics) {
        ancestor = ancestor.parent;
      }
      expect(ancestor, isA<ClampingScrollPhysics>());
      expect(ancestor, isNot(isA<ClampingWithOverscrollPhysics>()));
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );

  for (final bottom in [true, false]) {
    testWidgets(
      '${bottom ? 'bottom' : 'disabled top'} overscroll leaves the next inward drag free',
      (tester) async {
        await tester.pumpWidget(
          _host(refresh: () async => null, enabled: bottom),
        );
        final list = find.byType(ListView);
        final position = tester
            .state<ScrollableState>(find.byType(Scrollable))
            .position;
        final edge = bottom
            ? position.maxScrollExtent
            : position.minScrollExtent;
        position.jumpTo(edge);
        await tester.pump();
        final outward = Offset(0, bottom ? -200 : 200);
        await tester.drag(list, outward);
        expect(position.pixels, edge);
        final inward = await tester.startGesture(tester.getCenter(list));
        await inward.moveBy(-outward / 3);
        await inward.moveBy(-outward / 6);
        expect(
          bottom ? position.pixels < edge : position.pixels > edge,
          isTrue,
        );
        await inward.up();
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets('an old append cannot suppress pagination at the same offset', (
    tester,
  ) async {
    final oldAppend = Completer<bool>();
    final newAppend = Completer<bool>();
    var oldCalls = 0;
    var newCalls = 0;
    await tester.pumpWidget(
      _host(
        rows: 1,
        paginationKey: 'time',
        loadMore: () {
          oldCalls++;
          return oldAppend.future;
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(oldCalls, 1);
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
    void endScroll() => ScrollEndNotification(
      metrics: scroll.position.copyWith(),
      context: scroll.context,
    ).dispatch(scroll.context);

    await tester.pumpWidget(
      _host(
        rows: 1,
        paginationKey: 'modified',
        loadMore: () {
          newCalls++;
          return newAppend.future;
        },
      ),
    );
    endScroll();
    expect(newCalls, 1);
    oldAppend.complete(false);
    await tester.pump();
    endScroll();
    expect(newCalls, 1);
    newAppend.complete(true);
    await tester.pump();
    endScroll();
    expect(newCalls, 2);
    await tester.pump();
  });

  testWidgets(
    'a rejected preload is not retried by bottom scroll-end notifications',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        _host(
          rows: 1,
          loadMore: () async {
            calls++;
            return false;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, 1);
      await tester.drag(find.byType(ListView), const Offset(0, -150));
      await tester.pumpAndSettle();
      expect(calls, 1);
    },
  );
}
