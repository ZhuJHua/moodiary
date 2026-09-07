import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_editor/moodiary_editor.dart';
import 'package:moodiary_editor/src/data/markdown_media.dart';
import 'package:moodiary_files/moodiary_files.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_theme/moodiary_theme.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:path/path.dart' as p;

class MoodiaryEditorView extends StatefulWidget {
  final String initialContent;
  final ValueChanged<String> onChanged;

  final String initialTitle;
  final ValueChanged<String>? onTitleChanged;

  final MoodiaryEditorController? controller;

  final ValueChanged<int>? onActiveHeadingChanged;

  final bool editable;

  final bool firstLineIndent;

  final double fontScale;

  final String saveStatus;

  final ValueChanged<String>? onOpenDiaryLink;

  final String? metaJson;
  final String? linksJson;
  final VoidCallback? onPickDate;
  final VoidCallback? onPickTime;
  final VoidCallback? onPickCategory;
  final VoidCallback? onAddTag;
  final ValueChanged<int>? onRemoveTag;
  final ValueChanged<String>? onChangeMood;
  final ValueChanged<String>? onChangeWeather;
  final VoidCallback? onClearWeather;
  final VoidCallback? onFetchWeather;
  final VoidCallback? onFetchPosition;
  final VoidCallback? onLocateForPlaces;
  final ValueChanged<String>? onPickPlace;
  final VoidCallback? onNewPlace;
  final VoidCallback? onManagePlaces;
  final VoidCallback? onClearPosition;
  final VoidCallback? onOpenGraph;

  const MoodiaryEditorView({
    super.key,
    required this.initialContent,
    required this.onChanged,
    this.initialTitle = '',
    this.onTitleChanged,
    this.controller,
    this.onActiveHeadingChanged,
    this.editable = true,
    this.firstLineIndent = false,
    this.fontScale = 1.0,
    this.saveStatus = 'idle',
    this.onOpenDiaryLink,
    this.metaJson,
    this.linksJson,
    this.onPickDate,
    this.onPickTime,
    this.onPickCategory,
    this.onAddTag,
    this.onRemoveTag,
    this.onChangeMood,
    this.onChangeWeather,
    this.onClearWeather,
    this.onFetchWeather,
    this.onFetchPosition,
    this.onLocateForPlaces,
    this.onPickPlace,
    this.onNewPlace,
    this.onManagePlaces,
    this.onClearPosition,
    this.onOpenGraph,
  });

  @override
  State<MoodiaryEditorView> createState() => _MoodiaryEditorViewState();
}

class _MoodiaryEditorViewState extends State<MoodiaryEditorView> {
  late final _controller = widget.controller ?? MoodiaryEditorController();

  Future<void> _pickImages() async {
    final files = await getIt<IFilePicker>().pickImages(context);
    if (files.isEmpty) return;
    await _insertPicked(files);
  }

  Future<void> _insertPicked(List<XFile> files) async {
    for (final file in files) {
      final name = await MediaManager.saveImage(file);
      if (name == null) continue;
      await _controller.insertMedia(name);
    }
  }

  Future<String?> _saveDataUriImage(String dataUri, String fallbackName) async {
    final xfile = await _dataUriToTempFile(dataUri, fallbackName);
    if (xfile == null) return null;
    final saved = await MediaManager.saveImages(imageFileList: [xfile]);
    return saved[xfile.path];
  }

  Future<XFile?> _dataUriToTempFile(String dataUri, String fallbackName) async {
    final comma = dataUri.indexOf(',');
    if (comma < 0) return null;
    final mime = RegExp(r'data:([^;]+)').firstMatch(dataUri)?.group(1);
    final bytes = base64Decode(dataUri.substring(comma + 1));
    final ext = switch (mime) {
      'image/jpeg' => '.jpg',
      'image/png' => '.png',
      'image/webp' => '.webp',
      'image/gif' => '.gif',
      'image/heic' => '.heic',
      _ =>
        p.extension(fallbackName).isNotEmpty
            ? p.extension(fallbackName)
            : '.png',
    };
    final tmpName = 'upload-${uuidV7()}$ext';
    final tmpPath = AppFiles.getCachePath(tmpName);
    await File(tmpPath).writeAsBytes(bytes);
    return XFile(tmpPath);
  }

  Future<void> _pickVideo() async {
    final file = await getIt<IFilePicker>().pickVideo(context);
    if (file == null) return;
    final saved = await MediaManager.saveVideo(videoFileList: [file]);
    final name = saved[file.path];
    if (name != null) await _controller.insertVideo(name);
  }

