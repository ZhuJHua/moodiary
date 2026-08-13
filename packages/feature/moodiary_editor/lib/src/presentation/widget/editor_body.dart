import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_editor/moodiary_editor.dart'
    show MoodiaryEditorController;
import 'package:moodiary_editor/src/presentation/widget/moodiary_editor_view.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';

/// 编辑页正文区域：三种 [DiaryType] 统一由 TipTap webview（[MoodiaryEditorView]）承载，
/// 变更经 [onChanged] 透传 `(content, contentText)`。
///
/// 只有 tiptap 可编辑；markdown 与 richText 是旧格式只读。richText 的 Quill Delta 在此
/// 即时转成 TipTap 文档再渲染——与「迁移」按钮用的是同一个 [QuillDeltaToTiptap]，所见即
/// 迁移后所得；库里仍是原始 Delta，只读路径不写回。
class EditorBody extends StatefulWidget {
  final DiaryType type;
  final String initialContent;

  /// 初始标题 + 标题变更回调（映射 Diary.title）。
  final String initialTitle;
  final ValueChanged<String>? onTitleChanged;

  /// 目录跳转句柄 + 当前标题下标变化。
  final MoodiaryEditorController? editorController;
  final ValueChanged<int>? onActiveHeadingChanged;

  final bool editable;

  /// `(content, contentText)`：TipTap 文档 JSON + 纯文本镜像。
  final void Function(String content, String contentText) onChanged;

  /// 「详情」回调：编辑器工具栏首位按钮用它打开元信息面板。
  final VoidCallback? onShowDetails;

  /// 点击双链 chip 的回调，上层导航到目标日记。
  final ValueChanged<String>? onOpenDiaryLink;

  /// 本篇自动保存状态，驱动编辑器右下角气泡：saving / saved / failed。
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
  /// 喂给 webview 的正文；richText 为转换结果，其余类型即原文。转换只在内容/类型变化时做。
  late String _content = _resolveContent();

  @override
  void didUpdateWidget(covariant EditorBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.type != widget.type ||
        oldWidget.initialContent != widget.initialContent) {
      _content = _resolveContent();
    }
  }

  String _resolveContent() {
    if (widget.type != .richText) return widget.initialContent;
    final converted = QuillDeltaToTiptap.convert(widget.initialContent);
    if (converted != null) return converted;
    // 不是合法 Delta（极老版本的裸文本残留）：按纯文本兜底，宁可掉格式也要能看。
    final plain =
        QuillDelta.plainText(widget.initialContent) ?? widget.initialContent;
    return MarkdownToTiptap.convert(plain) ?? plain;
  }

  @override
  Widget build(BuildContext context) {
    // 首行缩进走 KV；字号跟随系统 —— webview 的 Android textZoom 被钉死为 100
    // （见 webview_flutter_transport），所以系统缩放必须由这里显式算出来下发，
    // 两端才是同一个倍率。boot 首帧与运行时实时切换共用同一路径。
    final fontScale = MediaQuery.textScalerOf(context).scale(16) / 16;
    return ValueListenableBuilder<bool>(
      valueListenable: MoodiaryKVs.firstLineIndent.getNotifier(),
      builder: (context, firstLineIndent, _) => MoodiaryEditorView(
        initialContent: _content,
        initialTitle: widget.initialTitle,
        onTitleChanged: widget.onTitleChanged,
        controller: widget.editorController,
        onActiveHeadingChanged: widget.onActiveHeadingChanged,
        // 仅 tiptap 可编辑；markdown / richText 只读查看。
        editable: widget.editable && widget.type.isEditable,
        saveStatus: widget.saveStatus,
        firstLineIndent: firstLineIndent,
        fontScale: fontScale,
        onChanged: (content) =>
            widget.onChanged(content, TiptapContent.parse(content).plainText),
        onOpenDiaryLink: widget.onOpenDiaryLink,
        onOpenDetails: widget.onShowDetails,
      ),
    );
  }
}
