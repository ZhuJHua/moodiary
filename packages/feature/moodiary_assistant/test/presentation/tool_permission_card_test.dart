import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart' as genui;
import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_assistant/src/application/tool_permission_coordinator.dart';
import 'package:moodiary_assistant/src/presentation/tool_permission_card.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';

void main() {
  (ToolPermissionCoordinator, String, Future<ToolPermissionDecision>)
  createCard(AssistantTool tool) {
    String? surfaceId;
    final coordinator = ToolPermissionCoordinator(
      catalog: assistantGenUiCatalog,
      onCardCreated: (id) => surfaceId = id,
    );
    final decision = coordinator.request(tool);
    return (coordinator, surfaceId!, decision);
  }

  Widget host(ToolPermissionCoordinator coordinator, String surfaceId) {
    return MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: genui.Surface(
          surfaceContext: coordinator.surfaces.contextFor(surfaceId),
          actionDelegate: ToolPermissionActionDelegate(
            coordinator.handleAction,
          ),
        ),
      ),
    );
  }

  testWidgets('允许一次：Future 得 allowOnce，卡片原地更新为结果态', (tester) async {
    final (coordinator, surfaceId, decision) = createCard(
      AssistantTool.searchDiaries,
    );

    await tester.pumpWidget(host(coordinator, surfaceId));
    await tester.pumpAndSettle();

    expect(find.text('允许一次'), findsOneWidget);
    expect(find.text('拒绝'), findsOneWidget);

    await tester.tap(find.text('允许一次'));
    await tester.pumpAndSettle();

    expect(await decision, ToolPermissionDecision.allowOnce);
    expect(find.text('已允许本次执行'), findsOneWidget);
    expect(find.text('允许一次'), findsNothing);

    coordinator.dispose();
  });

  testWidgets('危险工具显示警示，拒绝后更新为已拒绝', (tester) async {
    final (coordinator, surfaceId, decision) = createCard(
      AssistantTool.deleteDiary,
    );

    await tester.pumpWidget(host(coordinator, surfaceId));
    await tester.pumpAndSettle();

    expect(find.text('这是危险操作，会修改或删除你的数据，请谨慎确认。'), findsOneWidget);

    await tester.tap(find.text('拒绝'));
    await tester.pumpAndSettle();

    expect(await decision, ToolPermissionDecision.deny);
    expect(find.text('已拒绝执行'), findsOneWidget);

    coordinator.dispose();
  });

  testWidgets('取消在途申请：Future 得 canceled，卡片置为已取消', (tester) async {
    final (coordinator, surfaceId, decision) = createCard(
      AssistantTool.createDiary,
    );

    await tester.pumpWidget(host(coordinator, surfaceId));
    await tester.pumpAndSettle();

    coordinator.cancelPending();
    await tester.pumpAndSettle();

    expect(await decision, ToolPermissionDecision.canceled);
    expect(find.text('已取消'), findsOneWidget);
    expect(find.text('允许一次'), findsNothing);

    coordinator.dispose();
  });
}
