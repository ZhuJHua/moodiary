import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_assistant/src/application/llm_provider_preset_controller.dart';
import 'package:moodiary_assistant/src/data/llm_preset_repository.dart';
import 'package:moodiary_assistant/src/presentation/provider_logo.dart';
import 'package:moodiary_assistant/src/routes.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_utils/moodiary_utils.dart';

class AssistantProviderPickerPage extends ConsumerStatefulWidget {
  const AssistantProviderPickerPage({super.key});

  @override
  ConsumerState<AssistantProviderPickerPage> createState() =>
      _AssistantProviderPickerPageState();
}

class _AssistantProviderPickerPageState
    extends ConsumerState<AssistantProviderPickerPage> {
  bool _refreshing = false;
  String _query = '';

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await ref.read(llmProviderPresetControllerProvider.notifier).refresh();
      if (!mounted) return;
      toast.success(message: context.l10n.llmPickerRefreshed);
    } catch (_) {
      if (mounted) toast.error(message: context.l10n.llmPickerLoadFailed);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _openCustom() async {
    final saved = await const AssistantProviderEditRoute().push<bool>(context);
    if (saved == true && mounted) Navigator.of(context).pop();
  }

  Future<void> _openPreset(LlmProviderPreset preset) async {
    final saved = await AssistantProviderEditRoute(
      presetId: preset.id,
    ).push<bool>(context);
    if (saved == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final presetsAsync = ref.watch(llmProviderPresetControllerProvider);
    final all = presetsAsync.value ?? const <LlmProviderPreset>[];
    final waiting = presetsAsync.isLoading && !presetsAsync.hasValue;
    final hasError = presetsAsync.hasError && !presetsAsync.hasValue;

    final query = _query.trim().toLowerCase();
    final presets = query.isEmpty
        ? all
        : all.where((p) => p.name.toLowerCase().contains(query)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.llmPickerTitle),
        actions: [
          IconButton(
            tooltip: l10n.llmPickerRefresh,
            onPressed: _refreshing ? null : _refresh,
            icon: _refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(LucideIcons.rotateCw),
          ),
        ],
      ),
      body: ListView(
        padding: const .all(12),
        children: [
          _CustomTile(onTap: _openCustom),
          const SizedBox(height: 12),
          if (all.isNotEmpty) ...[
            TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: l10n.llmPickerSearchHint,
                prefixIcon: const Icon(LucideIcons.search),
                filled: true,
                isDense: true,
                border: const OutlineInputBorder(
                  borderRadius: AppBorderRadius.mediumBorderRadius,
                  borderSide: .none,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (waiting)
            const Padding(
              padding: .only(top: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (hasError)
            _InlineError(onRetry: _refresh)
          else if (all.isEmpty)
            Padding(
              padding: const .only(top: 32),
              child: Center(
                child: Text(
                  l10n.llmPickerEmpty,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else ...[
            for (final p in presets)
              Padding(
                padding: const .only(bottom: 8),
                child: _PresetCard(preset: p, onTap: () => _openPreset(p)),
              ),
            _UpdatedFooter(at: LlmPresetRepository.get().cachedAt),
          ],
        ],
      ),
    );
  }
}

class _CustomTile extends StatelessWidget {
  final VoidCallback onTap;

  const _CustomTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final l10n = context.l10n;
    return Material(
      color: scheme.secondaryContainer,
      borderRadius: AppBorderRadius.mediumBorderRadius,
      clipBehavior: .antiAlias,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.onSecondaryContainer,
          foregroundColor: scheme.secondaryContainer,
          child: const Icon(LucideIcons.slidersHorizontal, size: 20),
        ),
        title: Text(
          l10n.llmPickerCustom,
          style: context.textTheme.titleMedium?.copyWith(
            color: scheme.onSecondaryContainer,
          ),
        ),
        subtitle: Text(
          l10n.llmPickerCustomDes,
          style: context.textTheme.bodySmall?.copyWith(
            color: scheme.onSecondaryContainer.withValues(alpha: 0.8),
          ),
        ),
        trailing: Icon(
          LucideIcons.chevronRight,
          color: scheme.onSecondaryContainer,
        ),
        onTap: onTap,
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  final LlmProviderPreset preset;
  final VoidCallback onTap;

  const _PresetCard({required this.preset, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final l10n = context.l10n;
    final name = preset.name;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: AppBorderRadius.mediumBorderRadius,
      clipBehavior: .antiAlias,
      child: ListTile(
        leading: ProviderLogo(logoUrl: preset.logoUrl, name: name),
        title: Text(name),
        subtitle: Text(
          l10n.llmPickerModelCount(preset.models.length),
          maxLines: 1,
          overflow: .ellipsis,
        ),
        trailing: const Icon(LucideIcons.chevronRight),
        onTap: onTap,
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final VoidCallback onRetry;

  const _InlineError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final l10n = context.l10n;
    return Padding(
      padding: const .only(top: 32),
      child: Column(
        children: [
          Icon(LucideIcons.cloudOff, size: 40, color: scheme.outline),
          const SizedBox(height: 12),
          Text(
            l10n.llmPickerLoadFailed,
            style: context.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(LucideIcons.rotateCw),
            label: Text(l10n.llmPickerRetry),
          ),
        ],
      ),
    );
  }
}

class _UpdatedFooter extends StatelessWidget {
  final int at;

  const _UpdatedFooter({required this.at});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final parts = <String>[l10n.llmPickerDataSource];
    if (at > 0) {
      final time = TimeFormat.listDateTime(.fromMillisecondsSinceEpoch(at));
      parts.add(l10n.llmPickerUpdatedAt(time));
    }
    return Padding(
      padding: const .symmetric(vertical: 12),
      child: Center(
        child: Text(
          parts.join(' · '),
          style: context.textTheme.labelSmall?.copyWith(
            color: context.colorScheme.outline,
          ),
        ),
      ),
    );
  }
}
