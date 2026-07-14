import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_editor/src/quill_embed/audio_embed.dart';
import 'package:moodiary_editor/src/quill_embed/image_embed.dart';
import 'package:moodiary_editor/src/quill_embed/text_indent_embed.dart';
import 'package:moodiary_editor/src/quill_embed/video_embed.dart';
import 'package:moodiary_rust/moodiary_rust.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_editor/src/presentation/widget/editor_toolbar.dart';
import 'package:moodiary_editor/src/presentation/widget/moodiary_editor_view.dart';
import 'package:moodiary_editor/src/presentation/widget/record_sheet.dart';
import 'package:moodiary_editor/moodiary_editor.dart'
    show MoodiaryEditorController;
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:path/path.dart' as p;

/// 编辑页正文区域，按 [DiaryType] 切换 markdown（[MoodiaryEditorView]）与 richText
/// （[QuillEditor]）两种编辑器，变更经 [onChanged] 透传 `(content, contentText)`。
class EditorBody extends StatefulWidget {
  final DiaryType type;
  final String initialContent;

  /// 初始标题 + 标题变更回调（仅 tiptap/markdown 的 webview 编辑器用；richText 无标题）。
  final String initialTitle;
  final ValueChanged<String>? onTitleChanged;

  /// 目录跳转句柄 + 当前标题下标变化（仅 webview 编辑器；richText 无目录）。
  final MoodiaryEditorController? editorController;
  final ValueChanged<int>? onActiveHeadingChanged;

  final bool editable;

  /// `(content, contentText)`：markdown 为源码 + 剥离语法后纯文本；richText 为
  /// Delta JSON + 纯文本镜像。
  final void Function(String content, String contentText) onChanged;

  /// 「详情」回调：richText 原生工具栏 + tiptap webview 工具栏首位按钮都用它打开元信息面板。
  final VoidCallback? onShowDetails;

  /// 点击双链 chip 的回调（仅 tiptap 用），上层导航到目标日记。
  final ValueChanged<String>? onOpenDiaryLink;

  /// 本篇自动保存状态（仅 tiptap webview 用），驱动编辑器右下角气泡：saving / saved / failed。
  final String saveStatus;

  const EditorBody({
    super.key,
    required this.type,
    required this.initialContent,
    required this.onChanged,
    this.initialTitle = '',
    this.onTitleChanged,
    this.editorController,
    this.onActiveHeadingChanged,
    this.editable = true,
    this.onShowDetails,
    this.onOpenDiaryLink,
    this.saveStatus = 'idle',
  });

  @override
  State<EditorBody> createState() => _EditorBodyState();
}

