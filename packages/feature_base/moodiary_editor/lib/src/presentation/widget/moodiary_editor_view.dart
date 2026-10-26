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
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../../toolbar/editor_toolbar_host.dart';
import '../../toolbar/insert_panel.dart';

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

  final ValueChanged<String>? onOpenDiaryLink;

  final String? metaJson;
  final bool metaReady;
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

  final Widget? statusBar;

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
    this.onOpenDiaryLink,
    this.metaJson,
    this.metaReady = true,
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
    this.statusBar,
  });

  @override
  State<MoodiaryEditorView> createState() => _MoodiaryEditorViewState();
}

class _MoodiaryEditorViewState extends State<MoodiaryEditorView> {
  late final _controller = widget.controller ?? MoodiaryEditorController();

  Future<void> _onInsertMedia(InsertItem item) async {
    try {
      await _controller.withInputSuspended(() => _insertMedia(item));
    } catch (e, s) {
      logger.e('insert ${item.name} failed', error: e, stackTrace: s);
      if (mounted) {
        toast.error(message: context.l10n.editor.toolbar.insertFailed);
      }
    }
  }

  Future<void> _insertMedia(InsertItem item) async {
    switch (item) {
      case .gallery:
        await _insertImages(await getIt<IFilePicker>().pickImages(context));
      case .camera:
        final photo = await getIt<IFilePicker>().takePhoto();
        if (photo != null) await _insertImages([photo]);
      case .video:
        await _pickVideo();
      case .record:
        await _recordAudio();
      case .audio:
        await _pickAudioFile();
      case .attachment:
        await _pickAttachment();
      default:
    }
  }

  Future<void> _insertImages(List<XFile> files) async {
    for (final file in files) {
      final name = await MediaManager.saveImage(file);
      if (name == null) continue;
      await _controller.exec(.insertImage, {'name': name});
    }
  }

  Future<void> _pickAttachment() async {
    final file = await getIt<IFilePicker>().pickFile();
    if (file == null) return;
    final saved = await MediaManager.saveAttachment(file);
    if (saved == null) {
      if (mounted) {
        toast.error(message: context.l10n.editor.toolbar.attachmentFailed);
      }
      return;
    }
    await _controller.exec(.insertAttachment, {
      'name': saved.name,
      'displayName': saved.fileName,
      'mime': saved.mime,
      'size': saved.size,
    });
  }

  Future<void> _openAttachment(String src, String name, String? mime) async {
    final result = await OpenFile.open(
      AppFiles.getRealPath('file', src),
      type: mime,
    );
    if (result.type != .done && mounted) {
      toast.error(message: context.l10n.editor.toolbar.openFailed);
    }
  }

  // 链接来自用户内容，javascript: / file: / intent: 一律不开
  static const _openableSchemes = {'http', 'https', 'mailto', 'tel', 'sms'};

  Future<void> _openUrl(String href) async {
    final uri = Uri.tryParse(href);
    final opened =
        uri != null &&
        _openableSchemes.contains(uri.scheme.toLowerCase()) &&
        await launchUrl(uri, mode: .externalApplication);
    if (!opened && mounted) {
      toast.error(message: context.l10n.editor.toolbar.openFailed);
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
    if (name != null) await _controller.exec(.insertVideo, {'name': name});
  }

  Future<void> _pickAudioFile() async {
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
      final title = p.basenameWithoutExtension(file.path);
      await _controller.exec(.insertAudio, {
        'name': name,
        'displayName': title,
      });
    } catch (_) {
      if (name != null) {
        await AppFiles.deleteFile(AppFiles.getRealPath('audio', name));
      }
      if (mounted) toast.error(message: context.l10n.editor.audioFileError);
    }
  }

  Future<void> _recordAudio() async {
    final result = await MSheet.show<RecordSaveResult>(
      context,
      builder: (_) => const RecordSheet(),
    );
    if (result == null) return;
    await _controller.exec(.insertAudio, {
      'name': result.fileName,
      'displayName': result.name,
    });
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
    final hits = await getIt<DiaryRepository>().searchDiaries(
      query: q,
      limit: 12,
    );
    return [
      for (final hit in hits)
        (id: hit.diary.id, label: _candidateLabel(hit.diary)),
    ];
  }

  String _candidateLabel(Diary d) {
    final title = d.title.trim();
    if (title.isNotEmpty) return title;
    final date = TimeFormat.isoDate(d.time);
    final snippet = MediaMarkup.strip(d.contentText)
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
    if (snippet.isEmpty) return date;
    final clipped = snippet.length > 16
        ? '${snippet.substring(0, 16)}…'
        : snippet;
    return '$date · $clipped';
  }

  @override
  Widget build(BuildContext context) {
    return EditorToolbarHost(
      controller: _controller,
      editable: widget.editable,
      onInsertMedia: _onInsertMedia,
      statusBar: widget.statusBar,
      child: _buildEditor(),
    );
  }

  Widget _buildEditor() {
    return MoodiaryEditor(
      controller: _controller,
      readOnly: !widget.editable,
      initialContent: widget.initialContent,
      initialTitle: widget.initialTitle,
      onChanged: widget.onChanged,
      onTitleChanged: widget.onTitleChanged,
      onActiveHeadingChanged: widget.onActiveHeadingChanged,
      onUrlTap: _openUrl,
      onAttachmentTap: _openAttachment,
      onSaveImage: _saveDataUriImage,
      onImageTap: _previewImages,
      onVideoFullscreen: _openVideoFullscreen,
      onRequestLinkCandidates: _linkCandidates,
      onOpenDiaryLink: widget.onOpenDiaryLink,
      metaJson: widget.metaJson,
      metaReady: widget.metaReady,
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
      firstLineIndent: widget.firstLineIndent,
      fontScale: widget.fontScale,
      rolesResolver: getIt<ThemeManager>().editorRoles,
      fontResolver: () => getIt<ThemeManager>().editorFont,
      mediaResolver: appMediaResolver,
    );
  }
}
