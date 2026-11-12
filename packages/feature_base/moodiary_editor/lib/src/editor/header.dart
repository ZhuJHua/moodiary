part of '../moodiary_editor.dart';

Map<String, dynamic> _jsonMap(String? raw) {
  try {
    return raw == null ? {} : (jsonDecode(raw) as Map).cast<String, dynamic>();
  } catch (_) {
    return {};
  }
}

List<Map<String, dynamic>> _jsonList(Object? value) => value is List
    ? [
        for (final row in value)
          if (row is Map) row.cast<String, dynamic>(),
      ]
    : [];

class _DiaryHeader extends StatelessWidget {
  const _DiaryHeader({required this.host, this.font, required this.scale});
  final MoodiaryEditorHost host;
  final String? font;
  final double scale;
  Future<void> _popover(
    BuildContext anchor,
    String kind, {
    int tagIndex = -1,
  }) async {
    final box = anchor.findRenderObject()! as RenderBox;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final suspension = host._configuration.controller?.suspendInput();
    await host.holdSelection();
    await suspension?.ready;
    if (!anchor.mounted) return;
    if (kind == 'place') host._configuration.onLocateForPlaces?.call();
    final selected = await showGeneralDialog<VoidCallback>(
      context: anchor,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      barrierLabel: anchor.l10n.common.close,
      requestFocus: false,
      transitionDuration: Duration.zero,
      pageBuilder: (context, _, _) => CustomSingleChildLayout(
        delegate: _PopoverLayout(rect, MediaQuery.viewInsetsOf(context).bottom),
        child: ListenableBuilder(
          listenable: host,
          builder: (context, _) =>
              _MetaOptions(host: host, kind: kind, tagIndex: tagIndex),
        ),
      ),
    );
    selected?.call();
    await suspension?.resume();
  }

