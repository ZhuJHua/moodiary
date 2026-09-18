library;

import 'package:moodiary_assistant/src/data/assistant_defs.dart';
import 'package:moodiary_assistant/src/data/model_resolver.dart';
import 'package:moodiary_assistant/src/presentation/catalog_error.dart';
import 'package:moodiary_assistant/src/presentation/provider_logo.dart';
import 'package:moodiary_assistant/src/presentation/reasoning_label.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_utils/moodiary_utils.dart';
import 'package:mui/mui.dart';

typedef GlobalModelChoice = ({
  String providerId,
  String modelId,
  String? level,
});

typedef ProviderModels = ({
  LlmProvider provider,
  List<ModelOption> options,
  bool hasKey,
});

Future<String?> showModelPicker(
  BuildContext context, {
  required String providerName,
  required List<ModelOption> options,
  required String modelId,
}) {
  return MSheet.show<String>(
    context,
    builder: (sheetContext) => _ModelPickerBody(
      providerName: providerName,
      options: options,
      modelId: modelId,
    ),
  );
}

Future<GlobalModelChoice?> showGlobalModelPicker(
  BuildContext context, {
  required List<ProviderModels> groups,
  required String providerId,
  required String modelId,
  required String? level,
  required int catalogUpdatedAt,
  required Future<List<ProviderModels>> Function() onDownloadCatalog,
  required VoidCallback onManageProviders,
  required ValueChanged<LlmProvider> onFillKey,
}) {
  return MSheet.show<GlobalModelChoice>(
    context,
    builder: (sheetContext) => _GlobalModelPickerBody(
      groups: groups,
      providerId: providerId,
      modelId: modelId,
      level: level,
      catalogUpdatedAt: catalogUpdatedAt,
      onDownloadCatalog: onDownloadCatalog,
      onManageProviders: onManageProviders,
      onFillKey: onFillKey,
    ),
  );
}

class _GlobalModelPickerBody extends StatefulWidget {
  final List<ProviderModels> groups;
  final String providerId;
  final String modelId;
  final String? level;
  final int catalogUpdatedAt;
  final Future<List<ProviderModels>> Function() onDownloadCatalog;
  final VoidCallback onManageProviders;
  final ValueChanged<LlmProvider> onFillKey;

  const _GlobalModelPickerBody({
    required this.groups,
    required this.providerId,
    required this.modelId,
    required this.level,
    required this.catalogUpdatedAt,
    required this.onDownloadCatalog,
    required this.onManageProviders,
    required this.onFillKey,
  });

  @override
  State<_GlobalModelPickerBody> createState() => _GlobalModelPickerBodyState();
}

typedef _Row = ({
  LlmProvider provider,
  bool hasKey,
  ModelOption? option,
  bool missing,
});

class _GlobalModelPickerBodyState extends State<_GlobalModelPickerBody> {
  final _search = TextEditingController();
  final _currentKey = GlobalKey();

  late List<ProviderModels> _groups = widget.groups;
  late int _catalogUpdatedAt = widget.catalogUpdatedAt;
  late String _providerId = widget.providerId;
  late String _modelId = widget.modelId;
  late String? _level = widget.level;
  String _query = '';
  bool _downloading = false;
  String? _downloadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _currentKey.currentContext;
      if (context != null && mounted) {
        Scrollable.ensureVisible(context, alignment: 0.2);
      }
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _catalogMissing =>
      _groups.any((g) => g.provider.isPreset && g.options.isEmpty);

  int get _totalOptions {
    var n = 0;
    for (final g in _groups) {
      n += g.options.length;
    }
    return n;
  }

  ModelOption? _optionOf(String providerId, String modelId) {
    for (final g in _groups) {
      if (g.provider.id != providerId) continue;
      for (final o in g.options) {
        if (o.id == modelId) return o;
      }
    }
    return null;
  }

