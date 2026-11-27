import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mime/mime.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_router/moodiary_router.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:share_plus/share_plus.dart' show ShareParams, SharePlus;

import 'attachment_details.dart';
import 'media_controller.dart';

bool _sharing = false;

class MediaDetailPage extends ConsumerStatefulWidget {
  final MediaType? type;
  final String name;
  final String? diaryId;
  final String? label;
  final DateTime? date;

  const MediaDetailPage._({
    super.key,
    required this.type,
    required this.name,
    this.diaryId,
    required this.label,
    required this.date,
  });

  factory MediaDetailPage.fromRoute(GoRouterState state) {
    final params = state.params;
    final name = params['name'];
    final date = params['date'];
    final label = params['label'];
    final diaryId = params['diary_id'];
    final valid =
        name is String &&
        AttachmentLauncher.isValidName(name) &&
        (label == null || label is String) &&
        (diaryId == null || diaryId is String) &&
        date is int &&
        date >= -8640000000000000 &&
        date <= 8640000000000000;
    if (valid) {
      final day = DateTime.fromMillisecondsSinceEpoch(date);
      final title = label as String?;
      switch (params['type']) {
        case 'audio':
          return AudioDetailPage(
            name: name,
            diaryId: diaryId as String?,
            label: title,
            date: day,
          );
        case 'file':
          return FileDetailPage(
            name: name,
            diaryId: diaryId as String?,
            label: title,
            date: day,
          );
      }
    }
    return MediaDetailPage._(
      name: name is String ? name : '',
      type: null,
      label: null,
      date: null,
    );
  }

  @override
  ConsumerState<MediaDetailPage> createState() => _MediaDetailPageState();
}

class AudioDetailPage extends MediaDetailPage {
  const AudioDetailPage({
    super.diaryId,
    super.key,
    required super.name,
    super.label,
    required DateTime super.date,
  }) : super._(type: .audio);
}

class FileDetailPage extends MediaDetailPage {
  const FileDetailPage({
    super.diaryId,
    super.key,
    required super.name,
    super.label,
    required DateTime super.date,
  }) : super._(type: .file);
}

class _MediaDetailPageState extends ConsumerState<MediaDetailPage> {
  late String? _lastLabel = widget.label;
  String? _lastMime;
  static bool _opening = false;

  bool get _audio => widget.type == .audio;

  Future<File?> _localFile() async {
    final name = widget.name;
    final file = File(AppFiles.getRealPath(widget.type!.value, name));
    final missing = await _isMissing(file);
    if (!mounted) return null;
    ref.invalidate(attachmentSizeProvider(name, audio: _audio));
    if (_audio) ref.invalidate(audioDurationProvider(name));
    if (missing) {
      toast.info(message: l10n.media.waitingSync);
      return null;
    }
    return file;
  }

  Future<String?> _mimeOf(File source) async =>
      _lastMime ??
      (_audio
          ? lookupMimeType(source.path)
          : await AttachmentLauncher.mimeOf(widget.name));

  Future<void> _open(String displayName) async {
    if (_opening) return;
    _opening = true;
    File? copy;
    var opened = false;
    try {
      final file = await _localFile();
      if (file == null || !mounted) return;
      final mime = await _mimeOf(file);
      copy = await stageAttachmentCopy(
        Directory(AppFiles.getCachePath('')),
        file,
        displayName,
        prefix: 'open-',
      );
      if (!mounted) return;
      opened = await AttachmentLauncher.openPath(copy.path, mime: mime);
      if (!opened && mounted) {
        toast.error(message: l10n.common.openFailed);
      }
    } on FileSystemException {
      if (mounted) toast.error(message: l10n.common.openFailed);
    } finally {
      if (!opened && copy != null) {
        await AppFiles.deleteDir(copy.parent.path)
            .onError<FileSystemException>((_, _) {});
      }
      _opening = false;
    }
  }

