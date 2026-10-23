import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';

IconData mediaKindIcon(MediaKind? kind) => switch (kind) {
  .image => LucideIcons.image,
  .video => LucideIcons.video,
  .audio => LucideIcons.music,
  .attachment => LucideIcons.paperclip,
  null => LucideIcons.file,
};

List<InlineSpan> mediaMarkedSpans(
  String text, {
  required TextStyle style,
  List<InlineSpan> Function(String text)? textSpans,
}) {
  final spansOf = textSpans ?? (t) => [TextSpan(text: t)];
  final size = (style.fontSize ?? 14) * 0.95;
  return [
    for (final run in MediaMarkup.parse(text))
      ...switch (run) {
        TextRun(:final text) => spansOf(text),
        MediaRun(:final kind, :final text) => [
          WidgetSpan(
            alignment: .middle,
            child: Padding(
              padding: const .only(right: 3),
              child: Icon(mediaKindIcon(kind), size: size, color: style.color),
            ),
          ),
          ...spansOf(text),
        ],
      },
  ];
}

class MediaMarkedText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow? overflow;

  const MediaMarkedText(
    this.text, {
    super.key,
    required this.style,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: mediaMarkedSpans(text, style: style)),
      style: style,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
