import 'dart:ui' as ui;

import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

import '../../data/export_doc.dart';
import '../../data/export_options.dart';
import 'blocks.dart';
import 'card_style.dart';

const double kBrandMarkSize = 18;

class ImageCard extends StatelessWidget {
  final List<ExportDoc> docs;
  final ExportCommon common;
  final ImageCardStyle style;
  final Map<String, ui.Image> images;

  final ui.Image? brand;

  const ImageCard({
    super.key,
    required this.docs,
    required this.common,
    required this.style,
    required this.images,
    this.brand,
  });

  @override
  Widget build(BuildContext context) {
    final renderer = IrBlockRenderer(style: style, images: images);
    final children = <Widget>[];
    for (var i = 0; i < docs.length; i++) {
      if (i > 0) children.add(_docSeparator());
      children.addAll(_doc(docs[i], renderer));
    }
    if (style.watermark) children.add(_footer());

    return Container(
      width: style.widthDp,
      color: style.background,
      padding: const EdgeInsets.fromLTRB(
        ImageCardStyle.horizontalPadding,
        ImageCardStyle.topPadding,
        ImageCardStyle.horizontalPadding,
        ImageCardStyle.bottomPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  List<Widget> _doc(ExportDoc doc, IrBlockRenderer renderer) {
    final out = <Widget>[];
    if (common.includeMeta) out.addAll(_meta(doc));
    if (common.includeTitle && doc.title.trim().isNotEmpty) {
      out.add(
        Padding(
          padding: EdgeInsets.only(top: common.includeMeta ? 18 : 0),
          child: Text(doc.title, style: style.title),
        ),
      );
    }
    final blocks = renderer.blocks(doc.blocks);
    if (blocks.isNotEmpty) {
      out.add(
        Padding(
          padding: EdgeInsets.only(top: out.isEmpty ? 0 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: blocks,
          ),
        ),
      );
    }
    return out;
  }

  List<Widget> _meta(ExportDoc doc) {
    final chips = <Widget>[
      _moodChip(doc.mood),
      if (doc.weather case final w?)
        _metaItem(LucideIcons.cloudSun, w.displayText),
      if (doc.categoryName case final name? when name.isNotEmpty)
        _metaItem(LucideIcons.folder, name),
      if (common.includePosition)
        if (doc.place case final p?) _metaItem(LucideIcons.mapPin, p.name),
    ];

    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(TimeFormat.monthDay(doc.time), style: style.dateAnchor),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              TimeFormat.weekdayTimeHms(doc.time),
              style: style.meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Wrap(spacing: 10, runSpacing: 6, children: chips),
      ),
      if (doc.tags.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final tag in doc.tags)
                Text('#$tag', style: style.meta.copyWith(color: style.outline)),
            ],
          ),
        ),
    ];
  }

  Widget _moodChip(DiaryMood mood) {
    final color = mood.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: style.brightness == Brightness.dark ? 0.18 : 0.15,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(mood.icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            mood.labelOf(l10n),
            style: style.metaStrong.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  Widget _metaItem(IconData icon, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: style.muted),
      const SizedBox(width: 5),
      ConstrainedBox(
        constraints: BoxConstraints(maxWidth: style.contentWidth * 0.5),
        child: Text(
          text,
          style: style.meta,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );

  Widget _docSeparator() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 28),
    child: Row(
      children: [
        Expanded(child: Container(height: 1, color: style.hairline)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Icon(LucideIcons.dot, size: 16, color: style.outline),
        ),
        Expanded(child: Container(height: 1, color: style.hairline)),
      ],
    ),
  );

  Widget _footer() => Padding(
    padding: const EdgeInsets.only(top: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(height: 1, color: style.hairline),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (brand case final mark?) ...[
                RawImage(
                  image: mark,
                  width: kBrandMarkSize,
                  height: kBrandMarkSize,
                  filterQuality: FilterQuality.medium,
                ),
                const SizedBox(width: 7),
              ],
              Text(
                'Moodiary',
                style: style.meta.copyWith(
                  letterSpacing: 0.5,
                  color: style.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
