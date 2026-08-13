import 'package:flutter_test/flutter_test.dart';
import 'package:mui/mui.dart';

final _mui = buildMuiTheme(brightness: Brightness.light);

void main() {
  /// 弹窗内部取 `context.l10n` 的默认「取消」，所以宿主必须装 delegate。
  Widget host(void Function(BuildContext context) onReady) {
    final body = Builder(
      builder: (context) => Center(
        child: TextButton(
          onPressed: () => onReady(context),
          child: const Text('open'),
        ),
      ),
    );
    return MuiTheme(
      data: _mui,
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: const [
          MuiLocalizations.delegate,
          // material_ui 自带的那份（不是 flutter_localizations 的），
          // 它给出的才是 material_ui 的 MaterialLocalizations 类型。
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: MuiLocalizations.supportedLocales,
        home: Scaffold(body: body),
      ),
    );
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// 抓手在内容上方 48（kMinInteractiveDimension）那条里，居中。
  Offset handleOf(WidgetTester tester) {
    final rect = tester.getRect(find.byType(MSheetScaffold<void>));
    return Offset(rect.center.dx, rect.top - 24);
  }

  group('MSheet.show', () {
    testWidgets('返回被点动作的 value，点遮罩返回 null', (tester) async {
      String? result = 'sentinel';
      await tester.pumpWidget(
        host((context) async {
          result = await MSheet.show<String>(
            context,
            builder: (_) => const MSheetScaffold<String>(
              title: 'WebDAV',
              actions: [
                MAction(label: '取消'),
                MAction(label: '保存', value: 'saved', isPrimary: true),
              ],
              child: Text('表单占位'),
            ),
          );
        }),
      );

      await open(tester);
      expect(find.text('WebDAV'), findsOneWidget);
      expect(find.text('表单占位'), findsOneWidget);

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(result, 'saved');

      await open(tester);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(result, isNull);
    });

    testWidgets('动作条在内容之下，且不随内容滚动', (tester) async {
      await tester.pumpWidget(
        host(
          (context) => MSheet.show<void>(
            context,
            builder: (_) => MSheetScaffold<void>(
              title: '长表单',
              actions: const [MAction(label: '保存', isPrimary: true)],
              child: Column(
                mainAxisSize: .min,
                children: [
                  for (var i = 0; i < 40; i++)
                    SizedBox(height: 40, child: Text('行 $i')),
                ],
              ),
            ),
          ),
        ),
      );
      await open(tester);

      final footer = tester.getRect(find.text('保存'));
      final title = tester.getRect(find.text('长表单'));
      expect(title.top, lessThan(footer.top));

      // 内容滚到底后按钮仍在原位 —— 固定动作条的全部意义。
      await tester.drag(find.text('行 3'), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('保存')), footer);
    });

    testWidgets('下拉能关闭（官方默认整卡可拖）', (tester) async {
      var closed = false;
      await tester.pumpWidget(
        host((context) async {
          await MSheet.show<void>(
            context,
            builder: (_) => const MSheetScaffold<void>(
              title: '可下拉',
              child: SizedBox(height: 200),
            ),
          );
          closed = true;
        }),
      );

      await open(tester);
      await tester.dragFrom(handleOf(tester), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
    });
  });

  group('容器形态', () {
    Future<void> openPlain(WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          (context) => MSheet.show<void>(
            context,
            builder: (_) => const MSheetScaffold<void>(
              title: '同步方式',
              child: SizedBox(height: 120),
            ),
          ),
        ),
      );
      await open(tester);
    }

    testWidgets('贴住屏幕下沿，宽屏限宽 640 居中', (tester) async {
      tester.view.physicalSize = const Size(2400, 1800); // 800 × 600
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await openPlain(tester);
      final rect = tester.getRect(find.byType(MSheetScaffold<void>));
      expect(rect.bottom, 600, reason: '不是浮起卡，底边贴屏');
      expect(rect.width, 640, reason: 'M3 给的宽度上限');
      expect(rect.center.dx, 400, reason: '超过上限后居中');
    });

    testWidgets('内容超过可用高度时滚动，不再被自定义上限截断', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400); // 360 × 800
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        host(
          (context) => MSheet.show<void>(
            context,
            builder: (_) => MSheetScaffold<void>(
              title: '长表单',
              actions: const [MAction(label: '保存', isPrimary: true)],
              child: Column(
                mainAxisSize: .min,
                children: [
                  for (var i = 0; i < 60; i++)
                    SizedBox(height: 40, child: Text('行 $i')),
                ],
              ),
            ),
          ),
        ),
      );
      await open(tester);

      // isScrollControlled: true 下官方上限就是可用高度本身，顶到屏幕顶为止。
      final rect = tester.getRect(find.byType(MSheetScaffold<void>));
      expect(rect.bottom, 800);
      // 48 是官方抓手预留的高度，内容从这里开始 —— 也就是弹窗本身已经顶到屏幕顶。
      expect(rect.top, 48, reason: '够高就该顶满，不留 10% 的自定义余量');
      expect(tester.takeException(), isNull);

      // 超出的部分靠内容区滚动吸收，动作条不动。
      final footer = tester.getRect(find.text('保存'));
      await tester.drag(find.text('行 3'), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('保存')), footer);
    });

    testWidgets('窄屏铺满宽度', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400); // 360 × 800
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await openPlain(tester);
      final rect = tester.getRect(find.byType(MSheetScaffold<void>));
      expect(rect.left, 0);
      expect(rect.width, 360);
    });

    testWidgets('内容让开手势条', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      // padding 与 viewPadding 是两个字段，MediaQuery.viewPadding 只看后者。
      const inset = FakeViewPadding(bottom: 90); // 30 逻辑像素
      tester.view.padding = inset;
      tester.view.viewPadding = inset;
      addTearDown(tester.view.reset);

      await openPlain(tester);
      final rect = tester.getRect(find.byType(MSheetScaffold<void>));
      expect(rect.bottom, 770, reason: '弹窗自己压着安全区，内容要抬起来');
    });
  });

  group('下拉关闭的边角', () {
    testWidgets('矮窗口下头部折进滚动区，不撑破 Column', (tester) async {
      tester.view.physicalSize = const Size(1200, 540);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        host(
          (context) => MSheet.show<void>(
            context,
            builder: (_) => const MSheetScaffold<void>(
              title: 'WebDAV',
              subtitle: '已配置',
              icon: LucideIcons.cloud,
              actions: [
                MAction(label: '取消'),
                MAction(label: '保存', isPrimary: true),
              ],
              child: SizedBox(height: 400),
            ),
          ),
        ),
      );
      await open(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('保存'), findsOneWidget, reason: '动作条不能被挤掉');
    });
  });

  group('无障碍', () {
    testWidgets('路由名用「底部弹窗」而不是遮罩的「关闭」', (tester) async {
      final handle = tester.ensureSemantics();
      late MaterialLocalizations localizations;
      await tester.pumpWidget(
        host((context) {
          localizations = .of(context);
          MSheet.show<void>(
            context,
            builder: (_) => const MSheetScaffold<void>(
              title: '同步状态',
              child: SizedBox(height: 80),
            ),
          );
        }),
      );
      await open(tester);

      expect(find.bySemanticsLabel(localizations.bottomSheetLabel), findsOne);
      handle.dispose();
    });

    testWidgets('选中的选项行带 isSelected 标志', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(
          (context) => MSheet.picker<int>(
            context,
            title: '同步方式',
            selected: 1,
            options: const [
              MSheetOption(value: 1, label: 'WebDAV'),
              MSheetOption(value: 2, label: 'S3 / MinIO'),
            ],
          ),
        ),
      );
      await open(tester);

      bool selectedOf(String label) =>
          tester.getSemantics(find.text(label)).flagsCollection.isSelected ==
          .isTrue;
      expect(selectedOf('WebDAV'), isTrue);
      expect(selectedOf('S3 / MinIO'), isFalse);
      handle.dispose();
    });
  });

  group('MSheet.picker', () {
    testWidgets('点中选项即返回其值，取消返回 null', (tester) async {
      int? picked = -1;
      await tester.pumpWidget(
        host((context) async {
          picked = await MSheet.picker<int>(
            context,
            title: '同步方式',
            selected: 1,
            options: const [
              MSheetOption(value: 1, label: 'WebDAV'),
              MSheetOption(value: 2, label: 'S3 / MinIO'),
            ],
          );
        }),
      );

      await open(tester);
      await tester.tap(find.text('S3 / MinIO'));
      await tester.pumpAndSettle();
      expect(picked, 2);

      await open(tester);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(picked, isNull);
    });

    testWidgets('选中项打对勾，未选中项不打', (tester) async {
      await tester.pumpWidget(
        host(
          (context) => MSheet.picker<int>(
            context,
            title: '同步方式',
            selected: 1,
            options: const [
              MSheetOption(value: 1, label: 'WebDAV'),
              MSheetOption(value: 2, label: 'S3 / MinIO'),
            ],
          ),
        ),
      );
      await open(tester);
      expect(find.byIcon(LucideIcons.check), findsOneWidget);
    });

    testWidgets('enabled: false 的选项点不动', (tester) async {
      int? picked;
      await tester.pumpWidget(
        host((context) async {
          picked = await MSheet.picker<int>(
            context,
            title: '同步方式',
            options: const [
              MSheetOption(value: 1, label: 'WebDAV', enabled: false),
            ],
          );
        }),
      );
      await open(tester);
      await tester.tap(find.text('WebDAV'));
      await tester.pumpAndSettle();
      expect(find.text('同步方式'), findsOneWidget);
      expect(picked, isNull);
    });
  });

  group('MField', () {
    Widget fieldHost(Widget child) => MuiTheme(
      data: _mui,
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: const [
          MuiLocalizations.delegate,
          // material_ui 自带的那份（不是 flutter_localizations 的），
          // 它给出的才是 material_ui 的 MaterialLocalizations 类型。
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: MuiLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );

    testWidgets('有内容才出清除键，点了清空', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        fieldHost(MField(controller: controller, label: '服务器地址')),
      );

      expect(find.text('服务器地址'), findsOneWidget);
      expect(find.byIcon(LucideIcons.x), findsNothing);

      await tester.enterText(find.byType(TextField), 'https://dav.example.com');
      await tester.pump();
      expect(find.byIcon(LucideIcons.x), findsOneWidget);

      await tester.tap(find.byIcon(LucideIcons.x));
      await tester.pump();
      expect(controller.text, isEmpty);
      expect(find.byIcon(LucideIcons.x), findsNothing);
    });

    testWidgets('密码框给眼睛不给清除键，点了切换明文', (tester) async {
      final controller = TextEditingController(text: 'secret');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        fieldHost(
          MField(controller: controller, label: '密码', obscureText: true),
        ),
      );

      expect(find.byIcon(LucideIcons.x), findsNothing);
      expect(find.byIcon(LucideIcons.eyeOff), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isTrue,
      );

      await tester.tap(find.byIcon(LucideIcons.eyeOff));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isFalse,
      );
    });

    testWidgets('errorText 显示在框下方', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        fieldHost(
          MField(
            controller: controller,
            label: 'Bucket',
            errorText: 'Bucket 不能为空',
          ),
        ),
      );
      expect(find.text('Bucket 不能为空'), findsOneWidget);
    });

    testWidgets('禁用时尾部槽位一并消失', (tester) async {
      final controller = TextEditingController(text: 'moodiary');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        fieldHost(
          MField(controller: controller, label: '用户名', enabled: false),
        ),
      );
      expect(find.byIcon(LucideIcons.x), findsNothing);
    });
  });
}
