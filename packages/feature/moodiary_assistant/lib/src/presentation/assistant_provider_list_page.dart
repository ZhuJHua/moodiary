import 'dart:async';

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

  Future<void> _setActive(LlmProvider provider) async {
    MoodiaryKVs.assistantActiveProviderId.set(provider.id);
    if (mounted) setState(() => _activeId = provider.id);
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
    final scheme = context.theme.colors;
    final l10n = context.l10n;
    return Padding(
      padding: const .fromLTRB(12, 4, 12, 4),
      child: Material(
        color: isActive
            ? scheme.primaryContainer.withValues(alpha: 0.4)
            : scheme.surfaceContainerLow,
        borderRadius: AppBorderRadius.mediumBorderRadius,
        clipBehavior: .antiAlias,
        child: MInkWell(
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
                        style: context.theme.typography.titleMedium.onSurface,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        provider.model,
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
