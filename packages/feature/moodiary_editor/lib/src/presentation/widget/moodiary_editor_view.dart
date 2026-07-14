import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_rust/moodiary_rust.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_editor/src/data/markdown_media.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_editor/moodiary_editor.dart';
import 'package:path/path.dart' as p;

/// Markdown 编辑视图，包一层 [MoodiaryEditor]（始终嵌入式，仅渲染正文；AppBar / 阅读态
/// 元信息由 Flutter 原生承载，见 [DiaryPage]）。图片两条路径：原生选图（[_showImageDialog]
/// → 存盘 → insertMedia）与拖拽/粘贴（[_saveDataUriImage]）。
class MoodiaryEditorView extends StatefulWidget {
  final String initialContent;
  final ValueChanged<String> onChanged;

  /// 初始标题 + 标题变更回调（webview 顶部标题区，映射 Diary.title）。
  final String initialTitle;
  final ValueChanged<String>? onTitleChanged;

  /// 命令式句柄（宿主传入以驱动目录跳转 scrollToHeading）；不传则内部自建。
  final MoodiaryEditorController? controller;

  /// 当前顶部可见标题下标变化（目录高亮）。
  final ValueChanged<int>? onActiveHeadingChanged;

  final bool editable;

  /// 全局「首行缩进」偏好（[MoodiaryKVs.firstLineIndent]）。透传给 [MoodiaryEditor]，
  /// 经主题通道下发到 webview，由 CSS `text-indent` 对正文段落生效。
  final bool firstLineIndent;

  /// 本篇自动保存状态，透传给编辑器内右下角气泡：saving / saved / failed。
  final String saveStatus;

  /// 点击双链 chip：入参为目标日记业务 id。导航由上层（[DiaryPage]）实现（本层不依赖路由）。
  final ValueChanged<String>? onOpenDiaryLink;

  /// 编辑器工具栏首位「详情」按钮回调（打开元信息面板）。
  final VoidCallback? onOpenDetails;

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
    this.saveStatus = 'idle',
    this.onOpenDiaryLink,
    this.onOpenDetails,
  });

  @override
  State<MoodiaryEditorView> createState() => _MoodiaryEditorViewState();
}

class _MoodiaryEditorViewState extends State<MoodiaryEditorView> {
  late final _controller = widget.controller ?? MoodiaryEditorController();