  @override
  Widget build(BuildContext context) {
    final config = host._configuration,
        meta = _jsonMap(config.metaJson),
        readOnly = host.readOnly,
        colors = context.theme.colors,
        labels = context.l10n.editor.content,
        metaLabels = context.l10n.editor.meta;
    final faint = Color.lerp(colors.surface, colors.onSurfaceVariant, .6)!,
        metaIcon = Color.lerp(colors.surface, colors.onSurfaceVariant, .7)!;
    final moods = _jsonList(meta['moods']),
        mood = moods.where((m) => m['value'] == meta['mood']).firstOrNull;
    final weather = meta['weather'] is Map
        ? (meta['weather'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    Widget button(
      String text,
      ValueChanged<BuildContext>? action, {
      double size = 13,
      bool emphasized = false,
      IconData? icon,
      Color? color,
      Color? iconColor,
      bool unset = false,
      String? semanticLabel,
    }) => Semantics(
      label: semanticLabel,
      button: true,
      child: Builder(
        builder: (anchor) => InkWell(
          onTap: readOnly || action == null ? null : () => action(anchor),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.zero,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 14 * scale,
                    color:
                        iconColor ?? (unset ? colors.outlineVariant : metaIcon),
                  ),
                  const SizedBox(width: 4),
                ],
                SizedBox(
                  height: size * scale * (emphasized ? 1.4 : 1.43),
                  child: Text(
                    text,
                    style: _textStyle(
                      family: font,
                      size: size * scale,
                      height: emphasized ? 1.4 : 1.43,
                      weight: emphasized ? FontWeight.w600 : FontWeight.w400,
                      color: color ?? (unset ? faint : colors.onSurfaceVariant),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final facts = <Widget>[
      if (!readOnly || weather.isNotEmpty)
        button(
          weather['text'] as String? ?? metaLabels.weather,
          (anchor) => unawaited(_popover(anchor, 'weather')),
          icon:
              components.qweatherIcon(weather['icon'] as String?) ??
              LucideIcons.cloud,
          unset: weather.isEmpty,
        ),
      if (!readOnly || meta['position'] != null)
        button(
          meta['position'] as String? ?? metaLabels.place,
          (anchor) => unawaited(_popover(anchor, 'place')),
          icon: LucideIcons.mapPin,
          unset: meta['position'] == null,
        ),
      if (!readOnly || meta['category'] != null)
        button(
          meta['category'] as String? ?? metaLabels.category,
          (_) => config.onPickCategory?.call(),
          icon: LucideIcons.folder,
          unset: meta['category'] == null,
        ),
    ];
    final tags = (meta['tags'] as List? ?? const [])
        .whereType<String>()
        .toList();
    final dateText = meta['dateText'] as String? ?? '';
    final timeText = meta['subText'] as String? ?? '';
    final countText =
        ' · ${context.l10n.diary.wordCount(count: host.characterCount ?? 0)}';
    Widget date() => button(
      dateText,
      (_) => config.onPickDate?.call(),
      size: 18,
      emphasized: true,
      color: colors.onSurface,
    );
    double textWidth(String text, double size, FontWeight weight) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: _textStyle(
            family: font,
            size: size * scale,
            weight: weight,
            color: colors.onSurface,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    // Holds the count's slot while it is computed off the first frame.
    final countWidth = readOnly
        ? textWidth(
            ' · ${context.l10n.diary.wordCount(count: host.characterCount ?? 99999)}',
            13,
            FontWeight.w400,
          )
        : 0.0;
    Widget time() => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button(timeText, (_) => config.onPickTime?.call()),
        if (readOnly)
          SizedBox(
            width: countWidth,
            child: AnimatedOpacity(
              opacity: host.characterCount == null ? 0 : 1,
              duration: const Duration(milliseconds: 120),
              child: Text(
                countText,
                style: _textStyle(
                  family: font,
                  size: 13 * scale,
                  weight: FontWeight.w400,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (meta.isNotEmpty) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (textWidth(dateText, 18, FontWeight.w600) +
                            8 +
                            textWidth(timeText, 13, FontWeight.w400) +
                            countWidth <=
                        constraints.maxWidth) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [date(), const SizedBox(width: 8), time()],
                      );
                    }
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [date(), time()],
                    );
                  },
                ),
              ),
              Builder(
                builder: (anchor) => InkWell(
                  onTap: readOnly
                      ? null
                      : () => unawaited(_popover(anchor, 'mood')),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 28),
                    padding: const EdgeInsets.fromLTRB(8, 0, 10, 0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: mood == null
                          ? colors.surfaceContainer
                          : _parseColor(
                              mood['color'] as String?,
                              colors.primary,
                            ).withValues(alpha: .18),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        components.MoodGlyph(
                          mood: models.DiaryMood.values
                              .asNameMap()[meta['mood']],
                          size: 18 * scale,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          mood?['label'] as String? ?? metaLabels.moodUnset,
                          style: _textStyle(
                            family: font,
                            size: 13 * scale,
                            weight: FontWeight.w500,
                            color: mood == null
                                ? faint
                                : Color.lerp(
                                    colors.onSurface,
                                    _parseColor(
                                      mood['color'] as String?,
                                      colors.primary,
                                    ),
                                    .55,
                                  )!,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (facts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: 13 * 1.43 * scale),
                child: Wrap(spacing: 14, children: facts),
              ),
            ),
          if (tags.isNotEmpty || !readOnly)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 24),
                child: Wrap(
                  spacing: 12,
                  children: [
                    for (final (index, tag) in tags.indexed)
                      button(
                        '#$tag',
                        (anchor) =>
                            unawaited(_popover(anchor, 'tag', tagIndex: index)),
                        color: faint,
                      ),
                    if (!readOnly)
                      button(
                        tags.isEmpty ? metaLabels.tag : '',
                        semanticLabel: metaLabels.addTag,
                        (_) => config.onAddTag?.call(),
                        icon: LucideIcons.hash,
                        color: faint,
                        iconColor: colors.outlineVariant,
                      ),
                  ],
                ),
              ),
            ),
          SizedBox(height: 20 * scale),
        ],
        if (!readOnly || host.title.text.trim().isNotEmpty)
          LayoutBuilder(
            builder: (context, constraints) => Focus(
              onKeyEvent: (_, event) {
                final composing = host.title.value.composing;
                if (composing.isValid && !composing.isCollapsed) {
                  return KeyEventResult.ignored;
                }
                final keyboard = HardwareKeyboard.instance;
                final mod =
                    defaultTargetPlatform == TargetPlatform.iOS ||
                        defaultTargetPlatform == TargetPlatform.macOS
                    ? keyboard.isMetaPressed
                    : keyboard.isControlPressed;
                if (mod && event.logicalKey == LogicalKeyboardKey.keyF) {
                  if (event is KeyDownEvent) config.controller?.openSearch();
                  return KeyEventResult.handled;
                }
                final key = event.logicalKey;
                var body =
                    key == LogicalKeyboardKey.enter ||
                    key == LogicalKeyboardKey.numpadEnter ||
                    key == LogicalKeyboardKey.tab;
                if (key == LogicalKeyboardKey.arrowDown &&
                    !keyboard.isShiftPressed &&
                    !mod &&
                    !keyboard.isAltPressed &&
                    host.title.selection.isValid) {
                  final painter = TextPainter(
                    text: TextSpan(
                      text: host.title.text,
                      style: _textStyle(
                        family: font,
                        size: 28 * scale,
                        height: 1.3,
                        weight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                    textDirection: TextDirection.ltr,
                  )..layout(maxWidth: constraints.maxWidth);
                  body =
                      painter
                          .getLineBoundary(
                            TextPosition(
                              offset: host.title.selection.extentOffset,
                            ),
                          )
                          .end ==
                      host.title.text.length;
                  painter.dispose();
                }
                if (!body || readOnly) return KeyEventResult.ignored;
                if (event is KeyDownEvent || event is KeyRepeatEvent) {
                  host.editor.setSelection(
                    ft.Selection.near(host.editor.state.doc, 0),
                  );
                  unawaited(host.focus());
                }
                return KeyEventResult.handled;
              },
              child: TextField(
                onTap: () => config.controller?.panel.showKeyboard(),
                key: const ValueKey('editor-title'),
                controller: host.title,
                focusNode: host.titleFocus,
                readOnly: readOnly,
                maxLines: null,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.text,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(
                    _titleLineBreak,
                    replacementString: ' ',
                  ),
                ],
                style: _textStyle(
                  family: font,
                  size: 28 * scale,
                  height: 1.3,
                  weight: FontWeight.w700,
                  color: colors.onSurface,
                ),
                decoration: InputDecoration(
                  filled: false,
                  fillColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  focusColor: Colors.transparent,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: readOnly ? null : labels.titlePlaceholder,
                  hintStyle: _textStyle(
                    family: font,
                    size: 28 * scale,
                    height: 1.3,
                    weight: FontWeight.w700,
                    color: colors.onSurfaceVariant.withValues(alpha: .55),
                  ),
                ),
                onSubmitted: (_) {
                  host.editor.setSelection(
                    ft.Selection.near(host.editor.state.doc, 0),
                  );
                  unawaited(host.focus());
                },
              ),
            ),
          ),
        if (!readOnly || host.title.text.trim().isNotEmpty)
          SizedBox(height: 8 * scale),
      ],
    );
  }
}

class _LinkedDiaries extends StatelessWidget {
  const _LinkedDiaries({required this.host});
  final MoodiaryEditorHost host;
  @override
  Widget build(BuildContext context) {
    final links = _jsonMap(host._configuration.linksJson),
        outgoing = _jsonList(links['outgoing']),
        incoming = _jsonList(links['incoming']);
    if (outgoing.isEmpty && incoming.isEmpty) return const SizedBox.shrink();
    final colors = context.theme.colors;
    TextStyle text(
      double size, {
      bool dim = false,
      FontWeight weight = FontWeight.w400,
    }) => _textStyle(
      color: dim ? colors.onSurfaceVariant : colors.onSurface,
      size: size * host._configuration.fontScale,
      weight: weight,
    );
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 24),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(LucideIcons.link, size: 16, color: colors.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                links['title'] as String? ?? '',
                style: text(14, weight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '${outgoing.length + incoming.length}',
                  style: text(12, dim: true),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 36,
                height: 36,
                child: IconButton(
                  tooltip: links['graphTip'] as String?,
                  onPressed: host._configuration.onOpenGraph,
                  icon: Icon(
                    LucideIcons.waypoints,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          for (final (label, items, icon) in [
            (links['outgoingLabel'], outgoing, LucideIcons.arrowUpRight),
            (links['incomingLabel'], incoming, LucideIcons.cornerDownLeft),
          ])
            if (items.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 2),
                child: Text(label as String? ?? '', style: text(12, dim: true)),
              ),
              for (final item in items)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => host._configuration.onOpenDiaryLink?.call(
                    item['id'] as String,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 4,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHigh,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            icon,
                            size: 18,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item['title'] as String? ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text(14, weight: FontWeight.w500),
                              ),
                              if (item['subtitle'] is String &&
                                  (item['subtitle'] as String).isNotEmpty)
                                Text(
                                  item['subtitle'] as String,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: text(12, dim: true),
                                ),
                            ],
                          ),
                        ),
                        Icon(
                          LucideIcons.chevronRight,
                          size: 16,
                          color: colors.onSurfaceVariant.withValues(alpha: .4),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
        ],
      ),
    );
  }
}