  void _showAudioDialog() {
    showDialog<void>(
      context: context,
      builder: (sheetContext) {
        return SimpleDialog(
          title: Text(context.l10n.editor.pickAudio),
          children: [
            SimpleDialogOption(
              onPressed: () => _pickAudioFile(sheetContext),
              child: _DialogRow(
                icon: LucideIcons.fileAudio,
                label: context.l10n.editor.pickAudioFromFile,
              ),
            ),
            SimpleDialogOption(
              onPressed: () => _recordAudio(sheetContext),
              child: _DialogRow(
                icon: LucideIcons.mic,
                label: context.l10n.editor.pickAudioFromRecord,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickAudioFile(BuildContext sheetContext) async {
    Navigator.of(sheetContext).pop();
    String? name;
    try {
      final file = await getIt<IFilePicker>().pickAudio();
      if (file == null) return;
      final ext = p.extension(file.path);
      name = 'audio-${uuidV7()}$ext';
      final path = AppFiles.getRealPath('audio', name);
      await File(file.path).copy(path);
      final duration = await probeAudioDuration(path);
      if (duration == null) {
        await AppFiles.deleteFile(path);
        if (mounted) toast.error(message: context.l10n.editor.audioFileError);
        return;
      }
      await _saveMediaInfo(
        name,
        title: p.basenameWithoutExtension(file.path),
        duration: duration,
      );
      await _controller.insertAudio(name);
    } catch (_) {
      if (name != null) {
        try {
          await AppFiles.deleteFile(AppFiles.getRealPath('audio', name));
        } catch (_) {}
      }
      if (mounted) toast.error(message: context.l10n.editor.audioFileError);
    }
  }

  Future<void> _recordAudio(BuildContext sheetContext) async {
    Navigator.of(sheetContext).pop();
    final result = await MSheet.show<RecordSaveResult>(
      context,
      builder: (_) => const RecordSheet(),
    );
    if (result == null) return;
    await _saveMediaInfo(
      result.fileName,
      title: result.name,
      duration: result.duration,
    );
    await _controller.insertAudio(result.fileName);
  }

  Future<void> _saveMediaInfo(
    String fileName, {
    String? title,
    Duration? duration,
  }) async {
    try {
      await getIt<MediaInfoRepository>().insertAMediaInfo(
        MediaInfo.create(
          fileName: fileName,
          name: title,
          durationMs: duration?.inMilliseconds,
        ),
      );
    } catch (e, s) {
      logger.e('save media info failed: $fileName', error: e, stackTrace: s);
    }
  }

  void _previewImages(List<String> images, int index) {
    final resolved = [
      for (final src in images)
        src.startsWith('http://') || src.startsWith('https://')
            ? src
            : AppFiles.getRealPath('image', src),
    ];
    MImageBrowser.show(context, images: resolved, initialIndex: index);
  }

  Future<Duration?> _openVideoFullscreen(String name, Duration position) async {
    Duration? exitAt;
    await MVideoPlayerPage.showByName(
      context,
      name: name,
      startAt: position,
      onExitAt: (d) => exitAt = d,
    );
    return exitAt;
  }

  Future<List<DiaryLinkCandidate>> _linkCandidates(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final diaries = await getIt<DiaryRepository>().searchDiariesByText(
      q,
      limit: 12,
    );
    return [for (final d in diaries) (id: d.id, label: _candidateLabel(d))];
  }

  String _candidateLabel(Diary d) {
    final title = d.title.trim();
    if (title.isNotEmpty) return title;
    final date = TimeFormat.isoDate(d.time);
    final snippet = d.contentText.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (snippet.isEmpty) return date;
    final clipped = snippet.length > 16
        ? '${snippet.substring(0, 16)}…'
        : snippet;
    return '$date · $clipped';
  }

  @override
  Widget build(BuildContext context) {
    return MoodiaryEditor(
      controller: _controller,
      readOnly: !widget.editable,
      placeholder: context.l10n.editor.content,
      titlePlaceholder: context.l10n.editor.titlePlaceholder,
      initialContent: widget.initialContent,
      initialTitle: widget.initialTitle,
      onChanged: widget.onChanged,
      onTitleChanged: widget.onTitleChanged,
      onActiveHeadingChanged: widget.onActiveHeadingChanged,
      onPickImage: _pickImages,
      onPickAudio: _showAudioDialog,
      onPickVideo: _pickVideo,
      onSaveImage: _saveDataUriImage,
      onImageTap: _previewImages,
      onVideoFullscreen: _openVideoFullscreen,
      onRequestLinkCandidates: _linkCandidates,
      onOpenDiaryLink: widget.onOpenDiaryLink,
      metaJson: widget.metaJson,
      linksJson: widget.linksJson,
      onPickDate: widget.onPickDate,
      onPickTime: widget.onPickTime,
      onPickCategory: widget.onPickCategory,
      onAddTag: widget.onAddTag,
      onRemoveTag: widget.onRemoveTag,
      onChangeMood: widget.onChangeMood,
      onChangeWeather: widget.onChangeWeather,
      onClearWeather: widget.onClearWeather,
      onFetchWeather: widget.onFetchWeather,
      onFetchPosition: widget.onFetchPosition,
      onLocateForPlaces: widget.onLocateForPlaces,
      onPickPlace: widget.onPickPlace,
      onNewPlace: widget.onNewPlace,
      onManagePlaces: widget.onManagePlaces,
      onClearPosition: widget.onClearPosition,
      onOpenGraph: widget.onOpenGraph,
      saveStatus: widget.saveStatus,
      firstLineIndent: widget.firstLineIndent,
      fontScale: widget.fontScale,
      rolesResolver: getIt<ThemeManager>().editorRoles,
      fontResolver: () => getIt<ThemeManager>().editorFont,
      mediaResolver: appMediaResolver,
      mediaNameResolver: (name) async =>
          (await getIt<MediaInfoRepository>().getMediaInfoByFileName(name))
              ?.name,
      audioDefaultName: context.l10n.common.audio,
      loadingBuilder: (_) => const MLoading(),
    );
  }
}

class _DialogRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _DialogRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [Icon(icon), const SizedBox(width: 12), Text(label)]);
  }
}
