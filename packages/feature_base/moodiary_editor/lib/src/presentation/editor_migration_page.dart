import 'dart:io';

import 'package:flutter/services.dart' show SystemNavigator;
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_editor/src/data/editor_migration_service.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_logging/moodiary_logging.dart' show logger;
import 'package:moodiary_migration/moodiary_migration.dart'
    show EngineMigrationService;
import 'package:moodiary_router/moodiary_router.dart';
import 'package:mui/mui.dart';
import 'package:share_plus/share_plus.dart';

class EditorMigrationPage extends StatefulWidget {
  const EditorMigrationPage({super.key});

  @override
  State<EditorMigrationPage> createState() => _EditorMigrationPageState();
}

enum _Phase { landing, running, failed, done }

enum _Stage { engine, editor, content }

class _EditorMigrationPageState extends State<EditorMigrationPage> {
  _Phase _phase = .landing;

  late final List<_Stage> _stages = [
    if (EngineMigrationService.requiresMigration) .engine,
    if (EngineMigrationService.requiresMigration ||
        EditorMigrationService.hasLegacyDiaries)
      .editor,
    if (EditorMigrationService.requiresContentUpgrade) .content,
  ];

  _Stage? _activeStage;
  final Set<_Stage> _completed = {};
  _Stage? _failedStage;
  int _done = 0;
  int _total = 0;

  int _editorFailed = 0;
  String? _logPath;

  int _summaryDiaries = 0;
  int _summaryCategories = 0;

  bool get _onlyContent =>
      !_stages.contains(_Stage.engine) && !_stages.contains(_Stage.editor);

  void _onProgress(int done, int total) {
    if (!mounted) return;
    setState(() {
      _done = done;
      _total = total;
    });
  }

  void _enter(_Stage stage, {int total = 0}) {
    if (!mounted) return;
    setState(() {
      _activeStage = stage;
      _done = 0;
      _total = total;
    });
  }

  void _complete(_Stage stage) {
    if (!mounted) return;
    setState(() {
      _completed.add(stage);
      _activeStage = null;
      _done = 0;
      _total = 0;
    });
  }

  Future<void> _run() async {
    setState(() {
      _phase = .running;
      _activeStage = null;
      _completed.clear();
      _failedStage = null;
      _done = 0;
      _total = 0;
      _editorFailed = 0;
      _logPath = null;
    });
    try {
      if (EngineMigrationService.requiresMigration) {
        _enter(.engine);
        await EngineMigrationService.migrate(onProgress: _onProgress);
        await EngineMigrationService.finalizeMigration();
        await EditorMigrationService.refreshRequiresMigration();
      }
      _complete(.engine);

      final pending = await EditorMigrationService.pendingDiaries();
      if (!mounted) return;
      if (pending.isNotEmpty) _enter(.editor, total: pending.length);
      final report = await EditorMigrationService.migrateAll(
        pending,
        onProgress: _onProgress,
      );
      if (!mounted) return;
      if (report.failed > 0) {
        final logPath = await _writeFailureLog(
          stage: _Stage.editor.name,
          failures: report.failures,
        );
        if (!mounted) return;
        setState(() {
          _phase = .failed;
          _failedStage = .editor;
          _editorFailed = report.failed;
          _logPath = logPath;
        });
        return;
      }
      _complete(.editor);

      if (EditorMigrationService.requiresContentUpgrade) {
        _enter(.content);
        await EditorMigrationService.upgradeContent(onProgress: _onProgress);
      }
      _complete(.content);
    } catch (e, s) {
      final redacted = EditorMigrationService.redactDbError(e);
      logger.e('forced migration failed', error: redacted, stackTrace: s);
      final failed = _activeStage ?? _Stage.editor;
      String? logPath;
      try {
        logPath = await _writeFailureLog(
          stage: failed.name,
          error: redacted,
          stackTrace: s,
        );
      } catch (e, s) {
        logger.e('write migration failure log failed', error: e, stackTrace: s);
      }
      if (!mounted) return;
      setState(() {
        _phase = .failed;
        _failedStage = failed;
        _logPath = logPath;
      });
      return;
    }
    EditorMigrationService.requiresMigration = false;
    var diaries = 0;
    var categories = 0;
    try {
      diaries = await getIt<DiaryRepository>().countAllDiaries();
      categories =
          (await getIt<CategoryRepository>().getAllCategories()).length;
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

  static IconData _stageIcon(_Stage stage) => switch (stage) {
    .engine => LucideIcons.database,
    .editor => LucideIcons.fileText,
    .content => LucideIcons.fileCog,
  };

  String _stageTitle(BuildContext context, _Stage stage) => switch (stage) {
    .engine => context.l10n.editor.migrationStepEngine,
    .editor => context.l10n.editor.migrationStepEditor,
    .content => context.l10n.editor.migrationStepContent,
  };

  String _stageDescription(BuildContext context, _Stage stage) =>
      switch (stage) {
        .engine => context.l10n.editor.migrationStepEngineDesc,
        .editor => context.l10n.editor.migrationStepEditorDesc,
        .content => context.l10n.editor.migrationStepContentDesc,
      };

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
          subtitle: _onlyContent
              ? l10n.editor.migrationContentIntro
              : l10n.editor.migrationIntro,
        ),
        const SizedBox(height: 32),
        _Card(
          children: [
            for (final stage in _stages)
              _StepRow(
                icon: _stageIcon(stage),
                title: _stageTitle(context, stage),
                subtitle: _stageDescription(context, stage),
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
            for (final stage in _stages)
              if (_completed.contains(stage))
                _StepRow(
                  icon: LucideIcons.circleCheck,
                  title: _stageTitle(context, stage),
                  trailing: l10n.editor.migrationStageDone,
                )
              else if (stage == _activeStage)
                _StepRow(
                  icon: _stageIcon(stage),
                  title: _stageTitle(context, stage),
                  trailing: '$_done / $_total',
                  progress: _total == 0 ? null : _done / _total,
                  showProgress: true,
                )
              else
                _StepRow(
                  icon: _stageIcon(stage),
                  title: _stageTitle(context, stage),
                  trailing: l10n.editor.migrationStagePending,
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
            for (final stage in _stages)
              if (stage == _failedStage)
                _StepRow(
                  icon: LucideIcons.circleAlert,
                  iconColor: theme.colors.error,
                  title: _stageTitle(context, stage),
                  trailing: stage == .editor && _editorFailed > 0
                      ? l10n.editor.migrationStageFailedCount(
                          count: _editorFailed,
                        )
                      : l10n.editor.migrationStageFailed,
                  trailingError: true,
                )
              else if (_completed.contains(stage))
                _StepRow(
                  icon: LucideIcons.circleCheck,
                  title: _stageTitle(context, stage),
                  trailing: l10n.editor.migrationStageDone,
                )
              else
                _StepRow(
                  icon: _stageIcon(stage),
                  title: _stageTitle(context, stage),
                  trailing: l10n.editor.migrationStagePending,
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
          subtitle: _stages.contains(_Stage.engine)
              ? l10n.editor.migrationDoneSubtitle
              : l10n.editor.migrationContentDoneSubtitle,
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
            if (_stages.contains(_Stage.engine))
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