  void _showImageDialog() {
    showDialog<void>(
      context: context,
      builder: (sheetContext) {
        return SimpleDialog(
          title: Text(context.l10n.editPickImage),
          children: [
            SimpleDialogOption(
              onPressed: () => _pickFromGallery(sheetContext),
              child: _DialogRow(
                icon: Icons.photo_library_outlined,
                label: context.l10n.editPickImageFromGallery,
              ),
            ),
            SimpleDialogOption(
              onPressed: () => _pickFromCamera(sheetContext),
              child: _DialogRow(
                icon: Icons.camera_alt_outlined,
                label: context.l10n.editPickImageFromCamera,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickFromGallery(BuildContext sheetContext) async {
    Navigator.of(sheetContext).pop();
    final files = await IFilePicker.get().pickImages(context, maxAssets: 10);
    if (files.isEmpty) return;
    await _insertPicked(files);
  }

  Future<void> _pickFromCamera(BuildContext sheetContext) async {
    Navigator.of(sheetContext).pop();
    final file = await IFilePicker.get().takePhoto(context);
    if (file == null) return;
    await _insertPicked([file]);
  }

  /// 乐观插入：选图后立即把原图落到 image 目录并插入显示（快），压缩挪到后台就地进行、
  /// 完成后无感替换同名文件（见 [MediaUtil.materializeOriginal] / [MediaUtil.compressInPlace]）。
  Future<void> _insertPicked(List<XFile> files) async {
    for (final file in files) {
      final name = await MediaUtil.materializeOriginal(file);
      if (name == null) continue;
      await _controller.insertMedia(name);
      unawaited(MediaUtil.compressInPlace(name));
    }
  }

  /// 把 web 侧 data URI 落盘，复用 [MediaUtil.saveImages] 压缩 / 命名，返回存盘
  /// 文件名（失败返回 null）。
  Future<String?> _saveDataUriImage(String dataUri, String fallbackName) async {
    final xfile = await _dataUriToTempFile(dataUri, fallbackName);
    if (xfile == null) return null;
    final saved = await MediaUtil.saveImages(imageFileList: [xfile]);
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
    final tmpPath = FileUtil.getCachePath(tmpName);
    await File(tmpPath).writeAsBytes(bytes);
    return XFile(tmpPath);
  }

  // —— 视频：选取（相册 / 拍摄）→ 存盘（含缩略图）→ insertVideo —— //
  void _showVideoDialog() {
    showDialog<void>(
      context: context,
      builder: (sheetContext) {
        return SimpleDialog(
          title: Text(context.l10n.editPickVideo),
          children: [
            SimpleDialogOption(
              onPressed: () => _pickVideo(sheetContext, fromCamera: false),
              child: _DialogRow(
                icon: Icons.photo_library_outlined,
                label: context.l10n.editPickVideoFromGallery,
              ),
            ),
            SimpleDialogOption(
              onPressed: () => _pickVideo(sheetContext, fromCamera: true),
              child: _DialogRow(
                icon: Icons.camera_alt_outlined,
                label: context.l10n.editPickVideoFromCamera,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickVideo(
    BuildContext sheetContext, {
    required bool fromCamera,
  }) async {
    Navigator.of(sheetContext).pop();
    final file = fromCamera
        ? await IFilePicker.get().recordVideo(context)
        : await IFilePicker.get().pickVideo(context);
    if (file == null) return;
    final saved = await MediaUtil.saveVideo(videoFileList: [file]);
    final name = saved[file.path];
    if (name != null) await _controller.insertVideo(name);
  }

  // —— 音频：选取文件 / 录制 → 落盘 → insertAudio —— //
  void _showAudioDialog() {
    showDialog<void>(
      context: context,
      builder: (sheetContext) {
        return SimpleDialog(
          title: Text(context.l10n.editPickAudio),
          children: [
            SimpleDialogOption(
              onPressed: () => _pickAudioFile(sheetContext),
              child: _DialogRow(
                icon: Icons.audio_file_rounded,
                label: context.l10n.editPickAudioFromFile,
              ),
            ),
            SimpleDialogOption(
              onPressed: () => _recordAudio(sheetContext),
              child: _DialogRow(
                icon: Icons.mic_rounded,
                label: context.l10n.editPickAudioFromRecord,
              ),
            ),
          ],
        );
      },
    );
  }

  /// 复制原文件到 audio 目录、命名 `audio-uuid.ext` 直接落库，不压缩 / 转码。
  Future<void> _pickAudioFile(BuildContext sheetContext) async {
    Navigator.of(sheetContext).pop();
    try {
      final file = await IFilePicker.get().pickAudio();
      if (file == null) return;
      final ext = p.extension(file.path);
      final name = 'audio-${uuidV7()}$ext';
      await File(file.path).copy(FileUtil.getRealPath('audio', name));
      await _controller.insertAudio(name);
    } catch (_) {
      if (mounted) toast.error(message: context.l10n.audioFileError);
    }
  }

  Future<void> _recordAudio(BuildContext sheetContext) async {
    Navigator.of(sheetContext).pop();
    final name = await showFloatingModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const RecordSheet(),
    );
    if (name == null) return;
    await _controller.insertAudio(name);
  }

  // —— 双链候选 = 搜索：不输入关键词不列任何日记（避免列出全部）；输入后走相关性搜索（限量）。
  // 标签：标题优先，否则「日期 · 片段」。
  Future<List<DiaryLinkCandidate>> _linkCandidates(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final diaries = await DiaryRepository.get().searchDiariesByText(q, limit: 12);
    return [for (final d in diaries) (id: d.id, label: _candidateLabel(d))];
  }

  String _candidateLabel(Diary d) {
    final title = d.title.trim();
    if (title.isNotEmpty) return title;
    final date = TimeUtil.isoDate(d.time);
    final snippet = d.contentText.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (snippet.isEmpty) return date;
    final clipped = snippet.length > 16 ? '${snippet.substring(0, 16)}…' : snippet;
    return '$date · $clipped';
  }

  @override
  Widget build(BuildContext context) {
    return MoodiaryEditor(
      controller: _controller,
      readOnly: !widget.editable,
      placeholder: context.l10n.editContent,
      initialContent: widget.initialContent,
      initialTitle: widget.initialTitle,
      onChanged: widget.onChanged,
      onTitleChanged: widget.onTitleChanged,
      onActiveHeadingChanged: widget.onActiveHeadingChanged,
      onPickImage: _showImageDialog,
      onPickAudio: _showAudioDialog,
      onPickVideo: _showVideoDialog,
      onSaveImage: _saveDataUriImage,
      // —— 注入宿主依赖（主题种子 / 媒体磁盘解析 / 加载遮罩）——
      // 音视频在 webview 内用原生元素内联播放；双链候选/跳转见下。
      onRequestLinkCandidates: _linkCandidates,
      onOpenDiaryLink: widget.onOpenDiaryLink,
      onOpenDetails: widget.onOpenDetails,
      saveStatus: widget.saveStatus,
      firstLineIndent: widget.firstLineIndent,
      seedResolver: () => ThemeUtil().editorSeed,
      fontResolver: () => ThemeUtil().editorFont,
      mediaResolver: appMediaResolver,
      loadingBuilder: (_) => const MoodiaryLoading(),
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
