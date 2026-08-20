import 'package:moodiary_editor/src/data/editor_migration_service.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_logging/moodiary_logging.dart' show logger;
import 'package:moodiary_router/moodiary_router.dart';
import 'package:mui/mui.dart';

/// 强制迁移页（启动闸门）：存在旧格式（richText / markdown）日记时，路由 redirect 把
/// 一切目的地重定向到这里，迁移完成前进不了主界面。进入即自动开跑；逐篇独立事务 +
/// 转换前 sidecar 备份，中途退出不丢数据，下次启动从剩余部分继续。
class EditorMigrationPage extends StatefulWidget {
  const EditorMigrationPage({super.key});

  @override
  State<EditorMigrationPage> createState() => _EditorMigrationPageState();
}

class _EditorMigrationPageState extends State<EditorMigrationPage> {
  int _done = 0;
  int _total = 0;
  int _failed = 0;
  bool _running = true;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _running = true;
      _failed = 0;
      _done = 0;
    });
    // 整段兜底：这里是强制闸门里唯一的页面，任何未捕获异常（列待迁移、逐篇落库之外的
    // I/O）都会让进度条永久停住、重试按钮渲染不出来，用户被锁死在门外。
    try {
      final pending = await EditorMigrationService.pendingDiaries();
      if (!mounted) return;
      setState(() => _total = pending.length);
      final report = await EditorMigrationService.migrateAll(
        pending,
        onProgress: (done, total) {
          if (mounted) setState(() => _done = done);
        },
      );
      if (!mounted) return;
      if (report.failed > 0) {
        setState(() {
          _running = false;
          _failed = report.failed;
        });
        return;
      }
    } catch (e, s) {
      logger.e('forced migration failed', error: e, stackTrace: s);
      if (!mounted) return;
      setState(() => _running = false);
      return;
    }
    EditorMigrationService.requiresMigration = false;
    // 迁移中退后台会被「立即锁定」压上锁屏页；此刻 go('/') 是整栈替换，会把锁屏
    // 一并抹掉绕过应用锁。不是栈顶就按兵不动——解锁后锁屏页自己 go('/')，闸门已放行。
    if (ModalRoute.of(context)?.isCurrent ?? true) {
      const DiaryHomeRoute().go(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n.editor;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const .symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: .min,
              children: [
                Icon(
                  _running ? LucideIcons.wandSparkles : LucideIcons.circleAlert,
                  size: 48,
                  color: _running
                      ? context.theme.colors.primary
                      : context.theme.colors.error,
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.migrationTitle,
                  style: context.theme.typography.titleLarge.primary,
                  textAlign: .center,
                ),
                const SizedBox(height: 28),
                if (_running) ...[
                  LinearProgressIndicator(
                    value: _total == 0 ? null : _done / _total,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.migrationProgress(done: _done, total: _total),
                    style: context.theme.typography.bodyMedium.secondary,
                  ),
                ] else ...[
                  Text(
                    _failed > 0
                        ? l10n.migrationFailedCount(count: _failed)
                        : l10n.migrationError,
                    style: context.theme.typography.bodyMedium.primary,
                    textAlign: .center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _run,
                    child: Text(l10n.migrationRetry),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  l10n.migrationNote,
                  style: context.theme.typography.bodySmall.secondary,
                  textAlign: .center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
