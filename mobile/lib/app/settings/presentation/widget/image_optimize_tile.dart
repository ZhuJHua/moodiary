import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_media/moodiary_media.dart';

class ImageOptimizeTile extends ConsumerStatefulWidget {
  final bool isFirst;
  final bool isLast;

  const ImageOptimizeTile({
    super.key,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  ConsumerState<ImageOptimizeTile> createState() => _ImageOptimizeTileState();
}

class _ImageOptimizeTileState extends ConsumerState<ImageOptimizeTile> {
  bool _running = false;
  BuildContext? _progressCtx;

  @override
  Widget build(BuildContext context) {
    return SettingListTile(
      isFirst: widget.isFirst,
      isLast: widget.isLast,
      leading: const Icon(LucideIcons.images),
      title: context.l10n.app.imageOptimizeTitle,
      subtitle: context.l10n.app.imageOptimizeSubtitle,
      trailing: _running
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(LucideIcons.chevronRight),
      onTap: _running ? null : _confirmAndRun,
    );
  }

  Future<void> _confirmAndRun() async {
    final confirmed = await MAlert.confirm(
      context,
      title: l10n.app.imageOptimizeTitle,
      message: l10n.app.imageOptimizeMessage,
      confirmLabel: l10n.app.imageOptimizeStart,
    );
    if (!confirmed || !mounted) return;
    await _run();
  }

  Future<void> _run() async {
    setState(() => _running = true);
    final progress = StreamController<(int, int)>();
    _showProgress(progress.stream);
    try {
      final report = await ImageOptimizer.run(
        repo: ref.read(diaryRepositoryProvider),
        decoder: ref.read(heifDecoderProvider),
        onProgress: (done, total) => progress.add((done, total)),
      );
      _dismissProgress();
      if (!mounted) return;
      await _showResult(report);
    } catch (e, s) {
      _dismissProgress();
      logger.e('图片优化失败', error: e, stackTrace: s);
      if (mounted) toast.error(message: l10n.app.imageOptimizeFailed);
    } finally {
      unawaited(progress.close());
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _showResult(ImageOptimizeReport report) async {
    final lines = <String>[
      l10n.app.imageOptimizeScanned(count: report.images),
      if (report.heicConverted > 0)
        l10n.app.imageOptimizeConverted(count: report.heicConverted),
      if (report.heicFailed > 0)
        l10n.app.imageOptimizeConvertFailed(count: report.heicFailed),
      l10n.app.imageOptimizeThumbs,
    ];
    await MAlert.notice(
      context,
      title: l10n.app.imageOptimizeDoneTitle,
      message: lines.join('\n'),
      closeLabel: l10n.app.imageOptimizeOk,
    );
  }

  void _showProgress(Stream<(int, int)> progress) {
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          _progressCtx = ctx;
          return AlertDialog(
            title: Text(l10n.app.imageOptimizeRunning),
            content: StreamBuilder<(int, int)>(
              stream: progress,
              initialData: (0, 0),
              builder: (_, snapshot) {
                final (done, total) = snapshot.requireData;
                return Column(
                  mainAxisSize: .min,
                  children: [
                    LinearProgressIndicator(
                      value: total == 0 ? null : done / total,
                    ),
                    if (total > 0) ...[
                      const SizedBox(height: 12),
                      Text('$done / $total'),
                    ],
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _dismissProgress() {
    final ctx = _progressCtx;
    if (ctx != null && ctx.mounted) Navigator.of(ctx).pop();
    _progressCtx = null;
  }
}
