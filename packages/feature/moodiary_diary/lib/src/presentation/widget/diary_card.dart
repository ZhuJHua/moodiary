import 'dart:io';

import 'package:flutter/material.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_ui/moodiary_ui.dart';

/// 卡片同步状态：内联展示在元信息行里（不再用会盖住内容的角标）。
enum DiaryCardSyncState { none, dirty, syncing }

Widget _cardShell({
  required BuildContext context,
  required VoidCallback? onTap,
  required Widget child,
  VoidCallback? onLongPress,
  bool selecting = false,
  bool selected = false,
}) {
  final scheme = context.colorScheme;
  return Card.filled(
    color: scheme.surfaceContainerLow,
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    // 选中：主色描边（不再微染背景）；右上勾选圈另表状态。
    shape: RoundedRectangleBorder(
      borderRadius: AppBorderRadius.mediumBorderRadius,
      side: selected
          ? BorderSide(color: scheme.primary, width: 2)
          : BorderSide.none,
    ),
    child: InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        children: [
          child,
          if (selecting)
            PositionedDirectional(
              top: 8,
              end: 8,
              child: _SelectMark(selected: selected),
            ),
        ],
      ),
    ),
  );
}

/// 多选态右上角的勾选圈：选中填充主色 + 勾，未选空心圈。
class _SelectMark extends StatelessWidget {
  final bool selected;
  const _SelectMark({required this.selected});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected
            ? scheme.primary
            : scheme.surface.withValues(alpha: 0.85),
        border: Border.all(
          color: selected ? scheme.primary : scheme.outline,
          width: 2,
        ),
      ),
      child: selected
          ? Icon(Icons.check_rounded, size: 15, color: scheme.onPrimary)
          : null,
    );
  }
}

class _MetaFooter extends StatelessWidget {
  final Diary diary;
  final Category? category;
  final bool showCategoryLabel;
  final DiaryCardSyncState syncState;

  const _MetaFooter({
    required this.diary,
    required this.category,
    required this.showCategoryLabel,
    this.syncState = DiaryCardSyncState.none,
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

    children.add(Text(TimeUtil.cardDate(diary.time), style: labelStyle));

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

    // 心情标识暂时移除，待样式优化后再加回。

    if (syncState != DiaryCardSyncState.none) {
      final isSyncing = syncState == DiaryCardSyncState.syncing;
      final color = scheme.primary;
      // 纯 icon 表达（不占文字宽度）：待同步=上传云，同步中=转圈。
      children.add(
        isSyncing
            ? SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.6, color: color),
              )
            : Icon(Icons.cloud_upload_outlined, size: 14, color: color),
      );
    }

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
      text.preview(),
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
  final DiaryCardSyncState syncState;
  final VoidCallback? onLongPress;
  final bool selecting;
  final bool selected;

  const DiaryListTile({
    super.key,
    required this.diary,
    this.category,
    this.showCategoryLabel = true,
    this.onTap,
    this.syncState = DiaryCardSyncState.none,
    this.onLongPress,
    this.selecting = false,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    return _cardShell(
      context: context,
      onTap: onTap,
      onLongPress: onLongPress,
      selecting: selecting,
      selected: selected,
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
                        showCategoryLabel: showCategoryLabel,
                        syncState: syncState),
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
  final DiaryCardSyncState syncState;
  final VoidCallback? onLongPress;
  final bool selecting;
  final bool selected;

  const DiaryGridTile({
    super.key,
    required this.diary,
    this.category,
    this.showCategoryLabel = true,
    this.onTap,
    this.syncState = DiaryCardSyncState.none,
    this.onLongPress,
    this.selecting = false,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    return _cardShell(
      context: context,
      onTap: onTap,
      onLongPress: onLongPress,
      selecting: selecting,
      selected: selected,
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
                    showCategoryLabel: showCategoryLabel,
                    syncState: syncState),
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
