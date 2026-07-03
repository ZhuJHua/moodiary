import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_ui/moodiary_ui.dart';

const double _kAccentWidth = 4.0;

Widget _cardShell({
  required BuildContext context,
  required Diary diary,
  required Category? category,
  required bool showCategoryLabel,
  required VoidCallback? onTap,
  required Widget child,
}) {
  final scheme = context.colorScheme;
  final accent = category == null
      ? null
      : categoryColorOf(colorValue: category.color, id: category.id);
  return Card.filled(
    color: scheme.surfaceContainerLow,
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: accent == null
          ? child
          : Stack(
              children: [
                child,
                PositionedDirectional(
                  start: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(width: _kAccentWidth, color: accent),
                ),
              ],
            ),
    ),
  );
}

class _MetaFooter extends StatelessWidget {
  final Diary diary;
  final Category? category;
  final bool showCategoryLabel;

  const _MetaFooter({
    required this.diary,
    required this.category,
    required this.showCategoryLabel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final onVariant = scheme.onSurfaceVariant;
    final labelStyle = context.textTheme.labelSmall?.copyWith(color: onVariant);
    final children = <Widget>[];

    if (showCategoryLabel && category != null) {
      final color =
          categoryColorOf(colorValue: category!.color, id: category!.id);
      children.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(category!.categoryName,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: labelStyle),
        ],
      ));
    }

    children.add(Text(DateFormat.MMMEd().format(diary.time), style: labelStyle));

    if (diary.weather.length >= 3) {
      children.add(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_outlined, size: 12, color: onVariant),
          const SizedBox(width: 3),
          Text('${diary.weather[2]} ${diary.weather[1]}°', style: labelStyle),
        ],
      ));
    }

    children.add(MoodIconComponent(value: diary.mood, width: 16));

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}

Widget _title(BuildContext context, String title) => Text(
      title.trim(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.textTheme.titleMedium
          ?.copyWith(color: context.colorScheme.onSurface),
    );

Widget _content(BuildContext context, String text, {required int maxLines}) =>
    Text(
      text.trim().removeLineBreaks(),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: context.textTheme.bodyMedium
          ?.copyWith(color: context.colorScheme.onSurfaceVariant),
    );

Widget _image(String name, double pixelRatio, double targetWidth,
        {required BoxFit fit}) =>
    Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: ResizeImage(
            FileImage(File(FileUtil.getRealPath('image', name))),
            width: (targetWidth * pixelRatio).toInt(),
          ),
          fit: fit,
        ),
        borderRadius: AppBorderRadius.mediumBorderRadius,
      ),
    );

class DiaryListTile extends StatelessWidget {
  final Diary diary;
  final Category? category;
  final bool showCategoryLabel;
  final VoidCallback? onTap;

  const DiaryListTile({
    super.key,
    required this.diary,
    this.category,
    this.showCategoryLabel = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    return _cardShell(
      context: context,
      diary: diary,
      category: category,
      showCategoryLabel: showCategoryLabel,
      onTap: onTap,
      child: SizedBox(
        height: 132.0,
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (diary.title.isNotEmpty) ...[
                      _title(context, diary.title),
                      const SizedBox(height: 4),
                    ],
                    Expanded(
                      child: _content(context, diary.contentText,
                          maxLines: diary.title.isNotEmpty ? 3 : 4),
                    ),
                    const SizedBox(height: 6),
                    _MetaFooter(
                        diary: diary,
                        category: category,
                        showCategoryLabel: showCategoryLabel),
                  ],
                ),
              ),
            ),
            if (diary.imageName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: _image(diary.imageName.first, pixelRatio, 132,
                      fit: BoxFit.cover),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class DiaryGridTile extends StatelessWidget {
  final Diary diary;
  final Category? category;
  final bool showCategoryLabel;
  final VoidCallback? onTap;

  const DiaryGridTile({
    super.key,
    required this.diary,
    this.category,
    this.showCategoryLabel = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    return _cardShell(
      context: context,
      diary: diary,
      category: category,
      showCategoryLabel: showCategoryLabel,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (diary.imageName.isNotEmpty)
            SizedBox(
              height: 154.0,
              width: double.infinity,
              child: _image(diary.imageName.first, pixelRatio, 250,
                  fit: BoxFit.cover),
            ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (diary.title.isNotEmpty) ...[
                  _title(context, diary.title),
                  const SizedBox(height: 4),
                ],
                if (diary.contentText.isNotEmpty) ...[
                  _content(context, diary.contentText, maxLines: 4),
                  const SizedBox(height: 6),
                ],
                _MetaFooter(
                    diary: diary,
                    category: category,
                    showCategoryLabel: showCategoryLabel),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CalendarDiaryCard extends StatelessWidget {
  final Diary diary;
  final Category? category;
  final bool showCategoryLabel;
  final VoidCallback? onTap;

  const CalendarDiaryCard({
    super.key,
    required this.diary,
    this.category,
    this.showCategoryLabel = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final scheme = context.colorScheme;
    return _cardShell(
      context: context,
      diary: diary,
      category: category,
      showCategoryLabel: showCategoryLabel,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (diary.title.isNotEmpty) ...[
              _title(context, diary.title),
              const SizedBox(height: 4),
            ],
            if (diary.contentText.isNotEmpty) ...[
              _content(context, diary.contentText, maxLines: 4),
              const SizedBox(height: 8),
            ],
            if (diary.imageName.isNotEmpty) ...[
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: diary.imageName.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 4),
                  itemBuilder: (context, i) => SizedBox(
                    width: 100,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: scheme.outlineVariant),
                        borderRadius: AppBorderRadius.smallBorderRadius,
                      ),
                      child: _image(diary.imageName[i], pixelRatio, 100,
                          fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            _MetaFooter(
                diary: diary,
                category: category,
                showCategoryLabel: showCategoryLabel),
          ],
        ),
      ),
    );
  }
}