  Future<void> _shareFrom(BuildContext anchor, String displayName) async {
    final file = await _localFile();
    if (file == null || !mounted) return;
    final mime = await _mimeOf(file);
    if (anchor.mounted) await _share(anchor, file, displayName, mime);
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.type;
    if (type == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(widget.name)),
      );
    }
    final items = ref.watch(mediaItemsProvider(type: type)).value?.items;
    final item = items
        ?.where(
          (entry) =>
              entry.fileName == widget.name &&
              (widget.diaryId == null || entry.diaryId == widget.diaryId),
        )
        .firstOrNull;
    if (item != null) {
      _lastLabel = item.name;
      _lastMime = item.mime;
    }
    final label = _lastLabel?.trim() ?? '';
    final title = label.isEmpty
        ? (_audio ? context.l10n.common.audio : context.l10n.media.typeFile)
        : label;
    final duration = _audio
        ? ref.watch(audioDurationProvider(widget.name)).value
        : null;
    final extension = _audio ? '' : attachmentExtension(title, widget.name);
    final bytes = ref
        .watch(attachmentSizeProvider(widget.name, audio: _audio))
        .value;
    final meta = attachmentDetailMeta(
      extension: extension,
      duration: duration == null ? null : TimeFormat.mediaDuration(duration),
      bytes: bytes,
      waitingSync: context.l10n.media.waitingSync,
      date: TimeFormat.longDate(widget.date!),
    );
    final colors = context.theme.colors;
    return _DetailScaffold(
      share: (anchor) => _shareFrom(anchor, title),
      icon: _audio
          ? Icon(LucideIcons.music, size: 48, color: colors.onSurfaceVariant)
          : FileTypeIcon(extension, size: 64, color: colors.onSurfaceVariant),
      title: title,
      rename: () => _rename(context, ref, type, widget.name, label),
      meta: meta,
      action: _audio
          ? _AudioAction(
              key: ValueKey(widget.name),
              duration: duration,
              localFile: _localFile,
            )
          : SizedBox(
              width: 220,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                onPressed: () => _open(title),
                icon: const Icon(LucideIcons.externalLink),
                label: Text(context.l10n.media.openWith, textAlign: .center),
              ),
            ),
    );
  }
}

class _DetailScaffold extends StatelessWidget {
  final ValueChanged<BuildContext> share;
  final Widget icon;
  final String title;
  final VoidCallback rename;
  final String meta;
  final Widget action;

