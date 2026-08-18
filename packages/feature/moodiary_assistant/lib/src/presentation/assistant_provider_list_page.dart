import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_assistant/src/presentation/provider_logo.dart';
import 'package:moodiary_assistant/src/routes.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:mui/mui.dart';

class AssistantProviderListPage extends ConsumerStatefulWidget {
  const AssistantProviderListPage({super.key});

  @override
  ConsumerState<AssistantProviderListPage> createState() =>
      _AssistantProviderListPageState();
}

class _AssistantProviderListPageState
    extends ConsumerState<AssistantProviderListPage> {
  LlmProviderRepository get _repo => .get();

  List<LlmProvider> _providers = const [];
  Set<String> _withKey = const {};
  String _activeId = '';
  bool _loaded = false;
  StreamSubscription<void>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = _repo.providerEvents.listen((_) => _load());
    _load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final providers = await _repo.getAllProviders();
    final withKey = <String>{};
    for (final p in providers) {
      final key = await _repo.getKey(p.id);
      if (key != null && key.isNotEmpty) withKey.add(p.id);
    }
    if (!mounted) return;
    setState(() {
      _providers = providers;
      _withKey = withKey;
      _activeId = MoodiaryKVs.assistantActiveProviderId.get() ?? '';
      _loaded = true;
    });
  }

  /// 选中 = 设为默认（新会话的起始模型）。已开始的会话不受影响 ——
  /// 会话在首条消息落库时就把模型定格进 `ChatSession` 了。
  Future<void> _setDefault(LlmProvider provider) async {
    MoodiaryKVs.assistantActiveProviderId.set(provider.id);
    if (mounted) setState(() => _activeId = provider.id);
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;
    final next = [..._providers];
    next.insert(newIndex, next.removeAt(oldIndex));
    // 先就地更新再落库：等 Isar 回来才动列表的话，手指抬起到重排之间会闪一帧旧序。
    setState(() => _providers = next);
    HapticFeedback.mediumImpact();
    await _repo.reorderProviders([for (final p in next) p.id]);
  }

  Future<void> _delete(LlmProvider provider) async {
    final l10n = context.l10n;
    final ok = await MAlert.confirm(
      context,
      title: l10n.assistant.modelProviderDeleteTitle,
      message: l10n.assistant.modelProviderDeleteContent(name: provider.name),
      confirmLabel: l10n.common.delete,
      isDestructive: true,
    );
    if (!ok) return;
    await _repo.deleteProvider(provider.id);
    toast.success(message: l10n.assistant.modelProviderDeleted);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.assistant.modelProviderTitle)),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'assistantProviderFab',
        onPressed: () => const AssistantProviderPickerRoute().push(context),
        icon: const Icon(LucideIcons.plus),
        label: Text(l10n.assistant.modelProviderAdd),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _providers.isEmpty
          ? const _EmptyState()
          : ReorderableListView.builder(
              padding: const .fromLTRB(0, 8, 0, 88),
              buildDefaultDragHandles: false,
              proxyDecorator: (child, index, animation) => AnimatedBuilder(
                animation: animation,
                builder: (context, _) {
                  final t = Curves.easeOut.transform(animation.value);
                  return Transform.scale(
                    scale: 1 + 0.03 * t,
                    child: Material(
                      color: Colors.transparent,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: .circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: context.theme.colors.shadow.withValues(
                                alpha: 0.12 * t,
                              ),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: child,
                      ),
                    ),
                  );
                },
                child: child,
              ),
              onReorderItem: _onReorder,
              itemCount: _providers.length,
              itemBuilder: (context, index) {
                final p = _providers[index];
                return ReorderableDelayedDragStartListener(
                  key: ValueKey(p.id),
                  index: index,
                  child: _ProviderCard(
                    provider: p,
                    isDefault: p.id == _activeId,
                    hasKey: _withKey.contains(p.id),
                    dragIndex: index,
                    onTap: () => _setDefault(p),
                    onEdit: () =>
                        AssistantProviderEditRoute(id: p.id).push(context),
                    onDelete: () => _delete(p),
                  ),
                );
              },
            ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  final LlmProvider provider;
  final bool isDefault;
  final bool hasKey;
  final int dragIndex;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProviderCard({
    required this.provider,
    required this.isDefault,
    required this.hasKey,
    required this.dragIndex,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    final l10n = context.l10n;
    return Padding(
      padding: const .fromLTRB(12, 4, 12, 4),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: AppBorderRadius.mediumBorderRadius,
        clipBehavior: .antiAlias,
        child: MInkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: AppBorderRadius.mediumBorderRadius,
              border: .all(color: scheme.outlineVariant, width: 1),
            ),
            padding: const .fromLTRB(12, 12, 4, 12),
            child: Row(
              crossAxisAlignment: .center,
              children: [
                Padding(
                  padding: const .only(right: 12),
                  child: ProviderLogo(
                    logoUrl: ProviderLogo.urlOf(provider.presetId),
                    name: provider.name,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    mainAxisSize: .min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              provider.name,
                              maxLines: 1,
                              overflow: .ellipsis,
                              style: context
                                  .theme
                                  .typography
                                  .titleMedium
                                  .onSurface,
                            ),
                          ),
                          if (isDefault) ...[
                            const SizedBox(width: 8),
                            _Badge(
                              text: l10n.assistant.modelProviderDefault,
                              color: scheme.secondaryContainer,
                              onColor: scheme.onSecondaryContainer,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        provider.defaultModel,
                        maxLines: 1,
                        overflow: .ellipsis,
                        style:
                            context.theme.typography.bodySmall.onSurfaceVariant,
                      ),
                      // 只与「是否配置密钥」有关（和选中无关）→ 不影响选中时的尺寸。
                      if (!hasKey) ...[
                        const SizedBox(height: 8),
                        _Badge(
                          text: l10n.assistant.modelProviderNoKey,
                          color: scheme.errorContainer,
                          onColor: scheme.onErrorContainer,
                        ),
                      ],
                    ],
                  ),
                ),
                ReorderableDragStartListener(
                  index: dragIndex,
                  child: Padding(
                    padding: const .symmetric(horizontal: 4, vertical: 12),
                    child: Icon(
                      LucideIcons.gripVertical,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                MMenuButton<String>(
                  tooltip: l10n.common.more,
                  onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
                  entries: [
                    MMenuEntry(
                      value: 'edit',
                      label: l10n.assistant.diaryEdit,
                      icon: LucideIcons.squarePen,
                    ),
                    MMenuEntry(
                      value: 'delete',
                      label: l10n.common.delete,
                      icon: LucideIcons.trash2,
                      isDestructive: true,
                    ),
                  ],
                  child: Padding(
                    padding: const .all(12),
                    child: Icon(
                      LucideIcons.ellipsisVertical,
                      color: scheme.onSurfaceVariant,
                    ),
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

class _Badge extends StatelessWidget {
  final String text;
  final Color? color;
  final Color? onColor;

  const _Badge({required this.text, this.color, this.onColor});

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    final bg = color ?? scheme.secondaryContainer;
    final on = onColor ?? scheme.onSecondaryContainer;
    return Container(
      padding: const .symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: .circular(8)),
      child: Text(
        text,
        style: context.theme.typography.labelSmall.onSurface.copyWith(
          color: on,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    final l10n = context.l10n;
    return Center(
      child: Column(
        mainAxisSize: .min,
        children: [
          Icon(LucideIcons.cloudOff, size: 48, color: scheme.outline),
          const SizedBox(height: 12),
          Text(
            l10n.assistant.modelProviderEmptyTitle,
            style: context.theme.typography.titleMedium.onSurface,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.assistant.modelProviderEmptyHint,
            style: context.theme.typography.bodySmall.outline,
          ),
        ],
      ),
    );
  }
}
