import 'package:moodiary_editor/moodiary_editor.dart'
    show MoodiaryEditorController;
import 'package:moodiary_editor/src/presentation/widget/moodiary_editor_view.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';

class EditorBody extends StatefulWidget {
  final DiaryType type;
  final String initialContent;

  final String initialTitle;
  final ValueChanged<String>? onTitleChanged;

  final MoodiaryEditorController? editorController;
  final ValueChanged<int>? onActiveHeadingChanged;

  final bool editable;

  final void Function(String content, String contentText) onChanged;

  final ValueChanged<String>? onOpenDiaryLink;

  final String saveStatus;

  final String? metaJson;
  final String? linksJson;
  final ValueChanged<DateTime>? onChangeDate;
  final ValueChanged<TimeOfDay>? onChangeTime;
  final ValueChanged<String?>? onChangeCategory;
  final ValueChanged<String>? onAddTag;
  final ValueChanged<String>? onRemoveTag;
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
  final ValueChanged<bool>? onOverlayChanged;

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
    this.onOpenDiaryLink,
    this.saveStatus = 'idle',
    this.metaJson,
    this.linksJson,
    this.onChangeDate,
    this.onChangeTime,
    this.onChangeCategory,
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
    this.onOverlayChanged,
  });

  @override
  State<EditorBody> createState() => _EditorBodyState();
}

class _EditorBodyState extends State<EditorBody> {
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
    final content = widget.initialContent;
    switch (widget.type) {
      case .tiptap:
        return content;
      case .markdown:
        return MarkdownToTiptap.convert(content) ??
            TiptapContent.wrapPlainText(content);
      case .richText:
        final converted = QuillDeltaToTiptap.convert(content);
        if (converted != null) return converted;
        var plain = QuillDelta.plainText(content) ?? content;
        if (plain.trim().isEmpty && content.trim().isNotEmpty) plain = content;
        return MarkdownToTiptap.convert(plain) ??
            TiptapContent.wrapPlainText(plain);
    }
  }

  @override
  Widget build(BuildContext context) {
    // webview 的 Android textZoom 钉死为 100，系统字号缩放需在此显式算出下发
    final fontScale = MediaQuery.textScalerOf(context).scale(16) / 16;
    return ValueListenableBuilder<bool>(
      valueListenable: MoodiaryKVs.firstLineIndent.getNotifier(),
      builder: (context, firstLineIndent, _) => MoodiaryEditorView(
        initialContent: _content,
        initialTitle: widget.initialTitle,
        onTitleChanged: widget.onTitleChanged,
        controller: widget.editorController,
        onActiveHeadingChanged: widget.onActiveHeadingChanged,
        editable: widget.editable && widget.type.isEditable,
        saveStatus: widget.saveStatus,
        firstLineIndent: firstLineIndent,
        fontScale: fontScale,
        onChanged: (content) =>
            widget.onChanged(content, TiptapContent.parse(content).plainText),
        onOpenDiaryLink: widget.onOpenDiaryLink,
        metaJson: widget.metaJson,
        linksJson: widget.linksJson,
        onChangeDate: widget.onChangeDate,
        onChangeTime: widget.onChangeTime,
        onChangeCategory: widget.onChangeCategory,
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
        onOverlayChanged: widget.onOverlayChanged,
      ),
    );
  }
}
