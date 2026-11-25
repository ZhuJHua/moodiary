import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart' show SystemNavigator;
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_logging/moodiary_logging.dart' show logger;
import 'package:moodiary_router/moodiary_router.dart';
import 'package:mui/mui.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'editor_migration_service.dart';
import 'legacy_data_exporter.dart';
import 'legacy_database_guard.dart';
import 'startup_migration_coordinator.dart';

class EditorMigrationPage extends StatefulWidget {
  const EditorMigrationPage({
    required this.resumeStartup,
    this.coordinator,
    super.key,
  });

  final Future<void> Function() resumeStartup;
  final StartupMigrationCoordinator? coordinator;

  @override
  State<EditorMigrationPage> createState() => _EditorMigrationPageState();
}

enum _Phase { landing, running, failed, done }

enum _Stage { editor, content }

class _EditorMigrationPageState extends State<EditorMigrationPage> {
  _Phase _phase = .landing;

  late final List<_Stage> _stages = [
    if (EditorMigrationService.hasLegacyDiaries) .editor,
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

  late final _coordinator = widget.coordinator ?? StartupMigrationCoordinator();
  late bool _legacyGate = !_coordinator.canStartData;
  bool _homePending = false;

  Future<void> _resumeStartup() async {
    await _coordinator.startData(widget.resumeStartup);
    if (!mounted) return;
    if (!_coordinator.canEnterHome) {
      setState(() => _legacyGate = false);
    } else {
      setState(() => _homePending = true);
    }
  }

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
    final contentOnly = !_stages.contains(_Stage.editor);
    _coordinator.completeEditorMigration();
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
      _homePending = contentOnly && _coordinator.canEnterHome;
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
    if (_homePending && ModalRoute.isCurrentOf(context) == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            !_homePending ||
            ModalRoute.of(context)?.isCurrent != true) {
          return;
        }
        _homePending = false;
        const DiaryHomeRoute().go(context);
      });
    }
    if (_legacyGate || !_coordinator.canStartData) {
      return _LegacyDataGate(resumeStartup: _resumeStartup);
    }
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
    .editor => LucideIcons.fileText,
    .content => LucideIcons.fileCog,
  };

  String _stageTitle(BuildContext context, _Stage stage) => switch (stage) {
    .editor => context.l10n.editor.migrationStepEditor,
    .content => context.l10n.editor.migrationStepContent,
  };

  String _stageDescription(BuildContext context, _Stage stage) =>
      switch (stage) {
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
          subtitle: l10n.editor.migrationContentIntro,
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
          subtitle: l10n.editor.migrationContentDoneSubtitle,
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

enum _LegacyPhase {
  landing,
  exporting,
  generated,
  saved,
  exportFailed,
  probeFailed,
}

class _LegacyDataGate extends StatefulWidget {
  const _LegacyDataGate({required this.resumeStartup});

  final Future<void> Function() resumeStartup;

  @override
  State<_LegacyDataGate> createState() => _LegacyDataGateState();
}

class _LegacyDataGateState extends State<_LegacyDataGate> {
  _LegacyPhase _phase = .landing;
  LegacyExportSummary? _summary;
  String? _archive;
  int _archiveBytes = 0;
  int _completed = 0;
  int _total = 0;
  bool _busy = false;
  bool _cancelRequested = false;
  bool _shared = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    if (LegacyDatabaseGuard.state == LegacyDatabaseState.pending) {
      unawaited(_inspect());
    } else {
      _phase = .probeFailed;
    }
  }

  Future<void> _inspect() async {
    setState(() => _busy = true);
    try {
      final summary = await getIt<LegacyDataExporter>().inspect();
      if (mounted) {
        setState(() {
          _summary = summary;
          _phase = .landing;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _phase = .exportFailed;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _retryGuard() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await LegacyDatabaseGuard.probe();
      if (LegacyDatabaseGuard.state == LegacyDatabaseState.abandoning) {
        await LegacyDatabaseGuard.abandon();
      }
      if (!mounted) return;
      switch (LegacyDatabaseGuard.state) {
        case LegacyDatabaseState.none:
          await widget.resumeStartup();
        case LegacyDatabaseState.pending:
          await _inspect();
        case LegacyDatabaseState.probeFailed || LegacyDatabaseState.abandoning:
          setState(() => _phase = .probeFailed);
      }
    } catch (_) {
      if (mounted) setState(() => _phase = .probeFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() async {
    if (_busy) return;
    setState(() {
      _phase = .exporting;
      _busy = true;
      _cancelRequested = false;
      _completed = 0;
      _total = (_summary?.mediaCount ?? 0) + 1;
    });
    try {
      final archive = await getIt<LegacyDataExporter>().export(
        onProgress: (completed, total) {
          if (mounted) {
            setState(() {
              _completed = completed;
              _total = total;
            });
          }
        },
        isCancelled: () => !mounted || _cancelRequested,
      );
      final size = await File(archive).length();
      if (mounted) {
        setState(() {
          _archive = archive;
          _archiveBytes = size;
          _shared = false;
          _phase = .generated;
        });
      }
    } on LegacyExportCancelled {
      if (mounted) setState(() => _phase = .landing);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _phase = .exportFailed;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await SharePlus.instance.share(
        ShareParams(files: [XFile(_archive!, mimeType: 'application/zip')]),
      );
      if (mounted && result.status != ShareResultStatus.dismissed) {
        setState(() => _shared = true);
      }
    } catch (_) {
      if (mounted) {
        toast.error(message: context.l10n.editor.legacyShareFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _abandon() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final saved = _phase == _LegacyPhase.saved;
      final confirmed = await MAlert.confirm(
        context,
        title: context.l10n.editor.legacyAbandonConfirm,
        message: saved
            ? context.l10n.editor.legacyAbandonSaved
            : context.l10n.editor.legacyAbandonWarning,
        confirmLabel: context.l10n.editor.legacyAbandonConfirm,
        isDestructive: true,
        acknowledgeLabel: saved ? null : context.l10n.editor.legacyUnderstand,
      );
      if (!confirmed || !mounted) return;
      await LegacyDatabaseGuard.abandon();
      if (!mounted) return;
      if (LegacyDatabaseGuard.state == LegacyDatabaseState.none) {
        await widget.resumeStartup();
      } else {
        setState(() => _phase = .probeFailed);
      }
    } catch (_) {
      if (mounted) setState(() => _phase = .probeFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openReleases() async {
    try {
      if (await launchUrl(
        Uri.parse('https://github.com/ZhuJHua/moodiary/releases'),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (error, stackTrace) {
      logger.e(
        'Opening release downloads failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (mounted) {
      toast.error(message: context.l10n.editor.legacyOpenFailed);
    }
  }

  String _bytes(int bytes) {
    final units = AppFiles.bytesToUnits(bytes);
    return '${units['size']} ${units['unit']}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final version = LegacyDatabaseGuard.sourceVersion;
    final archiveName = _archive == null ? '' : p.basename(_archive!);
    final error = context.theme.colors.error;
    final abandon = OutlinedButton(
      onPressed: _busy ? null : _abandon,
      style: OutlinedButton.styleFrom(
        foregroundColor: error,
        side: BorderSide(color: error),
      ),
      child: Text(l10n.editor.legacyAbandon),
    );
    final exit = TextButton(
      onPressed: _busy ? null : SystemNavigator.pop,
      child: Text(l10n.editor.migrationExit),
    );
    final children = switch (_phase) {
      _LegacyPhase.landing => <Widget>[
        _Header(
          icon: LucideIcons.circleAlert,
          color: context.theme.colors.error,
          title: l10n.editor.legacyTitle,
          subtitle: version == null
              ? l10n.editor.legacyIntroUnknown
              : l10n.editor.legacyIntro(version: version),
        ),
        if (_summary case final summary?)
          _Card(
            children: [
              _SummaryRow(
                label: l10n.editor.legacyDatabaseSize,
                value: _bytes(summary.databaseBytes),
              ),
              _SummaryRow(
                label: l10n.editor.legacyMedia,
                value: l10n.editor.legacyMediaSummary(
                  count: summary.mediaCount,
                  size: _bytes(summary.mediaBytes),
                ),
              ),
            ],
          )
        else
          const LinearProgressIndicator(),
        FilledButton(
          onPressed: _busy ? null : _export,
          child: Text(l10n.editor.legacyExport),
        ),
        abandon,
        exit,
      ],
      _LegacyPhase.exporting => <Widget>[
        _Header(
          icon: LucideIcons.database,
          color: context.theme.colors.primary,
          title: l10n.editor.legacyExporting,
          subtitle: l10n.editor.legacyProgress(done: _completed, total: _total),
        ),
        LinearProgressIndicator(
          value: _total == 0 ? null : _completed / _total,
        ),
        _Footnote(text: l10n.editor.legacyKeepOpen),
        TextButton(
          onPressed: _cancelRequested
              ? null
              : () => setState(() => _cancelRequested = true),
          child: Text(l10n.common.cancel),
        ),
      ],
      _LegacyPhase.generated => <Widget>[
        _Header(
          icon: LucideIcons.fileText,
          color: context.theme.colors.primary,
          title: l10n.editor.legacyGenerated,
          subtitle: l10n.editor.legacyGeneratedNote,
        ),
        _Card(
          children: [
            _StepRow(
              icon: LucideIcons.fileText,
              title: archiveName,
              subtitle: _bytes(_archiveBytes),
            ),
          ],
        ),
        // 分享回来后，"我已保存"成为主操作，分享降为次要（可再次分享）。
        if (_shared) ...[
          FilledButton(
            onPressed: _busy ? null : () => setState(() => _phase = .saved),
            child: Text(l10n.editor.legacyShareConfirmed),
          ),
          OutlinedButton(
            onPressed: _busy ? null : _share,
            child: Text(l10n.editor.legacyShare),
          ),
        ] else
          FilledButton(
            onPressed: _busy ? null : _share,
            child: Text(l10n.editor.legacyShare),
          ),
        abandon,
      ],
      _LegacyPhase.saved => <Widget>[
        _Header(
          icon: LucideIcons.circleCheck,
          color: context.theme.colors.primary,
          title: l10n.editor.legacySaved,
          subtitle: l10n.editor.legacySharedVerified(name: archiveName),
        ),
        _Card(
          children: [
            for (final step in [
              l10n.editor.legacyRecoverOne,
              l10n.editor.legacyRecoverTwo,
              l10n.editor.legacyRecoverThree,
              l10n.editor.legacyRecoverFour,
            ])
              _StepRow(icon: LucideIcons.fileText, title: step),
          ],
        ),
        OutlinedButton(
          onPressed: _openReleases,
          child: Text(l10n.editor.legacyOpenReleases),
        ),
        FilledButton(
          onPressed: _busy ? null : SystemNavigator.pop,
          child: Text(l10n.editor.legacyFinishExit),
        ),
        abandon,
      ],
      _LegacyPhase.exportFailed => <Widget>[
        _Header(
          icon: LucideIcons.circleAlert,
          color: context.theme.colors.error,
          title: l10n.editor.legacyExportFailed,
          subtitle: switch (_error) {
            LegacyExportInsufficientSpace() => l10n.editor.legacySpaceError,
            LegacyExportFileTooLarge(:final path) =>
              l10n.editor.legacyLargeFile(name: p.basename(path)),
            _ => l10n.editor.legacyExportError,
          },
        ),
        FilledButton(
          onPressed: _busy ? null : _export,
          child: Text(l10n.editor.migrationRetry),
        ),
        abandon,
        exit,
      ],
      _LegacyPhase.probeFailed => <Widget>[
        _Header(
          icon: LucideIcons.circleAlert,
          color: context.theme.colors.error,
          title: l10n.editor.legacyProbeFailed,
          subtitle: l10n.editor.legacyProbeNote,
        ),
        FilledButton(
          onPressed: _busy ? null : _retryGuard,
          child: Text(l10n.editor.migrationRetry),
        ),
        exit,
      ],
    };
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            itemCount: children.length,
            itemBuilder: (context, index) => children[index],
            separatorBuilder: (_, _) => const SizedBox(height: 12),
          ),
        ),
      ),
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
