import 'package:fast_press/fast_press.dart';
import 'package:moodiary_models/moodiary_models.dart';

export 'package:fast_press/fast_press.dart'
    show
        IrBlock,
        IrBlock_Attachment,
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
        IrDividerVariant,
        IrRow,
        IrDoc,
        IrListItem,
        IrSpan;

class ExportDoc {
  final String id;
  final String title;
  final DateTime time;
  final DiaryMood mood;
  final DiaryWeather? weather;
  final Place? place;
  final List<String> tags;
  final String? categoryName;
  final List<IrBlock> blocks;

  final Set<String> unsupportedNodes;

  const ExportDoc({
    required this.id,
    required this.title,
    required this.time,
    required this.blocks,
    this.mood = .neutral,
    this.weather,
    this.place,
    this.tags = const [],
    this.categoryName,
    this.unsupportedNodes = const {},
  });

  IrDoc toIr(String displayTime) {
    final w = weather;
    final p = place;
    return IrDoc(
      id: id,
      title: title,
      time: displayTime,
      weather: w == null ? const [] : [w.icon, w.temp ?? '', w.text],
      position: p == null
          ? const []
          : [p.latitude.toString(), p.longitude.toString(), p.name],
      tags: tags,
      categoryName: categoryName,
      blocks: blocks,
    );
  }
}

IrSpan irSpan(
  String text, {
  bool bold = false,
  bool italic = false,
  bool strike = false,
  bool underline = false,
  bool code = false,
  bool highlight = false,
  String? href,
  String? diaryLinkId,
}) => IrSpan(
  text: text,
  bold: bold,
  italic: italic,
  strike: strike,
  underline: underline,
  code: code,
  highlight: highlight,
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
      !highlight &&
      href == null &&
      diaryLinkId == null;
}

extension IrListX on IrBlock_List {
  bool get isTask => items.any((i) => i.checked != null);
}

extension IrDividerX on IrBlock_Divider {
  String? get visibleLabel {
    if (variant != .text) return null;
    final trimmed = label?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}

String formatByteSize(int bytes) {
  const units = ['KB', 'MB', 'GB', 'TB'];
  if (bytes < 1024) return '${bytes < 0 ? 0 : bytes} B';
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(value < 10 ? 1 : 0)} ${units[unit]}';
}