  List<_Row> get _rows {
    final q = _query.trim().toLowerCase();
    bool matches(ModelOption o) =>
        q.isEmpty ||
        o.id.toLowerCase().contains(q) ||
        o.label.toLowerCase().contains(q);
    final rows = <_Row>[];
    for (final g in _groups) {
      final isCurrentProvider = g.provider.id == widget.providerId;
      final matched = [
        for (final o in g.options)
          if (matches(o)) o,
      ];
      final pinnedMissing =
          isCurrentProvider &&
          widget.modelId.isNotEmpty &&
          _optionOf(widget.providerId, widget.modelId) == null &&
          matches(
            ModelOption(
              id: widget.modelId,
              label: widget.modelId,
              preset: null,
              levels: const [],
            ),
          );
      if (matched.isEmpty && !pinnedMissing && q.isNotEmpty) continue;
      rows.add((
        provider: g.provider,
        hasKey: g.hasKey,
        option: null,
        missing: false,
      ));
      if (pinnedMissing) {
        rows.add((
          provider: g.provider,
          hasKey: g.hasKey,
          option: ModelOption(
            id: widget.modelId,
            label: widget.modelId,
            preset: null,
            levels: const [],
          ),
          missing: true,
        ));
      }
      for (final o in matched) {
        rows.add((
          provider: g.provider,
          hasKey: g.hasKey,
          option: o,
          missing: false,
        ));
      }
    }
    return rows;
  }

  void _pick(LlmProvider provider, ModelOption option) {
    setState(() {
      _providerId = provider.id;
      _modelId = option.id;
    });
  }

  void _pickLevel(String? level) {
    setState(() => _level = level);
  }

