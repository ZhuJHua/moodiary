import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary/feature/assistant/application/llm_provider_preset_controller.dart';
import 'package:moodiary/feature/assistant/data/llm_preset_repository.dart';
import 'package:moodiary_l10n/moodiary_l10n.dart';
import 'package:moodiary/app/router/router.dart';

/// 选中后用 `pushReplacement` 进编辑页，使保存返回时回到供应商列表而非本页。
class AssistantProviderPickerPage extends ConsumerStatefulWidget {
  const AssistantProviderPickerPage({super.key});

  @override
  ConsumerState<AssistantProviderPickerPage> createState() =>
      _AssistantProviderPickerPageState();
}

class _AssistantProviderPickerPageState
    extends ConsumerState<AssistantProviderPickerPage> {
  bool _refreshing = false;

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

  void _openCustom() =>
      const AssistantProviderEditRoute().pushReplacement(context);

  void _openPreset(LlmProviderPreset preset) =>
      AssistantProviderEditRoute(presetId: preset.id).pushReplacement(context);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    final presetsAsync = ref.watch(llmProviderPresetControllerProvider);
    final presets = presetsAsync.value ?? const <LlmProviderPreset>[];
    final waiting = presetsAsync.isLoading && !presetsAsync.hasValue;
    final hasError = presetsAsync.hasError && !presetsAsync.hasValue;

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
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _CustomTile(onTap: _openCustom),
          const SizedBox(height: 12),
          if (waiting)
            const Padding(
              padding: EdgeInsets.only(top: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (hasError)
            _InlineError(onRetry: _refresh)
          else if (presets.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 32),
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
                padding: const EdgeInsets.only(bottom: 8),
                child: _PresetCard(
                  preset: p,
                  lang: lang,
                  onTap: () => _openPreset(p),
                ),
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
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.onSecondaryContainer,
          foregroundColor: scheme.secondaryContainer,
          child: const Icon(Icons.tune_rounded, size: 20),
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
          Icons.chevron_right_rounded,
          color: scheme.onSecondaryContainer,
        ),
        onTap: onTap,
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  final LlmProviderPreset preset;
  final String lang;
  final VoidCallback onTap;

  const _PresetCard({
    required this.preset,
    required this.lang,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final l10n = context.l10n;
    final name = preset.localizedName(lang);
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '#';
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: AppBorderRadius.mediumBorderRadius,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimaryContainer,
          child: Text(initial),
        ),
        title: Text(name),
        subtitle: Text(
          '${preset.protocol.label} · ${l10n.llmPickerModelCount(preset.models.length)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
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
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        children: [
          Icon(Icons.cloud_off_rounded, size: 40, color: scheme.outline),
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
            icon: const Icon(Icons.refresh_rounded),
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
    if (at <= 0) return const SizedBox.shrink();
    final time = DateFormat.yMd().add_Hm().format(
      DateTime.fromMillisecondsSinceEpoch(at),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(
          context.l10n.llmPickerUpdatedAt(time),
          style: context.textTheme.labelSmall?.copyWith(
            color: context.colorScheme.outline,
          ),
        ),
      ),
    );
  }
}
