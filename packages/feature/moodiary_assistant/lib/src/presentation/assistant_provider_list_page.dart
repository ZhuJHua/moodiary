import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_assistant/src/presentation/provider_logo.dart';
import 'package:moodiary_assistant/src/routes.dart';

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

  Future<void> _setActive(LlmProvider provider) async {
    await MoodiaryKVs.assistantActiveProviderId.set(provider.id);
    if (mounted) setState(() => _activeId = provider.id);
  }

  Future<void> _delete(LlmProvider provider) async {
    final l10n = context.l10n;
    final ok = await showMoodiaryConfirm(
      context,
      title: l10n.modelProviderDeleteTitle,
      message: l10n.modelProviderDeleteContent(provider.name),
      confirmLabel: l10n.diaryDelete,
      isDestructive: true,
    );
    if (!ok) return;
    await _repo.deleteProvider(provider.id);
    toast.success(message: l10n.modelProviderDeleted);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.modelProviderTitle)),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'assistantProviderFab',
        onPressed: () => const AssistantProviderPickerRoute().push(context),
        icon: const Icon(LucideIcons.plus),
        label: Text(l10n.modelProviderAdd),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _providers.isEmpty
          ? const _EmptyState()
          : ListView.builder(
              padding: const .fromLTRB(0, 8, 0, 88),
              itemCount: _providers.length,
              itemBuilder: (context, index) {
                final p = _providers[index];
                return _ProviderCard(
                  provider: p,
                  isActive: p.id == _activeId,
                  hasKey: _withKey.contains(p.id),
                  onTap: () => _setActive(p),
                  onEdit: () =>
                      AssistantProviderEditRoute(id: p.id).push(context),
                  onDelete: () => _delete(p),
                );
              },
            ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  final LlmProvider provider;
  final bool isActive;
  final bool hasKey;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProviderCard({
    required this.provider,
    required this.isActive,
    required this.hasKey,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final l10n = context.l10n;
    return Padding(
      padding: const .fromLTRB(12, 4, 12, 4),
      child: Material(
        color: isActive
            ? scheme.primaryContainer.withValues(alpha: 0.4)
            : scheme.surfaceContainerLow,
        borderRadius: AppBorderRadius.mediumBorderRadius,
        clipBehavior: .antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: AppBorderRadius.mediumBorderRadius,
              border: .all(
                // 边框宽度恒定（不随选中变化），只变色，避免选中后卡片尺寸抖动。
                color: isActive ? scheme.primary : scheme.outlineVariant,
                width: 1,
              ),
            ),
            padding: const .fromLTRB(12, 12, 4, 12),
            child: Row(
              crossAxisAlignment: .center,
              children: [
                Padding(
                  padding: const .only(right: 12),
                  // 选中态用 logo 角标表达（Stack 叠加，不占布局）→ 选中不改卡片尺寸。
                  child: Stack(
                    clipBehavior: .none,
                    children: [
                      ProviderLogo(
                        logoUrl: ProviderLogo.urlOf(provider.providerId),
                        name: provider.name,
                      ),
                      if (isActive)
                        Positioned(
                          right: -3,
                          bottom: -3,
                          child: Container(
                            padding: const .all(2),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              shape: .circle,
                              border: .all(
                                color: scheme.primaryContainer,
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              LucideIcons.check,
                              size: 11,
                              color: scheme.onPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    mainAxisSize: .min,
                    children: [
                      Text(
                        provider.name,
                        maxLines: 1,
                        overflow: .ellipsis,
                        style: context.textTheme.titleMedium?.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        provider.model,
                        maxLines: 1,
                        overflow: .ellipsis,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      // 只与「是否配置密钥」有关（和选中无关）→ 不影响选中时的尺寸。
                      if (!hasKey) ...[
                        const SizedBox(height: 8),
                        _Badge(
                          text: l10n.modelProviderNoKey,
                          color: scheme.errorContainer,
                        ),
                      ],
                    ],
                  ),
                ),
                MoodiaryMenuButton<String>(
                  tooltip: l10n.more,
                  onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
                  entries: [
                    MoodiaryMenuEntry(
                      value: 'edit',
                      label: l10n.diaryEdit,
                      icon: LucideIcons.squarePen,
                    ),
                    MoodiaryMenuEntry(
                      value: 'delete',
                      label: l10n.diaryDelete,
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

  const _Badge({required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final bg = color ?? scheme.secondaryContainer;
    return Container(
      padding: const .symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: .circular(8)),
      child: Text(text, style: context.textTheme.labelSmall),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final l10n = context.l10n;
    return Center(
      child: Column(
        mainAxisSize: .min,
        children: [
          Icon(LucideIcons.cloudOff, size: 48, color: scheme.outline),
          const SizedBox(height: 12),
          Text(
            l10n.modelProviderEmptyTitle,
            style: context.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.modelProviderEmptyHint,
            style: context.textTheme.bodySmall?.copyWith(color: scheme.outline),
          ),
        ],
      ),
    );
  }
}