  const _DetailScaffold({
    required this.share,
    required this.icon,
    required this.title,
    required this.rename,
    required this.meta,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final content = Column(
      children: [
        const Spacer(flex: 2),
        Container(
          width: 120,
          height: 120,
          alignment: .center,
          decoration: BoxDecoration(
            color: colors.surfaceContainer,
            border: Border.all(color: colors.outlineVariant),
            borderRadius: AppBorderRadius.xLargeBorderRadius,
          ),
          child: icon,
        ),
        const SizedBox(height: 16),
        Semantics(
          button: true,
          label: '${context.l10n.media.rename} $title',
          excludeSemantics: true,
          onTap: rename,
          child: MInkWell(
            borderRadius: AppBorderRadius.mediumBorderRadius,
            onTap: rename,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisSize: .min,
                children: [
                  const SizedBox(width: 24),
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: .ellipsis,
                      textAlign: .center,
                      style: context
                          .theme
                          .typography
                          .titleLarge
                          .emphasized
                          .onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    LucideIcons.pencilLine,
                    size: 16,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
        Text(
          meta,
          textAlign: .center,
          style: context.theme.typography.bodyMedium.onSurfaceVariant.tabular,
        ),
        const SizedBox(height: 32),
        const Spacer(flex: 3),
        action,
        const Spacer(),
      ],
    );
    return Scaffold(
      appBar: AppBar(
        actions: [
          Builder(
            builder: (anchor) => IconButton(
              icon: const Icon(LucideIcons.share2),
              tooltip: context.l10n.share.share,
              onPressed: () => share(anchor),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (_, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: constraints.maxWidth,
                minHeight: constraints.maxHeight,
              ),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AudioAction extends StatefulWidget {
  final Duration? duration;
  final Future<File?> Function() localFile;
  const _AudioAction({
    super.key,
    required this.duration,
    required this.localFile,
  });

  @override
  State<_AudioAction> createState() => _AudioActionState();
}

class _AudioActionState extends State<_AudioAction>
    with WidgetsBindingObserver {
  AudioPlaybackController? _controller;
  Future<AudioPlaybackController?>? _loading;
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _gen++;
      unawaited(_controller?.pause());
    }
  }

  Future<AudioPlaybackController?> _ensureController() {
    if (_controller != null) return Future.value(_controller);
    return _loading ??= () async {
      try {
        final file = await widget.localFile();
        if (!mounted || file == null) return null;
        final controller = AudioPlaybackController(file.path);
        try {
          await controller.prepare();
        } catch (_) {
          controller.dispose();
          rethrow;
        }
        if (!mounted) {
          controller.dispose();
          return null;
        }
        return _controller = controller..progress.addListener(_update);
      } finally {
        _loading = null;
      }
    }();
  }

  Future<void> _onAction([double? fraction]) async {
    final current = _controller;
    if (fraction == null && current != null && current.progress.value.playing) {
      _gen++;
      await current.pause();
      return;
    }
    final gen = _gen;
    try {
      final controller = await _ensureController();
      if (!mounted || controller == null) return;
      if (fraction == null) {
        if (gen != _gen) return;
        await controller.toggle();
      } else {
        // Don't block subsequent Play/Pause on Android seeks that land in STATE_ENDED.
        unawaited(controller.seek(fraction, fallbackTotal: widget.duration));
      }
    } catch (_) {
      if (mounted) toast.error(message: l10n.common.openFailed);
    }
  }

  void _enqueue([double? fraction]) => unawaited(_onAction(fraction));

  void _update() => setState(() {});

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _controller?.progress.value ?? AudioProgress.zero;
    final total = progress.duration > Duration.zero
        ? progress.duration
        : widget.duration ?? Duration.zero;
    final fraction = total.inMilliseconds <= 0
        ? 0.0
        : (progress.position.inMilliseconds / total.inMilliseconds).clamp(
            0.0,
            1.0,
          );
    final style = context.theme.typography.labelMedium.onSurfaceVariant.tabular;
    return Column(
      mainAxisSize: .min,
      children: [
        Row(
          children: [
            Text(TimeFormat.mediaDuration(progress.position), style: style),
            const SizedBox(width: 12),
            Expanded(
              child: MAudioScrubBar(fraction: fraction, onSeek: _enqueue),
            ),
            const SizedBox(width: 12),
            Text(TimeFormat.mediaDuration(total), style: style),
          ],
        ),
        const SizedBox(height: 8),
        IconButton.filled(
          style: IconButton.styleFrom(
            fixedSize: const Size.square(64),
            shape: const CircleBorder(),
          ),
          tooltip: progress.playing
              ? context.l10n.ui.pause
              : context.l10n.ui.play,
          icon: Icon(
            progress.playing ? LucideIcons.pause : LucideIcons.play,
            color: context.theme.colors.onPrimary,
          ),
          onPressed: () => _enqueue(),
        ),
      ],
    );
  }
}

Future<bool> _isMissing(File file) async {
  try {
    await file.length();
    return false;
  } on PathNotFoundException {
    return true;
  } on FileSystemException {
    return false;
  }
}

Future<void> _rename(
  BuildContext context,
  WidgetRef ref,
  MediaType type,
  String name,
  String initialValue,
) async {
  final input = await MAlert.prompt(
    context,
    title: context.l10n.media.rename,
    initialValue: initialValue,
    hintText: context.l10n.common.name,
  );
  if (input == null || input.trim() == initialValue || !context.mounted) return;
  await ref
      .read(mediaItemsProvider(type: type).notifier)
      .rename(name, input.trim());
}

/// Shares a copy named after the diary label, so the receiver does not see
/// the stored uuid name. Only the latest copy is kept in the cache.
Future<void> _share(
  BuildContext context,
  File source,
  String displayName,
  String? mime,
) async {
  if (_sharing) return;
  final box = context.findRenderObject() as RenderBox?;
  final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  _sharing = true;
  File? copy;
  try {
    copy = await stageAttachmentCopy(
      Directory(AppFiles.getCachePath('')),
      source,
      displayName,
      prefix: 'share-',
    );
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(copy.path, mimeType: mime)],
        sharePositionOrigin: origin,
      ),
    );
  } catch (_) {
    if (copy != null) {
      await AppFiles.deleteDir(copy.parent.path)
          .onError<FileSystemException>((_, _) => false);
    }
    if (context.mounted) toast.error(message: context.l10n.media.shareFailed);
  } finally {
    _sharing = false;
  }
}