  Future<void> _download() async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
      _downloadError = null;
    });
    final l10n = context.l10n;
    try {
      final groups = await widget.onDownloadCatalog();
      if (!mounted) return;
      setState(() {
        _groups = groups;
        _catalogUpdatedAt = DateTime.now().millisecondsSinceEpoch;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _downloadError = assistantNetworkErrorText(e, l10n));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _leave(VoidCallback then) {
    Navigator.of(context).pop();
    then();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final typography = context.theme.typography;
    final rows = _rows;
    final levels = _optionOf(_providerId, _modelId)?.levels ?? const <String>[];

    return MSheetScaffold<GlobalModelChoice>(
      title: l10n.assistant.modelProviderPickModel,
      icon: LucideIcons.cpu,
      actions: [
        MAction(label: l10n.common.cancel),
        MAction(
          label: l10n.common.ok,
          isPrimary: true,
          value: (providerId: _providerId, modelId: _modelId, level: _level),
        ),
      ],
      child: Column(
        crossAxisAlignment: .stretch,
        mainAxisSize: .min,
        children: [
          if (_totalOptions > 6)
            Padding(
              padding: const .only(bottom: 8),
              child: MField(
                controller: _search,
                hintText: l10n.assistant.modelProviderSearchModelHint,
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
          if (_catalogMissing)
            _CatalogRow(
              busy: _downloading,
              error: _downloadError,
              onDownload: _download,
            ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.62,
            ),
            child: rows.isEmpty
                ? Padding(
                    padding: const .symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        l10n.assistant.modelProviderNoModelMatch,
                        style: typography.bodySmall.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView(
                    shrinkWrap: true,
                    children: [
                      for (final row in rows)
                        if (row.option case final option?)
                          _ModelTile(
                            key:
                                option.id == widget.modelId &&
                                    row.provider.id == widget.providerId
                                ? _currentKey
                                : null,
                            option: option,
                            selected:
                                row.provider.id == _providerId &&
                                option.id == _modelId,
                            missing: row.missing,
                            onTap: row.hasKey
                                ? () => _pick(row.provider, option)
                                : null,
                            below:
                                row.provider.id == _providerId &&
                                    option.id == _modelId &&
                                    levels.isNotEmpty
                                ? _LevelChips(
                                    levels: levels,
                                    stored: _level,
                                    onChanged: _pickLevel,
                                  )
                                : null,
                          )
                        else
                          _ProviderHeader(
                            provider: row.provider,
                            hasKey: row.hasKey,
                            empty: _groups
                                .firstWhere(
                                  (g) => g.provider.id == row.provider.id,
                                )
                                .options
                                .isEmpty,
                            onFillKey: () =>
                                _leave(() => widget.onFillKey(row.provider)),
                          ),
                    ],
                  ),
          ),
          Padding(
            padding: const .only(top: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _catalogUpdatedAt > 0
                        ? l10n.assistant.modelCatalogUpdatedAt(
                            time: TimeFormat.listDateTime(
                              DateTime.fromMillisecondsSinceEpoch(
                                _catalogUpdatedAt,
                              ),
                            ),
                          )
                        : l10n.assistant.llmPickerDataSource,
                    maxLines: 1,
                    overflow: .ellipsis,
                    style: typography.labelSmall.onSurfaceVariant,
                  ),
                ),
                MInkWell.fade(
                  onTap: () => _leave(widget.onManageProviders),
                  child: Padding(
                    padding: const .symmetric(horizontal: 8, vertical: 6),
                    child: Text(
                      '${l10n.assistant.modelProviderManage} →',
                      style: typography.labelMedium.emphasized.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogRow extends StatelessWidget {
  final bool busy;
  final String? error;
  final VoidCallback onDownload;

  const _CatalogRow({
    required this.busy,
    required this.error,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.theme.colors;
    final typography = context.theme.typography;
    return Padding(
      padding: const .only(bottom: 8),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: MuiRadius.md,
        clipBehavior: .antiAlias,
        child: MInkWell(
          onTap: busy ? null : onDownload,
          child: Padding(
            padding: const .symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                if (busy)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.onSurfaceVariant,
                    ),
                  )
                else
                  Icon(
                    LucideIcons.cloudDownload,
                    size: 18,
                    color: scheme.primary,
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    mainAxisSize: .min,
                    children: [
                      Text(
                        l10n.assistant.modelCatalogDownload,
                        style: typography.labelLarge.emphasized.onSurface,
                      ),
                      Text(
                        error ?? l10n.assistant.modelCatalogMissing,
                        style: error == null
                            ? typography.bodySmall.onSurfaceVariant
                            : typography.bodySmall.error,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProviderHeader extends StatelessWidget {
  final LlmProvider provider;
  final bool hasKey;
  final bool empty;
  final VoidCallback onFillKey;

  const _ProviderHeader({
    required this.provider,
    required this.hasKey,
    required this.empty,
    required this.onFillKey,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final typography = context.theme.typography;
    return Padding(
      padding: const .only(top: 8, bottom: 6, left: 2),
      child: Row(
        children: [
          ProviderLogo(
            logoUrl: ProviderLogo.urlOf(provider.presetId),
            name: provider.name,
            size: 20,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              provider.name,
              maxLines: 1,
              overflow: .ellipsis,
              style: typography.labelLarge.emphasized.onSurfaceVariant,
            ),
          ),
          if (empty && !provider.isPreset) ...[
            const SizedBox(width: 6),
            Text(
              l10n.assistant.modelListEmpty,
              style: typography.labelSmall.onSurfaceVariant,
            ),
          ],
          if (!hasKey) ...[
            const SizedBox(width: 6),
            _Badge(
              icon: LucideIcons.keyRound,
              text: l10n.assistant.modelProviderNoKey,
            ),
            MInkWell.fade(
              onTap: onFillKey,
              child: Padding(
                padding: const .symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  '${l10n.assistant.modelProviderFillKey} →',
                  style: typography.labelSmall.emphasized.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LevelChips extends StatelessWidget {
  final List<String> levels;
  final String? stored;
  final ValueChanged<String?> onChanged;

  const _LevelChips({
    required this.levels,
    required this.stored,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final effective = effectiveReasoningLevel(stored: stored, levels: levels);
    final off = stored == reasoningOffValue;
    return Padding(
      padding: const .only(top: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final level in levels)
            _LevelChip(
              label: reasoningLevelLabel(level, l10n),
              selected: !off && level == effective,
              onTap: () => onChanged(level),
            ),
          _LevelChip(
            label: l10n.assistant.reasoningOff,
            selected: off,
            onTap: () => onChanged(reasoningOffValue),
          ),
        ],
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LevelChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    final typography = context.theme.typography;
    return Material(
      color: selected ? scheme.primary : scheme.surfaceContainerHighest,
      shape: const StadiumBorder(),
      clipBehavior: .antiAlias,
      child: MInkWell(
        onTap: onTap,
        child: Padding(
          padding: const .symmetric(horizontal: 10, vertical: 5),
          child: Text(
            label,
            style: selected
                ? typography.labelMedium.emphasized.onPrimary
                : typography.labelMedium.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _ModelPickerBody extends StatefulWidget {
  final String providerName;
  final List<ModelOption> options;
  final String modelId;

  const _ModelPickerBody({
    required this.providerName,
    required this.options,
    required this.modelId,
  });

  @override
  State<_ModelPickerBody> createState() => _ModelPickerBodyState();
}

class _ModelPickerBodyState extends State<_ModelPickerBody> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<ModelOption> get _visible {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.options;
    return [
      for (final o in widget.options)
        if (o.id.toLowerCase().contains(q) || o.label.toLowerCase().contains(q))
          o,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final typography = context.theme.typography;
    final visible = _visible;

    return MSheetScaffold<String>(
      title: l10n.assistant.modelProviderPickModel,
      subtitle: widget.providerName,
      icon: LucideIcons.cpu,
      actions: [MAction(label: l10n.common.cancel)],
      child: Column(
        crossAxisAlignment: .stretch,
        mainAxisSize: .min,
        children: [
          if (widget.options.length > 6)
            Padding(
              padding: const .only(bottom: 8),
              child: MField(
                controller: _search,
                hintText: l10n.assistant.modelProviderSearchModelHint,
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.62,
            ),
            child: visible.isEmpty
                ? Padding(
                    padding: const .symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        l10n.assistant.modelProviderNoModelMatch,
                        style: typography.bodySmall.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final option = visible[index];
                      return _ModelTile(
                        option: option,
                        selected: option.id == widget.modelId,
                        missing: false,
                        onTap: () => Navigator.of(context).pop(option.id),
                        below: null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ModelTile extends StatelessWidget {
  final ModelOption option;
  final bool selected;
  final bool missing;
  final VoidCallback? onTap;
  final Widget? below;

  const _ModelTile({
    super.key,
    required this.option,
    required this.selected,
    required this.missing,
    required this.onTap,
    required this.below,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    final typography = context.theme.typography;
    final l10n = context.l10n;
    final preset = option.preset;
    final badges = <Widget>[
      if (preset != null) ...[
        if (preset.toolCall)
          _Badge(icon: LucideIcons.wrench, text: l10n.assistant.tool),
        if (preset.reasoning)
          _Badge(
            icon: LucideIcons.brain,
            text: l10n.assistant.modelProviderBadgeReasoning,
          ),
        if (preset.acceptsImage)
          _Badge(
            icon: LucideIcons.image,
            text: l10n.assistant.modelProviderBadgeVision,
          ),
        if (_formatContext(preset.contextLimit) case final ctx?)
          _Badge(icon: LucideIcons.chevronsUpDown, text: ctx),
        if (_formatPrice(preset.inputCost, preset.outputCost) case final price?)
          _Badge(icon: LucideIcons.banknote, text: price),
      ],
    ];

    return Padding(
      padding: const .only(bottom: 6),
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1,
        child: Material(
          color: selected
              ? scheme.secondaryContainer
              : scheme.surfaceContainerLow,
          borderRadius: MuiRadius.md,
          clipBehavior: .antiAlias,
          child: MInkWell(
            onTap: onTap,
            child: Padding(
              padding: const .symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: .start,
                mainAxisSize: .min,
                children: [
                  Row(
                    crossAxisAlignment: .start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: .start,
                          mainAxisSize: .min,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    option.label,
                                    maxLines: 1,
                                    overflow: .ellipsis,
                                    style: selected
                                        ? typography
                                              .titleSmall
                                              .emphasized
                                              .onSecondaryContainer
                                        : typography.titleSmall.onSurface,
                                  ),
                                ),
                                if (missing) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    l10n.assistant.modelNotInCatalog,
                                    style: typography.labelSmall.error,
                                  ),
                                ] else if (option.deprecated) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    l10n.assistant.modelDeprecated,
                                    style:
                                        typography.labelSmall.onSurfaceVariant,
                                  ),
                                ],
                              ],
                            ),
                            if (option.label != option.id)
                              Text(
                                option.id,
                                maxLines: 1,
                                overflow: .ellipsis,
                                style: typography.labelSmall.onSurfaceVariant,
                              ),
                            if (badges.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Wrap(spacing: 6, runSpacing: 4, children: badges),
                            ],
                          ],
                        ),
                      ),
                      if (selected)
                        Padding(
                          padding: const .only(left: 8, top: 2),
                          child: Icon(
                            LucideIcons.circleCheck,
                            size: 18,
                            color: scheme.onSecondaryContainer,
                          ),
                        ),
                    ],
                  ),
                  ?below,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Badge({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    return Container(
      padding: const .symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: .circular(6),
      ),
      child: Row(
        mainAxisSize: .min,
        children: [
          Icon(icon, size: 13, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            text,
            style: context.theme.typography.labelSmall.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

String? _formatContext(int? n) {
  if (n == null || n <= 0) return null;
  if (n >= 1000000) {
    final m = n / 1000000;
    return '${m == m.roundToDouble() ? m.toStringAsFixed(0) : m.toStringAsFixed(1)}M';
  }
  if (n >= 1000) return '${(n / 1000).round()}K';
  return '$n';
}

String? _formatPrice(num? input, num? output) {
  if (input == null && output == null) return null;
  String f(num? v) => v == null ? '?' : '\$${_trimNum(v)}';
  return '${f(input)}/${f(output)}';
}

String _trimNum(num v) {
  var s = v.toStringAsFixed(2);
  if (s.contains('.')) {
    s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
  return s;
}
