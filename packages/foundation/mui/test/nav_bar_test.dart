import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as glass;
import 'package:mui/mui.dart';

const _destinations = [
  MNavDestination(icon: Icon(LucideIcons.bookText), label: 'Diary'),
  MNavDestination(icon: Icon(LucideIcons.astroid), label: 'Assistant'),
  MNavDestination(icon: Icon(LucideIcons.circleUser), label: 'Me'),
];

void main() {
  for (final (platform, inset, bottom) in [
    (TargetPlatform.iOS, 34.0, 20.0),
    (TargetPlatform.android, 24.0, 24.0),
    (TargetPlatform.android, 48.0, 48.0),
    (TargetPlatform.android, 0.0, 20.0),
  ]) {
    testWidgets('$platform inset $inset geometry and interaction', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      try {
        tester.view.physicalSize = const Size(402, 874);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final theme = buildMuiTheme(brightness: Brightness.light);
        var selected = 0;
        var actions = 0;
        var enabled = true;
        late StateSetter update;
        await tester.pumpWidget(
          MuiTheme(
            data: theme,
            child: MaterialApp(
              theme: theme,
              home: MediaQuery(
                data: MediaQueryData(
                  padding: EdgeInsets.only(bottom: inset),
                  viewPadding: EdgeInsets.only(bottom: inset),
                  textScaler: const TextScaler.linear(2),
                ),
                child: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return Scaffold(
                      extendBody: true,
                      body: const SizedBox.expand(),
                      bottomNavigationBar: MNavBar(
                        destinations: _destinations,
                        selectedIndex: selected,
                        onDestinationSelected: (value) =>
                            setState(() => selected = value),
                        action: MNavAction(
                          icon: const Icon(LucideIcons.pencilLine),
                          tooltip: 'Compose',
                          onPressed: enabled ? () => actions++ : null,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final ios = platform == TargetPlatform.iOS;
        final capsule = ios
            ? find
                  .byWidgetPredicate(
                    (widget) =>
                        widget is SizedBox &&
                        widget.height == 62 &&
                        widget.width == 292,
                  )
                  .first
            : find.byType(MGlassSurface).first;
        final action = ios
            ? find.byType(glass.GlassButton).first
            : find.byType(MGlassSurface).last;
        final capsuleRect = tester.getRect(capsule);
        final actionRect = tester.getRect(action);
        expect(capsuleRect, Rect.fromLTWH(20, 874 - bottom - 62, 292, 62));
        expect(actionRect.size, const Size.square(62));
        expect(402 - actionRect.right, 20);
        expect(actionRect.left - capsuleRect.right, 8);
        expect(874 - actionRect.bottom, bottom);
        expect(tester.getSize(find.byType(MNavBar)).height, 62 + bottom);
        final iconContext = tester.element(
          find.byIcon(LucideIcons.pencilLine).first,
        );
        expect(
          MediaQuery.textScalerOf(iconContext).scale(10),
          closeTo(11.5, 0.001),
        );
        await tester.tapAt(
          Offset(
            capsuleRect.left + capsuleRect.width / 2,
            capsuleRect.center.dy,
          ),
        );
        await tester.pumpAndSettle();
        expect(selected, 1);
        await tester.tapAt(actionRect.center);
        await tester.pumpAndSettle();
        expect(actions, 1);
        update(() => enabled = false);
        await tester.pumpAndSettle();
        await tester.tapAt(actionRect.center);
        await tester.pumpAndSettle();
        expect(actions, 1);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }
}
