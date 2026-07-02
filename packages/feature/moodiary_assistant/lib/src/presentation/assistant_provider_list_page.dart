import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
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
  LlmProviderRepository get _repo => LlmProviderRepository.get();

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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.modelProviderDeleteTitle),
        content: Text(l10n.modelProviderDeleteContent(provider.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.diaryDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _repo.deleteProvider(provider.id);
    toast.success(message: l10n.modelProviderDeleted);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.modelProviderTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => const AssistantProviderPickerRoute().push(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.modelProviderAdd),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _providers.isEmpty
          ? const _EmptyState()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 88),
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
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Material(
        color: isActive
            ? scheme.primaryContainer.withValues(alpha: 0.4)
            : scheme.surfaceContainerLow,
        borderRadius: AppBorderRadius.mediumBorderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: AppBorderRadius.mediumBorderRadius,
              border: Border.all(
                color: isActive ? scheme.primary : scheme.outlineVariant,
                width: isActive ? 1.5 : 1,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: ProviderLogo(
                    logoUrl: ProviderLogo.urlOf(provider.providerId),
                    name: provider.name,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (isActive) ...[
                            Icon(
                              Icons.check_circle_rounded,
                              size: 18,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: Text(
                              provider.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.textTheme.titleMedium?.copyWith(
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (isActive || !hasKey) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (isActive)
                              _Badge(
                                text: l10n.modelProviderActive,
                                color: scheme.primaryContainer,
                              ),
                            if (!hasKey)
                              _Badge(
                                text: l10n.modelProviderNoKey,
                                color: scheme.errorContainer,
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        provider.model,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit', child: Text(l10n.diaryEdit)),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(l10n.diaryDelete),
                    ),
                  ],
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 48, color: scheme.outline),
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
