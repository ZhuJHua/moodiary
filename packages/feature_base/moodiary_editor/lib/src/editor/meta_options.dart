part of '../moodiary_editor.dart';

class _PopoverLayout extends SingleChildLayoutDelegate {
  const _PopoverLayout(this.anchor, this.keyboard);
  final Rect anchor;
  final double keyboard;
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        maxWidth: math.max(1, constraints.maxWidth - 16),
        maxHeight: math.max(1, constraints.maxHeight - keyboard - 16),
      );
  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final bottom = size.height - keyboard - 8;
    final y = anchor.bottom + 6 + childSize.height <= bottom
        ? anchor.bottom + 6
        : anchor.top - childSize.height - 6;
    return Offset(
      anchor.left.clamp(8, math.max(8, size.width - childSize.width - 8)),
      y.clamp(8, math.max(8, bottom - childSize.height)),
    );
  }

  @override
  bool shouldRelayout(_PopoverLayout old) =>
      old.anchor != anchor || old.keyboard != keyboard;
}

IconData _placeIcon(Object? name) => switch (name) {
  'house' => LucideIcons.house,
  'building-2' => LucideIcons.building2,
  'school' => LucideIcons.school,
  'coffee' => LucideIcons.coffee,
  'dumbbell' => LucideIcons.dumbbell,
  'trees' => LucideIcons.trees,
  'hospital' => LucideIcons.hospital,
  'plane' => LucideIcons.plane,
  _ => LucideIcons.mapPin,
};

class _MetaOptions extends StatelessWidget {
  const _MetaOptions({
    required this.host,
    required this.kind,
    this.tagIndex = -1,
  });
  final MoodiaryEditorHost host;
  final String kind;
  final int tagIndex;
  @override
  Widget build(BuildContext context) {
    final config = host._configuration,
        meta = host._meta,
        colors = context.theme.colors,
        labels = context.l10n.editor.meta;
    void choose(VoidCallback action) => Navigator.of(context).pop(action);
    Widget divider() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: SizedBox(
        height: 1,
        child: ColoredBox(color: colors.outlineVariant),
      ),
    );
    Widget item(
      String label,
      IconData icon,
      VoidCallback action, {
      bool active = false,
      bool dim = false,
      bool danger = false,
      String? trail,
    }) => Semantics(
      selected: active,
      child: Material(
        color: active ? colors.surfaceContainerHighest : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => choose(action),
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: danger
                        ? colors.error
                        : dim
                        ? colors.onSurfaceVariant
                        : colors.onSurface,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _textStyle(
                        color: danger
                            ? colors.error
                            : dim
                            ? colors.onSurfaceVariant
                            : colors.onSurface,
                        size: 14,
                        weight: active ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (trail != null)
                    Text(
                      trail,
                      style: _textStyle(
                        color: colors.onSurfaceVariant,
                        size: 12,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    Widget grid(List<Map<String, dynamic>> options, {required bool mood}) =>
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = mood ? 5 : 4,
                width = (constraints.maxWidth - (columns - 1) * 2) / columns;
            return Wrap(
              spacing: 2,
              runSpacing: 2,
              children: [
                for (final option in options)
                  Builder(
                    builder: (context) {
                      final value = option[mood ? 'value' : 'code'] as String,
                          active = mood
                              ? meta['mood'] == value
                              : (meta['weather'] as Map?)?['icon'] == value;
                      return Semantics(
                        selected: active,
                        button: true,
                        child: Material(
                          color: active
                              ? colors.surfaceContainerHighest
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => choose(
                              () => mood
                                  ? config.onChangeMood?.call(value)
                                  : config.onChangeWeather?.call(value),
                            ),
                            child: SizedBox(
                              width: width,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 2,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (mood)
                                      components.MoodGlyph(
                                        mood: models.DiaryMood.values
                                            .asNameMap()[value],
                                        size: 30,
                                      )
                                    else
                                      Icon(
                                        components.qweatherIcon(value) ??
                                            LucideIcons.cloud,
                                        size: 22,
                                        color: colors.onSurfaceVariant,
                                      ),
                                    const SizedBox(height: 4),
                                    Text(
                                      option['label'] as String? ?? '',
                                      style: _textStyle(
                                        color: active
                                            ? colors.onSurface
                                            : colors.onSurfaceVariant,
                                        size: 12,
                                        weight: active
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            );
          },
        );
    final children = <Widget>[];
    if (kind == 'mood') {
      children.addAll([
        grid(_jsonList(meta['moods']), mood: true),
        divider(),
        item(
          labels.moodClear,
          LucideIcons.circleDashed,
          () => config.onChangeMood?.call(''),
          dim: true,
        ),
      ]);
    } else if (kind == 'weather') {
      children.add(grid(_jsonList(meta['weatherOptions']), mood: false));
      if (meta['weatherAutoLabel'] != null || meta['weather'] != null) {
        children.add(divider());
      }
      if (meta['weatherAutoLabel'] is String) {
        children.add(
          item(
            meta['weatherAutoLabel'] as String,
            LucideIcons.refreshCw,
            () => config.onFetchWeather?.call(),
          ),
        );
      }
      if (meta['weather'] != null) {
        children.add(
          item(
            meta['weatherClearLabel'] as String? ?? context.l10n.common.delete,
            LucideIcons.x,
            () => config.onClearWeather?.call(),
            dim: true,
          ),
        );
      }
    } else if (kind == 'place') {
      if (meta['positionAutoLabel'] is String) {
        children.add(
          item(
            meta['positionAutoLabel'] as String,
            LucideIcons.locateFixed,
            () => config.onFetchPosition?.call(),
          ),
        );
      }
      final places = _jsonList(meta['places']);
      if (places.isNotEmpty) {
        if (children.isNotEmpty) children.add(divider());
        children.add(
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final place in places)
                    item(
                      place['name'] as String,
                      _placeIcon(place['icon']),
                      () => config.onPickPlace?.call(place['id'] as String),
                      active: place['id'] == meta['positionId'],
                      trail: place['distance'] as String?,
                    ),
                ],
              ),
            ),
          ),
        );
      }
      if (children.isNotEmpty) children.add(divider());
      children.addAll([
        item(
          meta['positionNewPlaceLabel'] as String? ?? labels.place,
          LucideIcons.plus,
          () => config.onNewPlace?.call(),
        ),
        item(
          meta['positionManageLabel'] as String? ?? labels.place,
          LucideIcons.settings,
          () => config.onManagePlaces?.call(),
          dim: true,
        ),
        if (meta['position'] != null)
          item(
            meta['positionClearLabel'] as String? ?? context.l10n.common.delete,
            LucideIcons.x,
            () => config.onClearPosition?.call(),
            dim: true,
          ),
      ]);
    } else {
      children.add(
        item(
          meta['deleteLabel'] as String? ?? context.l10n.common.delete,
          LucideIcons.trash2,
          () => config.onRemoveTag?.call(tagIndex),
          danger: true,
        ),
      );
    }
    return Semantics(
      namesRoute: true,
      label: switch (kind) {
        'mood' => labels.mood,
        'weather' => labels.weather,
        'place' => labels.place,
        _ => labels.removeTag,
      },
      child: Material(
        key: ValueKey('meta-$kind'),
        color: colors.surfaceContainerHigh,
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: kind == 'mood'
              ? 300
              : kind == 'weather'
              ? 288
              : 240,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(6),
            child: Column(mainAxisSize: MainAxisSize.min, children: children),
          ),
        ),
      ),
    );
  }
}
