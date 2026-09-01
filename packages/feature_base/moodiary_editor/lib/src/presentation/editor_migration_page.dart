import 'dart:io';

import 'package:flutter/services.dart' show SystemNavigator;
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_editor/src/data/editor_migration_service.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_logging/moodiary_logging.dart' show logger;
import 'package:moodiary_migration/moodiary_migration.dart'
    show EngineMigrationService;
import 'package:moodiary_router/moodiary_router.dart';
import 'package:mui/mui.dart';
import 'package:share_plus/share_plus.dart';

/// 强制迁移页（启动闸门）：存在旧引擎库或旧格式日记时，路由 redirect 把一切目的地
/// 重定向到这里，迁移完成前进不了主界面。**不自动开跑**：由用户点「开始迁移」才执行，
/// 否则只能退出应用。逐篇独立事务 + 转换前 sidecar 备份，失败重试不丢数据；
/// 失败时落一份不含正文的日志，可经系统分享面板发出。
class EditorMigrationPage extends StatefulWidget {
  const EditorMigrationPage({super.key});

  @override
  State<EditorMigrationPage> createState() => _EditorMigrationPageState();
}

enum _Phase { landing, running, failed, done }

enum _Stage { engine, editor }

class _EditorMigrationPageState extends State<EditorMigrationPage> {
  _Phase _phase = .landing;

  /// 正在执行的阶段；running 之外无意义。
  _Stage? _activeStage;
  int _done = 0;
  int _total = 0;

  /// 失败态的归因：引擎阶段整体抛出，或正文阶段的逐篇失败数。
  bool _engineFailed = false;
  int _editorFailed = 0;
  String? _logPath;

  int _summaryDiaries = 0;
  int _summaryCategories = 0;

  Future<void> _run() async {
    setState(() {
      _phase = .running;
      _activeStage = null;
      _done = 0;
      _total = 0;
      _engineFailed = false;
      _editorFailed = 0;
      _logPath = null;
    });
    // 整段兜底：这里是强制闸门里唯一的页面，任何未捕获异常都会让进度永久停住、
    // 重试按钮渲染不出来，用户被锁死在门外。
    try {
      // 阶段一：引擎搬迁（旧 Isar → SQLite）。可重入：标记只在对账通过后置位，
      // 中途被杀下次启动整库重来；旧库全程只读。
      if (EngineMigrationService.requiresMigration) {
        setState(() => _activeStage = .engine);
        await EngineMigrationService.migrate(
          onProgress: (done, total) {
            if (mounted) {
              setState(() {
                _done = done;
                _total = total;
              });
            }
          },
        );
        await EngineMigrationService.finalizeMigration();
        // 阶段二的判据此刻才有意义：正文格式闸门查的是刚灌满的 SQLite。
        await EditorMigrationService.refreshRequiresMigration();
        if (!mounted) return;
        setState(() {
          _activeStage = null;
          _done = 0;
          _total = 0;
        });
      }
      final pending = await EditorMigrationService.pendingDiaries();
      if (!mounted) return;
      setState(() {
        _activeStage = .editor;
        _total = pending.length;
      });
      final report = await EditorMigrationService.migrateAll(
        pending,
        onProgress: (done, total) {
          if (mounted) setState(() => _done = done);
        },
      );
      if (!mounted) return;
      if (report.failed > 0) {
        final logPath = await _writeFailureLog(
          stage: 'editor',
          failures: report.failures,
        );
        if (!mounted) return;
        setState(() {
          _phase = .failed;
          _editorFailed = report.failed;
          _logPath = logPath;
        });
        return;
      }
    } catch (e, s) {
      // 引擎阶段的异常同样可能是 drift/sqlite3 的、带着绑定参数（正文）的那种。
      final redacted = EditorMigrationService.redactDbError(e);
      logger.e('forced migration failed', error: redacted, stackTrace: s);
      final engineFailed = _activeStage == .engine;
      String? logPath;
      try {
        logPath = await _writeFailureLog(
          stage: engineFailed ? 'engine' : 'editor',
          error: redacted,
          stackTrace: s,
        );
      } catch (e, s) {
        logger.e('write migration failure log failed', error: e, stackTrace: s);
      }
      if (!mounted) return;
      setState(() {
        _phase = .failed;
        _engineFailed = engineFailed;
        _logPath = logPath;
      });
      return;
    }
    EditorMigrationService.requiresMigration = false;
    // 完成页摘要。取数失败不挡完成态——摘要是锦上添花，闸门已放行。
    var diaries = 0;
    var categories = 0;
    try {
      diaries = await DiaryRepository.get().countAllDiaries();
      categories = (await CategoryRepository.get().getAllCategories()).length;
    } catch (e, s) {
      logger.e('load migration summary failed', error: e, stackTrace: s);
    }
    if (!mounted) return;
    setState(() {
      _phase = .done;
      _summaryDiaries = diaries;
      _summaryCategories = categories;
    });
  }