class _EditorBodyState extends State<EditorBody> {
  QuillController? _quillController;

  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _bindControllers();
  }

  @override
  void didUpdateWidget(covariant EditorBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.type != widget.type) {
      _disposeControllers();
      _bindControllers();
    } else if (oldWidget.editable != widget.editable) {
      // 富文本就地切 readOnly（markdown 由 MoodiaryEditor 自理）。
      _quillController?.readOnly = !widget.editable;
    }
  }

  void _bindControllers() {
    switch (widget.type) {
      // tiptap / markdown 都不需要 Quill 控制器（前者 webview JSON，后者只读 markdown 走 webview）。
      case DiaryType.tiptap:
      case DiaryType.markdown:
        break;
      case DiaryType.richText:
        Document doc;
        try {
          final raw = widget.initialContent.trim();
          if (raw.isEmpty) {
            doc = Document();
          } else {
            doc = Document.fromJson(jsonDecode(raw) as List<dynamic>);
          }
        } catch (_) {
          // 兼容旧库纯文本：直接装入 Document。
          doc = Document()..insert(0, widget.initialContent);
        }
        final controller = QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
          readOnly: !widget.editable,
        );
        controller.addListener(_onQuillChanged);
        _quillController = controller;
    }
  }

  void _disposeControllers() {
    _quillController?.removeListener(_onQuillChanged);
    _quillController?.dispose();
    _quillController = null;
  }

  void _onQuillChanged() {
    final ctrl = _quillController;
    if (ctrl == null) return;
    // 阅读模式下选区变化也触发监听，但不应上报内容变更 / 触发自动保存。
    if (!widget.editable) return;
    final delta = jsonEncode(ctrl.document.toDelta().toJson());
    final plain = ctrl.document.toPlainText().trimRight();
    widget.onChanged(delta, plain);
  }

  @override
  void dispose() {
    _disposeControllers();
    _focusNode.dispose();
    super.dispose();
  }

  void _insertEmbed(BlockEmbed embed) {
    final ctrl = _quillController;
    if (ctrl == null) return;
    final index = ctrl.selection.baseOffset;
    final length = ctrl.selection.extentOffset - index;
    ctrl.replaceText(index, length, embed, null);
    ctrl.moveCursorToPosition(index + 1);
  }

  Future<void> _pickImageFromGallery({required BuildContext sheetContext}) async {
    Navigator.of(sheetContext).pop();
    final files = await IFilePicker.get().pickImages(context);
    if (files.isEmpty) return;
    final saved = await MediaUtil.saveImages(imageFileList: files);
    // saveImages 返回 {tempPath: finalName}；按用户挑选顺序插入。
    for (final file in files) {
      final name = saved[file.path];
      if (name != null) _insertEmbed(ImageBlockEmbed.fromName(name));
    }
  }

  Future<void> _pickImageFromCamera({required BuildContext sheetContext}) async {
    Navigator.of(sheetContext).pop();
    final file = await IFilePicker.get().takePhoto(context);
    if (file == null) return;
    final saved = await MediaUtil.saveImages(imageFileList: [file]);
    final name = saved[file.path];
    if (name != null) _insertEmbed(ImageBlockEmbed.fromName(name));
  }

  Future<void> _pickVideoFromGallery({required BuildContext sheetContext}) async {
    Navigator.of(sheetContext).pop();
    final file = await IFilePicker.get().pickVideo(context);
    if (file == null) return;
    final saved = await MediaUtil.saveVideo(videoFileList: [file]);
    final name = saved[file.path];
    if (name != null) _insertEmbed(VideoBlockEmbed.fromName(name));
  }

  Future<void> _pickVideoFromCamera({required BuildContext sheetContext}) async {
    Navigator.of(sheetContext).pop();
    final file = await IFilePicker.get().recordVideo(context);
    if (file == null) return;
    final saved = await MediaUtil.saveVideo(videoFileList: [file]);
    final name = saved[file.path];
    if (name != null) _insertEmbed(VideoBlockEmbed.fromName(name));
  }

  /// 复制原文件到 audio 目录、命名 `audio-uuid.ext` 直接落库，不走压缩 / 转码。
  Future<void> _pickAudioFile({required BuildContext sheetContext}) async {
    Navigator.of(sheetContext).pop();
    try {
      final file = await IFilePicker.get().pickAudio();
      if (file == null) return;
      final ext = p.extension(file.path);
      final name = 'audio-${uuidV7()}$ext';
      final dst = FileUtil.getRealPath('audio', name);
      await File(file.path).copy(dst);
      _insertEmbed(AudioBlockEmbed.fromName(name));
    } catch (_) {
      if (mounted) toast.error(message: context.l10n.audioFileError);
    }
  }

  Future<void> _recordAudio({required BuildContext sheetContext}) async {
    Navigator.of(sheetContext).pop();
    final name = await showFloatingModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const RecordSheet(),
    );
    if (name == null) return;
    _insertEmbed(AudioBlockEmbed.fromName(name));
  }

  void _showImageDialog() {
    showDialog<void>(
      context: context,
      builder: (sheetContext) {
        return SimpleDialog(
          title: Text(context.l10n.editPickImage),
          children: [
            SimpleDialogOption(
              onPressed: () =>
                  _pickImageFromGallery(sheetContext: sheetContext),
              child: _DialogRow(
                icon: Icons.photo_library_outlined,
                label: context.l10n.editPickImageFromGallery,
              ),
            ),
            SimpleDialogOption(
              onPressed: () =>
                  _pickImageFromCamera(sheetContext: sheetContext),
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

  void _showVideoDialog() {
    showDialog<void>(
      context: context,
      builder: (sheetContext) {
        return SimpleDialog(
          title: Text(context.l10n.editPickVideo),
          children: [
            SimpleDialogOption(
              onPressed: () =>
                  _pickVideoFromGallery(sheetContext: sheetContext),
              child: _DialogRow(
                icon: Icons.photo_library_outlined,
                label: context.l10n.editPickVideoFromGallery,
              ),
            ),
            SimpleDialogOption(
              onPressed: () =>
                  _pickVideoFromCamera(sheetContext: sheetContext),
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

  void _showAudioDialog() {
    showDialog<void>(
      context: context,
      builder: (sheetContext) {
        return SimpleDialog(
          title: Text(context.l10n.editPickAudio),
          children: [
            SimpleDialogOption(
              onPressed: () => _pickAudioFile(sheetContext: sheetContext),
              child: _DialogRow(
                icon: Icons.audio_file_rounded,
                label: context.l10n.editPickAudioFromFile,
              ),
            ),
            SimpleDialogOption(
              onPressed: () => _recordAudio(sheetContext: sheetContext),
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

  @override
  Widget build(BuildContext context) {
    return switch (widget.type) {
      DiaryType.tiptap => _buildMoodiaryEditor(context),
      // 旧 markdown 日记：复用 TipTap 编辑器只读查看（editable 由 type.isEditable 钳为 false）。
      DiaryType.markdown => _buildMoodiaryEditor(context),
      DiaryType.richText => _buildRichTextEditor(context),
    };
  }

  Widget _buildMoodiaryEditor(BuildContext context) {
    // 全局「首行缩进」偏好：监听 KV，开关变更即重建并透传给 webview（走主题通道下发，
    // web 侧据此切 CSS text-indent）。boot 首帧与运行时实时切换共用同一路径。
    return ValueListenableBuilder<bool>(
      valueListenable: MoodiaryKVs.firstLineIndent.getNotifier(),
      builder: (context, firstLineIndent, _) => MoodiaryEditorView(
        initialContent: widget.initialContent,
        initialTitle: widget.initialTitle,
        onTitleChanged: widget.onTitleChanged,
        controller: widget.editorController,
        onActiveHeadingChanged: widget.onActiveHeadingChanged,
        // 仅 tiptap 可编辑；旧 markdown 只读查看。
        editable: widget.editable && widget.type.isEditable,
        saveStatus: widget.saveStatus,
        firstLineIndent: firstLineIndent,
        // content 为 TipTap 文档 JSON；contentText 走 JSON 解析得纯文本（旧 markdown 自动兼容）。
        onChanged: (content) =>
            widget.onChanged(content, TiptapContent.plainText(content)),
        onOpenDiaryLink: widget.onOpenDiaryLink,
        onOpenDetails: widget.onShowDetails,
      ),
    );
  }

  Widget _buildRichTextEditor(BuildContext context) {
    final controller = _quillController;
    if (controller == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: QuillEditor.basic(
            controller: controller,
            focusNode: _focusNode,
            config: QuillEditorConfig(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              placeholder: context.l10n.editContent,
              expands: true,
              showCursor: widget.editable,
              paintCursorAboveText: true,
              keyboardAppearance:
                  CupertinoTheme.maybeBrightnessOf(context) ??
                  Theme.of(context).brightness,
              customStyles: ThemeUtil.getInstance(
                context,
                customColorScheme: scheme,
              ),
              embedBuilders: [
                ImageEmbedBuilder(),
                VideoEmbedBuilder(isEdit: widget.editable),
                AudioEmbedBuilder(),
                // 旧「首行缩进」日记（≤2.7.3）正文里的 text_indent 占位：渲染成等宽留白。
                TextIndentEmbedBuilder(),
              ],
              // 其它历史未知 embed 一律降级为零尺寸空白，杜绝 UnimplementedError 崩渲染。
              unknownEmbedBuilder: UnknownEmbedBuilder(),
            ),
          ),
        ),
        // richText 现为旧格式只读，不再提供编辑工具栏（type.isEditable 恒为 false）。
        if (widget.editable && widget.type.isEditable)
          _buildMobileToolbar(controller),
      ],
    );
  }

  Widget _buildMobileToolbar(QuillController controller) {
    return EditorToolbar(
      leadingActions: [
        if (widget.onShowDetails != null)
          EditorToolbarAction(
            icon: Icons.tune_rounded,
            onPressed: () => widget.onShowDetails?.call(),
          ),
        EditorToolbarAction(
          icon: Icons.image_rounded,
          onPressed: _showImageDialog,
        ),
        EditorToolbarAction(
          icon: Icons.movie_rounded,
          onPressed: _showVideoDialog,
        ),
        EditorToolbarAction(
          icon: Icons.audiotrack_rounded,
          onPressed: _showAudioDialog,
        ),
      ],
      formatActions: [
        EditorToolbarAction(
          icon: Icons.format_bold,
          onPressed: () => _toggleInline(controller, Attribute.bold),
        ),
        EditorToolbarAction(
          icon: Icons.format_italic,
          onPressed: () => _toggleInline(controller, Attribute.italic),
        ),
        EditorToolbarAction(
          icon: Icons.format_underlined,
          onPressed: () => _toggleInline(controller, Attribute.underline),
        ),
        EditorToolbarAction(
          icon: Icons.format_strikethrough,
          onPressed: () => _toggleInline(controller, Attribute.strikeThrough),
        ),
        EditorToolbarAction(
          icon: Icons.looks_one_rounded,
          onPressed: () => _toggleHeader(controller, Attribute.h1),
        ),
        EditorToolbarAction(
          icon: Icons.looks_two_rounded,
          onPressed: () => _toggleHeader(controller, Attribute.h2),
        ),
        EditorToolbarAction(
          icon: Icons.looks_3_rounded,
          onPressed: () => _toggleHeader(controller, Attribute.h3),
        ),
        EditorToolbarAction(
          icon: Icons.format_quote_rounded,
          onPressed: () => _toggleBlock(controller, Attribute.blockQuote),
        ),
        EditorToolbarAction(
          icon: Icons.format_list_bulleted_rounded,
          onPressed: () => _toggleBlock(controller, Attribute.ul),
        ),
        EditorToolbarAction(
          icon: Icons.format_list_numbered_rounded,
          onPressed: () => _toggleBlock(controller, Attribute.ol),
        ),
        EditorToolbarAction(
          icon: Icons.code_rounded,
          onPressed: () => _toggleBlock(controller, Attribute.codeBlock),
        ),
      ],
    );
  }

  void _toggleInline(QuillController controller, Attribute attr) {
    final isApplied = controller
        .getSelectionStyle()
        .attributes
        .containsKey(attr.key);
    controller.formatSelection(isApplied ? Attribute.clone(attr, null) : attr);
  }

  void _toggleHeader(QuillController controller, Attribute headerAttr) {
    final current =
        controller.getSelectionStyle().attributes[Attribute.header.key];
    final isSame = current?.value == headerAttr.value;
    controller.formatSelection(isSame ? Attribute.header : headerAttr);
  }

  /// ul/ol 共用 `list` key，互相切换时直接覆盖。
  void _toggleBlock(QuillController controller, Attribute attr) {
    final current = controller.getSelectionStyle().attributes[attr.key];
    final isSame = current?.value == attr.value;
    controller.formatSelection(isSame ? Attribute.clone(attr, null) : attr);
  }

}

class _DialogRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _DialogRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon),
        const SizedBox(width: 12),
        Text(label),
      ],
    );
  }
}
