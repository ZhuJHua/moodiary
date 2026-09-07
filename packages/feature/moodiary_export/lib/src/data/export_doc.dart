import 'package:fast_press/fast_press.dart';
import 'package:moodiary_models/moodiary_models.dart';

export 'package:fast_press/fast_press.dart'
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
  bool get isTask => items.any((i) => i.checked != null);
}
