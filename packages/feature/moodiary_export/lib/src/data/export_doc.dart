import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_rust/export.dart';

// freezed 变体类（IrBlock_Paragraph 等）也要透出去，模式匹配要用。
export 'package:moodiary_rust/export.dart'
    show
        IrBlock,
        IrBlock_Code,
        IrBlock_Divider,
        IrBlock_Heading,
        IrBlock_Image,
        IrBlock_List,
        IrBlock_Media,
        IrBlock_Paragraph,
        IrBlock_Quote,
        IrBlock_Table,
        IrCell,
        IrRow,
        IrDoc,
        IrListItem,
        IrSpan;

/// 一篇日记的导出形态。[blocks] 与跨桥的 [IrDoc] 共用同一批类型（由 FRB 生成），
/// 另外几个字段只在 Dart 侧用、不过桥：[time] 保持 DateTime 以便命名文件与格式化，
/// [unsupportedNodes] 是遍历时的诊断信息。
class ExportDoc {
  final String id;
  final String title;
  final DateTime time;
  final DiaryMood mood;
  final DiaryWeather? weather;
  final DiaryPosition? position;
  final List<String> tags;
  final String? categoryName;
  final List<IrBlock> blocks;

  /// 遍历时遇到的、IR 表达不了的 tiptap 节点类型（去重）。非空说明编辑器加了新节点
  /// 而这里没跟上 —— UI 应当把它报给用户，而不是静默产出缺内容的文件。
  final Set<String> unsupportedNodes;

  const ExportDoc({
    required this.id,
    required this.title,
    required this.time,
    required this.blocks,
    this.mood = .neutral,
    this.weather,
    this.position,
    this.tags = const [],
    this.categoryName,
    this.unsupportedNodes = const {},
  });

  /// 过桥形态。[displayTime] 是已本地化的展示串——Rust 侧只照抄进 meta 行。
  ///
  /// [IrDoc] 是 FRB 生成物，天气 / 定位在桥那侧仍是定长 `List<String>` 元组
  /// （`[icon, temp, text]` / `[lat, lng, name]`）；降级只发生在这一处。
  IrDoc toIr(String displayTime) {
    final w = weather;
    final p = position;
    return IrDoc(
      id: id,
      title: title,
      time: displayTime,
      weather: w == null ? const [] : [w.icon, w.temp, w.text],
      position: p == null
          ? const []
          : [p.latitude.toString(), p.longitude.toString(), p.name],
      tags: tags,
      categoryName: categoryName,
      blocks: blocks,
    );
  }
}

/// FRB 生成的 [IrSpan] 每个 bool 都是 required，构造点会很啰嗦；这里补回默认值。
IrSpan irSpan(
  String text, {
  bool bold = false,
  bool italic = false,
  bool strike = false,
  bool underline = false,
  bool code = false,
  String? href,
  String? diaryLinkId,
}) => IrSpan(
  text: text,
  bold: bold,
  italic: italic,
  strike: strike,
  underline: underline,
  code: code,
  href: href,
  diaryLinkId: diaryLinkId,
);

extension IrSpanX on IrSpan {
  bool get isPlain =>
      !bold &&
      !italic &&
      !strike &&
      !underline &&
      !code &&
      href == null &&
      diaryLinkId == null;
}

extension IrListX on IrBlock_List {
  /// 任一项带勾选状态即视为任务列表 —— markdown 写 `- [x]`，docx/pdf 写 ☑/☐。
  bool get isTask => items.any((i) => i.checked != null);
}
