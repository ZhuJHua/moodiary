import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mui/mui.dart';

final _mui = buildMuiTheme(brightness: Brightness.light);

void main() {
  /// 弹窗内部取 `context.muiL10n` 的默认「取消 / 确认」，所以宿主必须挂
  /// [MuiTranslationScope]。
  Widget host(void Function(BuildContext context) onReady) {
    final body = Builder(
      builder: (context) => Center(
        child: TextButton(
          onPressed: () => onReady(context),
          child: const Text('open'),
        ),
      ),
    );
    return MuiTranslationScope(
      child: MuiTheme(
        data: _mui,
        child: MaterialApp(
          theme: _mui,
          locale: const Locale('zh'),
          localizationsDelegates: const [
            // material_ui 自带的那份（不是 flutter_localizations 的），
            // 它给出的才是 material_ui 的 MaterialLocalizations 类型。
            // mui 自己的通用词走 slang，不再有 delegate。
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const [Locale('zh'), Locale('en')],
          home: Scaffold(body: body),
        ),
      ),
    );
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Color backgroundOf(WidgetTester tester, String label) {
    final button = tester.widget<FilledButton>(
      find.ancestor(of: find.text(label), matching: find.byType(FilledButton)),
    );
    return button.style!.backgroundColor!.resolve(<WidgetState>{})!;
  }

  group('MAlert.confirm', () {
    testWidgets('确认返回 true，取消返回 false', (tester) async {
      bool? result;
      await tester.pumpWidget(
        host((context) async {
          result = await MAlert.confirm(
            context,
            title: '清空回收站？',
            message: '将永久删除 24 条日记。',
            confirmLabel: '清空',
          );
        }),
      );

      await open(tester);
      expect(find.text('清空回收站？'), findsOneWidget);
      expect(find.text('将永久删除 24 条日记。'), findsOneWidget);

      await tester.tap(find.text('清空'));
      await tester.pumpAndSettle();
      expect(result, isTrue);

      await open(tester);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });

    testWidgets('点遮罩关闭也返回 false', (tester) async {
      bool? result;
      await tester.pumpWidget(
        host((context) async {
          result = await MAlert.confirm(context, title: '要继续吗？');
        }),
      );

      await open(tester);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });

    testWidgets('isDestructive 用 error 色并自动补警告图标', (tester) async {
      await tester.pumpWidget(
        host(
          (context) => MAlert.confirm(
            context,
            title: '彻底删除？',
            confirmLabel: '删除',
            isDestructive: true,
          ),
        ),
      );
      await open(tester);

      expect(find.byIcon(LucideIcons.triangleAlert), findsOneWidget);
      expect(backgroundOf(tester, '删除'), _mui.colorScheme.error);
      expect(
        backgroundOf(tester, '取消'),
        _mui.colorScheme.surfaceContainerHighest,
      );
    });

    testWidgets('非破坏性确认用 primary 色且不加图标', (tester) async {
      await tester.pumpWidget(
        host(
          (context) =>
              MAlert.confirm(context, title: '数据修复', confirmLabel: '开始修复'),
        ),
      );
      await open(tester);

      expect(find.byIcon(LucideIcons.triangleAlert), findsNothing);
      expect(backgroundOf(tester, '开始修复'), _mui.colorScheme.primary);
    });

    testWidgets('barrierDismissible: false 时点遮罩不关闭', (tester) async {
      await tester.pumpWidget(
        host(
          (context) => MAlert.confirm(
            context,
            title: '加密云端已有数据',
            barrierDismissible: false,
          ),
        ),
      );

      await open(tester);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('加密云端已有数据'), findsOneWidget);
    });
  });

  group('MAlert.prompt', () {
    testWidgets('返回输入值，取消返回 null', (tester) async {
      String? result = 'sentinel';
      await tester.pumpWidget(
        host((context) async {
          result = await MAlert.prompt(context, title: '新建分类');
        }),
      );

      await open(tester);
      await tester.enterText(find.byType(TextField), '  旅行  ');
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
      expect(result, '旅行', reason: 'trim 默认开');

      await open(tester);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(result, isNull);
    });

    testWidgets('trim: false 保留原样（密码场景）', (tester) async {
      String? result;
      await tester.pumpWidget(
        host((context) async {
          result = await MAlert.prompt(
            context,
            title: '加密密码',
            obscureText: true,
            trim: false,
          );
        }),
      );

      await open(tester);
      await tester.enterText(find.byType(TextField), ' pw ');
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
      expect(result, ' pw ');
    });

    testWidgets('validator 拦住空值：弹窗不关且显示错误', (tester) async {
      var resolved = false;
      await tester.pumpWidget(
        host((context) async {
          await MAlert.prompt(
            context,
            title: '加密密码',
            validator: (value) => value.isEmpty ? '请输入密码' : null,
          );
          resolved = true;
        }),
      );

      await open(tester);
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();

      expect(find.text('请输入密码'), findsOneWidget);
      expect(find.text('加密密码'), findsOneWidget);
      expect(resolved, isFalse);
    });

    testWidgets('onSubmit 失败保留弹窗与已输入内容，成功才关闭', (tester) async {
      String? result;
      var attempts = 0;
      await tester.pumpWidget(
        host((context) async {
          result = await MAlert.prompt(
            context,
            title: '远端备份已加密',
            obscureText: true,
            trim: false,
            onSubmit: (value) async {
              attempts++;
              return value == 'right' ? null : '密码不正确，无法解密远端数据';
            },
          );
        }),
      );

      await open(tester);
      await tester.enterText(find.byType(TextField), 'wrong');
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();

      expect(attempts, 1);
      expect(find.text('密码不正确，无法解密远端数据'), findsOneWidget);
      expect(find.text('远端备份已加密'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'wrong',
        reason: '失败后已输入内容要留住',
      );

      await tester.enterText(find.byType(TextField), 'right');
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();

      expect(attempts, 2);
      expect(result, 'right');
      expect(find.text('远端备份已加密'), findsNothing);
    });

    testWidgets('onSubmit 执行期间确认键转圈、取消键禁用', (tester) async {
      final gate = Completer<String?>();
      await tester.pumpWidget(
        host(
          (context) => MAlert.prompt(
            context,
            title: '验证中',
            onSubmit: (_) => gate.future,
          ),
        ),
      );

      await open(tester);
      await tester.enterText(find.byType(TextField), 'x');
      await tester.tap(find.text('确认'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final cancel = tester.widget<FilledButton>(
        find.ancestor(of: find.text('取消'), matching: find.byType(FilledButton)),
      );
      expect(cancel.onPressed, isNull);

      gate.complete(null);
      await tester.pumpAndSettle();
      expect(find.text('验证中'), findsNothing);
    });

    testWidgets('数字键盘与 formatter 透传', (tester) async {
      String? result;
      await tester.pumpWidget(
        host((context) async {
          result = await MAlert.prompt(
            context,
            title: '生成数量',
            hintText: '1–500',
            keyboardType: .number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (value) {
              final n = int.tryParse(value);
              if (n == null || n < 1 || n > 500) return '数量需在 1–500 之间';
              return null;
            },
          );
        }),
      );

      await open(tester);
      await tester.enterText(find.byType(TextField), '12a3');
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
      expect(result, '123', reason: 'digitsOnly 生效');
    });

    testWidgets('校验不通过时弹窗留在原地，错误随重新提交刷新', (tester) async {
      await tester.pumpWidget(
        host(
          (context) => MAlert.prompt(
            context,
            title: '生成数量',
            validator: (value) => int.tryParse(value) == null ? '请输入数字' : null,
          ),
        ),
      );

      await open(tester);
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
      expect(find.text('请输入数字'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '7');
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
      expect(find.text('生成数量'), findsNothing);
    });
  });

  group('MAlert.notice', () {
    testWidgets('只有一颗按钮，点了就关', (tester) async {
      var closed = false;
      await tester.pumpWidget(
        host((context) async {
          await MAlert.notice(
            context,
            title: '修复完成',
            message: '共扫描 128 篇日记。\n修复 6 篇：\n· 卡片预览 4 篇',
            closeLabel: '好',
          );
          closed = true;
        }),
      );

      await open(tester);
      expect(find.byType(FilledButton), findsOneWidget);

      await tester.tap(find.text('好'));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(find.text('修复完成'), findsNothing);
    });
  });

  group('按钮排布', () {
    Future<void> pumpActions(
      WidgetTester tester,
      List<MAction<int>> actions, {
      MActionsLayout layout = .auto,
    }) async {
      await tester.pumpWidget(
        host(
          (context) => MAlert.show<int>(
            context,
            title: '排布',
            actions: actions,
            actionsLayout: layout,
          ),
        ),
      );
      await open(tester);
    }

    testWidgets('两个短标签横排：取消在左、主操作在右', (tester) async {
      await pumpActions(tester, const [
        MAction(label: '取消', value: 0),
        MAction(label: '删除', value: 1, isDestructive: true),
      ]);

      final cancel = tester.getCenter(find.text('取消'));
      final confirm = tester.getCenter(find.text('删除'));
      expect(cancel.dx, lessThan(confirm.dx));
      expect(cancel.dy, closeTo(confirm.dy, 0.5));
    });

    testWidgets('三个动作竖排且反序：主操作在上、取消在最下', (tester) async {
      await pumpActions(tester, const [
        MAction(label: '取消', value: 0),
        MAction(label: '清除压测数据', value: 1, isDestructive: true),
        MAction(label: '生成', value: 2, isPrimary: true),
      ]);

      final generate = tester.getCenter(find.text('生成'));
      final clear = tester.getCenter(find.text('清除压测数据'));
      final cancel = tester.getCenter(find.text('取消'));
      expect(generate.dy, lessThan(clear.dy));
      expect(clear.dy, lessThan(cancel.dy));
      expect(generate.dx, closeTo(cancel.dx, 0.5));
    });

    testWidgets('两个长标签放不下时自动竖排', (tester) async {
      await pumpActions(tester, const [
        MAction(label: '我再想想，先不要动我的数据', value: 0),
        MAction(label: '我确认要永久删除全部内容', value: 1, isDestructive: true),
      ]);

      final cancel = tester.getCenter(find.text('我再想想，先不要动我的数据'));
      final confirm = tester.getCenter(find.text('我确认要永久删除全部内容'));
      expect(confirm.dy, lessThan(cancel.dy), reason: '竖排时主操作在上');
    });

    testWidgets('layout: horizontal 可以强制横排', (tester) async {
      await pumpActions(tester, const [
        MAction(label: '我再想想，先不要动我的数据', value: 0),
        MAction(label: '我确认要永久删除全部内容', value: 1),
      ], layout: .horizontal);

      final cancel = tester.getCenter(find.text('我再想想，先不要动我的数据'));
      final confirm = tester.getCenter(find.text('我确认要永久删除全部内容'));
      expect(cancel.dy, closeTo(confirm.dy, 0.5));
    });

    testWidgets('enabled: false 的动作不可点', (tester) async {
      await pumpActions(tester, const [
        MAction(label: '取消', value: 0),
        MAction(label: '删除', value: 1, enabled: false),
      ]);

      final button = tester.widget<FilledButton>(
        find.ancestor(of: find.text('删除'), matching: find.byType(FilledButton)),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('MAlert.show', () {
    testWidgets('返回被点动作的 value', (tester) async {
      int? result;
      await tester.pumpWidget(
        host((context) async {
          result = await MAlert.show<int>(
            context,
            title: '选一个',
            actions: const [
              MAction(label: '取消', value: 0),
              MAction(label: '继续', value: 42, isPrimary: true),
            ],
          );
        }),
      );

      await open(tester);
      await tester.tap(find.text('继续'));
      await tester.pumpAndSettle();
      expect(result, 42);
    });

    testWidgets('onIntercept 返回 false 时不关闭', (tester) async {
      var taps = 0;
      var closed = false;
      await tester.pumpWidget(
        host((context) async {
          await MAlert.show<bool>(
            context,
            title: '新建分类',
            content: const Text('色板占位'),
            actions: [
              const MAction(label: '取消', value: false),
              MAction(
                label: '确认',
                value: true,
                isPrimary: true,
                onIntercept: () => ++taps > 1,
              ),
            ],
          );
          closed = true;
        }),
      );

      await open(tester);
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
      expect(find.text('新建分类'), findsOneWidget, reason: '第一次被拦下');
      expect(closed, isFalse);

      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(taps, 2);
    });

    testWidgets('一句话正文居中，分段长文左对齐', (tester) async {
      await tester.pumpWidget(
        host(
          (context) => MAlert.show<void>(
            context,
            title: '导入本地备份',
            message: '· 同名条目按修改时间取新\n· 远端不存在的条目会被补齐\n· 本地多出的条目保持不变',
            actions: const [MAction(label: '取消')],
          ),
        ),
      );
      await open(tester);
      expect(
        tester.widget<Text>(find.textContaining('同名条目')).textAlign,
        TextAlign.start,
      );

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        host(
          (context) => MAlert.show<void>(
            context,
            title: '清空日志',
            message: '操作不可恢复。',
            actions: const [MAction(label: '取消')],
          ),
        ),
      );
      await open(tester);
      expect(
        tester.widget<Text>(find.text('操作不可恢复。')).textAlign,
        TextAlign.center,
      );
    });

    testWidgets('content 被渲染在正文下方', (tester) async {
      await tester.pumpWidget(
        host(
          (context) => MAlert.show<void>(
            context,
            title: '新建分类',
            message: '分类只影响筛选。',
            content: const Text('色板占位'),
            actions: const [MAction(label: '取消')],
          ),
        ),
      );

      await open(tester);
      final message = tester.getCenter(find.text('分类只影响筛选。'));
      final content = tester.getCenter(find.text('色板占位'));
      expect(message.dy, lessThan(content.dy));
    });
  });
}