  /// 失败日志落盘。只写阶段、**已脱敏的**异常与失败日记的 id——不含正文、标题等
  /// 任何隐私内容（页脚文案对用户是这么承诺的，脱敏见
  /// [EditorMigrationService.redactDbError]）。
  Future<String> _writeFailureLog({
    required String stage,
    String? error,
    StackTrace? stackTrace,
    List<MigrationFailure> failures = const [],
  }) async {
    final buffer = StringBuffer()
      ..writeln('Moodiary migration failure log')
      ..writeln('time: ${DateTime.now().toIso8601String()}')
      ..writeln('stage: $stage');
    if (error != null) {
      buffer
        ..writeln('error: $error')
        ..writeln(stackTrace ?? '');
    }
    for (final f in failures) {
      buffer
        ..writeln('--- diary ${f.diaryId}')
        ..writeln(f.error)
        ..writeln(f.stackTrace);
    }
    final path = AppFiles.getCachePath('migration_failure.log');
    await File(path).writeAsString(buffer.toString());
    return path;
  }

  Future<void> _shareLog() async {
    final path = _logPath;
    if (path == null) return;
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path, mimeType: 'text/plain')]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const .symmetric(horizontal: 24),
          child: switch (_phase) {
            .landing => _buildLanding(context),
            .running => _buildRunning(context),
            .failed => _buildFailed(context),
            .done => _buildDone(context),
          },
        ),
      ),
    );
  }

  Widget _buildLanding(BuildContext context) {
    final theme = context.theme;
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        _Header(
          icon: LucideIcons.database,
          color: theme.colors.primary,
          title: l10n.editor.migrationTitle,
          subtitle: l10n.editor.migrationIntro,
        ),
        const SizedBox(height: 32),
        _Card(
          children: [
            _StepRow(
              icon: LucideIcons.database,
              title: l10n.editor.migrationStepEngine,
              subtitle: l10n.editor.migrationStepEngineDesc,
            ),
            _StepRow(
              icon: LucideIcons.fileText,
              title: l10n.editor.migrationStepEditor,
              subtitle: l10n.editor.migrationStepEditorDesc,
            ),
          ],
        ),
        const Spacer(),
        SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: _run,
            child: Text(l10n.editor.migrationStart),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: TextButton(
            onPressed: SystemNavigator.pop,
            child: Text(l10n.editor.migrationExit),
          ),
        ),
        _Footnote(text: l10n.editor.migrationLandingNote),
      ],
    );
  }

  Widget _buildRunning(BuildContext context) {
    final theme = context.theme;
    final l10n = context.l10n;
    final engineRunning = _activeStage == .engine;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        _Header(
          icon: LucideIcons.refreshCw,
          color: theme.colors.primary,
          title: l10n.editor.migrationRunningTitle,
          subtitle: l10n.editor.migrationRunningSubtitle,
        ),
        const SizedBox(height: 32),
        _Card(
          children: [
            _StepRow(
              icon: engineRunning
                  ? LucideIcons.database
                  : LucideIcons.circleCheck,
              title: l10n.editor.migrationStepEngine,
              trailing: engineRunning
                  ? '$_done / $_total'
                  : l10n.editor.migrationStageDone,
              progress: engineRunning
                  ? (_total == 0 ? null : _done / _total)
                  : null,
              showProgress: engineRunning,
            ),
            _StepRow(
              icon: LucideIcons.fileText,
              title: l10n.editor.migrationStepEditor,
              trailing: engineRunning ? null : '$_done / $_total',
              progress: engineRunning
                  ? null
                  : (_total == 0 ? null : _done / _total),
              showProgress: !engineRunning,
            ),
          ],
        ),
        const Spacer(),
        _Footnote(text: l10n.editor.migrationDataSafeNote),
      ],
    );
  }

  Widget _buildFailed(BuildContext context) {
    final theme = context.theme;
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        _Header(
          icon: LucideIcons.circleAlert,
          color: theme.colors.error,
          title: _editorFailed > 0
              ? l10n.editor.migrationFailedTitle
              : l10n.editor.migrationErrorTitle,
          subtitle: _editorFailed > 0
              ? l10n.editor.migrationFailedSubtitle(count: _editorFailed)
              : l10n.editor.migrationErrorSubtitle,
        ),
        const SizedBox(height: 32),
        _Card(
          children: [
            _StepRow(
              icon: _engineFailed
                  ? LucideIcons.circleAlert
                  : LucideIcons.circleCheck,
              iconColor: _engineFailed ? theme.colors.error : null,
              title: l10n.editor.migrationStepEngine,
              trailing: _engineFailed
                  ? l10n.editor.migrationStageFailed
                  : l10n.editor.migrationStageDone,
              trailingError: _engineFailed,
            ),
            _StepRow(
              icon: _editorFailed > 0
                  ? LucideIcons.circleAlert
                  : LucideIcons.fileText,
              iconColor: _editorFailed > 0 ? theme.colors.error : null,
              title: l10n.editor.migrationStepEditor,
              trailing: _editorFailed > 0
                  ? l10n.editor.migrationStageFailedCount(count: _editorFailed)
                  : (_engineFailed
                        ? l10n.editor.migrationStagePending
                        : l10n.editor.migrationStageFailed),
              trailingError: _editorFailed > 0 || !_engineFailed,
            ),
          ],
        ),
        const Spacer(),
        SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: _run,
            child: Text(l10n.editor.migrationRetry),
          ),
        ),
        if (_logPath != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _shareLog,
              icon: const Icon(LucideIcons.share2, size: 18),
              label: Text(l10n.editor.migrationShareLog),
            ),
          ),
        ],
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: TextButton(
            onPressed: SystemNavigator.pop,
            child: Text(l10n.editor.migrationExit),
          ),
        ),
        _Footnote(text: l10n.editor.migrationFailedNote),
      ],
    );
  }

  Widget _buildDone(BuildContext context) {
    final theme = context.theme;
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        _Header(
          icon: LucideIcons.circleCheck,
          color: theme.colors.primary,
          title: l10n.editor.migrationDoneTitle,
          subtitle: l10n.editor.migrationDoneSubtitle,
        ),
        const SizedBox(height: 32),
        _Card(
          children: [
            _SummaryRow(
              label: l10n.editor.migrationSummaryDiaries,
              value: l10n.editor.migrationSummaryDiariesCount(
                count: _summaryDiaries,
              ),
            ),
            _SummaryRow(
              label: l10n.editor.migrationSummaryCategories,
              value: l10n.editor.migrationSummaryCategoriesCount(
                count: _summaryCategories,
              ),
            ),
            _SummaryRow(
              label: l10n.editor.migrationSummaryMedia,
              value: l10n.editor.migrationSummaryMigrated,
            ),
          ],
        ),
        const Spacer(),
        SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: () => const DiaryHomeRoute().go(context),
            child: Text(l10n.editor.migrationEnter),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Column(
      children: [
        const SizedBox(height: 72),
        Icon(icon, size: 48, color: color),
        const SizedBox(height: 20),
        Text(
          title,
          style: theme.typography.titleLarge.onSurface,
          textAlign: .center,
        ),
        const SizedBox(height: 20),
        Text(
          subtitle,
          style: theme.typography.bodyMedium.secondary,
          textAlign: .center,
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.surfaceContainerLow,
        borderRadius: .circular(theme.radii.lg),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Divider(thickness: 0, height: 1, indent: 16, endIndent: 16),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.trailingError = false,
    this.iconColor,
    this.progress,
    this.showProgress = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailing;
  final bool trailingError;
  final Color? iconColor;

  /// null + [showProgress] = 不确定进度。
  final double? progress;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Padding(
      padding: const .all(16),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          Row(
            crossAxisAlignment: subtitle == null ? .center : .start,
            children: [
              Icon(icon, size: 20, color: iconColor ?? theme.colors.onSurface),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    Text(title, style: theme.typography.titleSmall.onSurface),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: theme.typography.bodySmall.secondary,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 16),
                Text(
                  trailing!,
                  style: trailingError
                      ? theme.typography.bodySmall.error
                      : theme.typography.bodySmall.secondary,
                ),
              ],
            ],
          ),
          if (showProgress) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Padding(
      padding: const .all(16),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: theme.typography.bodyMedium.onSurface),
          ),
          Text(value, style: theme.typography.bodyMedium.secondary),
        ],
      ),
    );
  }
}

class _Footnote extends StatelessWidget {
  const _Footnote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .only(top: 16, bottom: 24),
      child: Text(
        text,
        style: context.theme.typography.bodySmall.secondary,
        textAlign: .center,
      ),
    );
  }
}
