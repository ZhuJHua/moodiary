import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:moodiary_assistant/moodiary_assistant.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:moodiary_ml/moodiary_ml.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:mui/mui.dart';

class ServicesPage extends ConsumerWidget {
  const ServicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.app.services)),
      body: Padding(
        padding: const .symmetric(horizontal: 8.0),
        child: CustomScrollView(
          slivers: [
            const _AiSection(),
            const _SemanticSection(),
            const _MoodSuggestSection(),
            const _QweatherSection(),
            const _TiandituSection(),
            SliverGap(context.safeBottom),
          ],
        ),
      ),
    );
  }
}

class _AiSection extends StatelessWidget {
  const _AiSection();

  @override
  Widget build(BuildContext context) {
    return MSliverSettingGroup(
      title: context.l10n.app.servicesAssistant,
      children: [
        ValueListenableBuilder<String>(
          valueListenable: MoodiaryKVs.assistantActiveProviderId.getNotifier(),
          builder: (context, _, _) => const AssistantSummaryTile(),
        ),
      ],
    );
  }
}

/// 语义检索：嵌入模型选择（下载/切换/删除）+ 停用 + 索引重建。模型运行时下载，
/// 启用后由 EmbedIndexService 后台建索引，助手的 semanticSearchDiaries 随即可用；
/// 切换模型 = 维度变 = 全量重建索引（激活即置 stale）。
class _SemanticSection extends StatefulWidget {
  const _SemanticSection();

  @override
  State<_SemanticSection> createState() => _SemanticSectionState();
}

class _SemanticSectionState extends State<_SemanticSection> {
  final _manager = getIt<EmbeddingModelManager>();

  bool _rebuilding = false;

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    return ValueListenableBuilder<String>(
      valueListenable: MoodiaryKVs.embeddingModelId.getNotifier(),
      builder: (context, _, _) {
        final active = _manager.active;
        return MSliverSettingGroup(
          title: context.l10n.app.semanticTitle,
          children: [
            SettingListTile(
              leading: Icon(
                LucideIcons.sparkles,
                color: scheme.onSurfaceVariant,
              ),
              title: context.l10n.app.semanticModelTitle,
              subtitle:
                  active?.displayName ?? context.l10n.app.semanticStateOff,
              trailing: const Icon(LucideIcons.chevronRight),
              onTap: _openPicker,
            ),
            if (active != null)
              SettingListTile(
                leading: Icon(
                  LucideIcons.refreshCw,
                  color: scheme.onSurfaceVariant,
                ),
                title: context.l10n.app.semanticRebuildTitle,
                subtitle: context.l10n.app.semanticRebuildSubtitle,
                trailing: _rebuilding
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.chevronRight),
                onTap: _rebuilding ? null : _rebuild,
              ),
          ],
        );
      },
    );
  }

  Future<void> _openPicker() async {
    await MSheet.show<void>(
      context,
      builder: (_) => _ModelPickerSheet(manager: _manager),
    );
    if (mounted) setState(() {});
  }

  Future<void> _rebuild() async {
    setState(() => _rebuilding = true);
    try {
      final count = await EmbedIndexService.get().rebuildAll();
      toast.success(message: l10n.app.semanticRebuildDone(count: count));
    } catch (e, s) {
      logger.e('semantic rebuild failed', error: e, stackTrace: s);
    } finally {
      if (mounted) setState(() => _rebuilding = false);
    }
  }
}

class _ModelPickerSheet extends StatefulWidget {
  final EmbeddingModelManager manager;

  const _ModelPickerSheet({required this.manager});

  @override
  State<_ModelPickerSheet> createState() => _ModelPickerSheetState();
}

class _ModelPickerSheetState extends State<_ModelPickerSheet> {
  /// 正在下载的模型 id 与进度（0~1；-1 = 校验中）。
  String? _downloadingId;
  double _progress = 0;

  EmbeddingModelManager get _manager => widget.manager;

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    final active = _manager.active;
    return SafeArea(
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          Padding(
            padding: const .fromLTRB(24, 8, 24, 8),
            child: Text(
              context.l10n.app.semanticPickTitle,
              style: context.theme.typography.titleMedium.onSurface,
            ),
          ),
          for (final (i, spec) in embeddingModelCatalog.indexed)
            _modelTile(
              context,
              spec,
              isFirst: i == 0,
              isLast: i == embeddingModelCatalog.length - 1 && active == null,
              isActive: spec.id == active?.id,
            ),
          if (active != null)
            SettingListTile(
              isLast: true,
              leading: Icon(LucideIcons.circleOff, color: scheme.error),
              title: context.l10n.app.semanticDisableTitle,
              onTap: _downloadingId != null ? null : _disable,
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _modelTile(
    BuildContext context,
    EmbeddingModelSpec spec, {
    required bool isFirst,
    required bool isLast,
    required bool isActive,
  }) {
    final scheme = context.theme.colors;
    final downloading = _downloadingId == spec.id;
    final downloaded = _manager.isDownloaded(spec);
    final sizeMb = (spec.sizeBytes / (1024 * 1024)).round();
    final subtitle = downloading
        ? (_progress < 0
              ? context.l10n.app.semanticVerifying
              : context.l10n.app.semanticDownloading(
                  percent: (_progress * 100).toStringAsFixed(0),
                ))
        : '$sizeMb MB · ${_descOf(context, spec)}';
    return SettingListTile(
      isFirst: isFirst,
      isLast: isLast,
      leading: Icon(
        isActive ? LucideIcons.circleCheck : LucideIcons.box,
        color: isActive ? scheme.primary : scheme.onSurfaceVariant,
      ),
      title: spec.displayName,
      subtitle: subtitle,
      trailing: downloading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : (downloaded && !isActive)
          ? IconButton(
              icon: Icon(LucideIcons.trash2, color: scheme.onSurfaceVariant),
              onPressed: () => _delete(spec),
            )
          : null,
      onTap: (isActive || _downloadingId != null)
          ? null
          : () => _activate(spec),
    );
  }

  String _descOf(BuildContext context, EmbeddingModelSpec spec) {
    return switch (spec.id) {
      'qwen3-embedding-0.6b-int8' => context.l10n.app.semanticDescQwen3,
      _ => '',
    };
  }

  Future<void> _activate(EmbeddingModelSpec spec) async {
    final downloaded = _manager.isDownloaded(spec);
    final sizeMb = (spec.sizeBytes / (1024 * 1024)).round();
    final confirmed = await MAlert.confirm(
      context,
      title: l10n.app.semanticEnableTitle,
      message: downloaded
          ? l10n.app.semanticActivateLocalMessage
          : l10n.app.semanticActivateDownloadMessage(size: '$sizeMb MB'),
      confirmLabel: l10n.app.semanticEnableConfirm,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _downloadingId = spec.id;
      _progress = 0;
    });
    try {
      if (!downloaded) {
        await _manager.download(
          spec,
          onProgress: (received, total) {
            if (!mounted) return;
            setState(() => _progress = total > 0 ? received / total : 0);
          },
        );
      }
      if (mounted) setState(() => _progress = -1);
      await _manager.activate(spec);
      // 激活即置 stale，直接开建（后台跑，不等）。
      unawaited(EmbedIndexService.get().drain());
      toast.success(message: l10n.app.semanticEnabled);
      if (mounted) Navigator.of(context).pop();
    } catch (e, s) {
      logger.e('activate embedding model failed', error: e, stackTrace: s);
      toast.error(message: l10n.app.semanticEnableFailed);
    } finally {
      if (mounted) setState(() => _downloadingId = null);
    }
  }

  Future<void> _delete(EmbeddingModelSpec spec) async {
    final confirmed = await MAlert.confirm(
      context,
      title: l10n.app.semanticDeleteTitle,
      message: l10n.app.semanticDeleteMessage,
      confirmLabel: l10n.app.semanticDeleteConfirm,
      isDestructive: true,
    );
    if (!confirmed) return;
    await _manager.delete(spec);
    if (mounted) setState(() {});
  }

  Future<void> _disable() async {
    final confirmed = await MAlert.confirm(
      context,
      title: l10n.app.semanticDisableTitle,
      message: l10n.app.semanticDisableMessage,
      confirmLabel: l10n.app.semanticDisableConfirm,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    try {
      _manager.deactivate();
      await EmbedIndexService.get().clearAll();
      if (mounted) Navigator.of(context).pop();
    } catch (e, s) {
      logger.e('disable semantic search failed', error: e, stackTrace: s);
    }
  }
}

/// 心情建议：小型本地 LLM 下载/启停。启用后写日记自动保存时在本机建议心情
/// （仅本次会话新建且用户未动过选择器的日记，见 diary_page 的 _maybeSuggestMood）。
class _MoodSuggestSection extends StatefulWidget {
  const _MoodSuggestSection();

  @override
  State<_MoodSuggestSection> createState() => _MoodSuggestSectionState();
}

class _MoodSuggestSectionState extends State<_MoodSuggestSection> {
  final _manager = getIt<MoodLlmModelManager>();

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    return MSliverSettingGroup(
      title: context.l10n.app.moodSuggestTitle,
      children: [
        ValueListenableBuilder<String>(
          valueListenable: MoodiaryKVs.moodLlmModelId.getNotifier(),
          builder: (context, _, _) {
            final active = _manager.active;
            return SettingListTile(
              leading: Icon(
                LucideIcons.smilePlus,
                color: scheme.onSurfaceVariant,
              ),
              title: context.l10n.app.moodSuggestModelTitle,
              subtitle:
                  active?.displayName ?? context.l10n.app.semanticStateOff,
              trailing: const Icon(LucideIcons.chevronRight),
              onTap: _openPicker,
            );
          },
        ),
      ],
    );
  }

  Future<void> _openPicker() async {
    await MSheet.show<void>(
      context,
      builder: (_) => _MoodLlmPickerSheet(manager: _manager),
    );
    if (mounted) setState(() {});
  }
}

class _MoodLlmPickerSheet extends StatefulWidget {
  final MoodLlmModelManager manager;

  const _MoodLlmPickerSheet({required this.manager});

  @override
  State<_MoodLlmPickerSheet> createState() => _MoodLlmPickerSheetState();
}

class _MoodLlmPickerSheetState extends State<_MoodLlmPickerSheet> {
  /// 正在下载的模型 id 与进度（0~1；-1 = 校验中）。
  String? _downloadingId;
  double _progress = 0;

  MoodLlmModelManager get _manager => widget.manager;

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    final active = _manager.active;
    return SafeArea(
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          Padding(
            padding: const .fromLTRB(24, 8, 24, 8),
            child: Text(
              context.l10n.app.moodSuggestPickTitle,
              style: context.theme.typography.titleMedium.onSurface,
            ),
          ),
          for (final (i, spec) in moodLlmCatalog.indexed)
            _modelTile(
              context,
              spec,
              isFirst: i == 0,
              isLast: i == moodLlmCatalog.length - 1 && active == null,
              isActive: spec.id == active?.id,
            ),
          if (active != null)
            SettingListTile(
              isLast: true,
              leading: Icon(LucideIcons.circleOff, color: scheme.error),
              title: context.l10n.app.moodSuggestDisableTitle,
              onTap: _downloadingId != null ? null : _disable,
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _modelTile(
    BuildContext context,
    MoodLlmSpec spec, {
    required bool isFirst,
    required bool isLast,
    required bool isActive,
  }) {
    final scheme = context.theme.colors;
    final downloading = _downloadingId == spec.id;
    final downloaded = _manager.isDownloaded(spec);
    final sizeMb = (spec.sizeBytes / (1024 * 1024)).round();
    final subtitle = downloading
        ? (_progress < 0
              ? context.l10n.app.semanticVerifying
              : context.l10n.app.semanticDownloading(
                  percent: (_progress * 100).toStringAsFixed(0),
                ))
        : '$sizeMb MB · ${context.l10n.app.moodSuggestDescQwen3}';
    return SettingListTile(
      isFirst: isFirst,
      isLast: isLast,
      leading: Icon(
        isActive ? LucideIcons.circleCheck : LucideIcons.box,
        color: isActive ? scheme.primary : scheme.onSurfaceVariant,
      ),
      title: spec.displayName,
      subtitle: subtitle,
      trailing: downloading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : (downloaded && !isActive)
          ? IconButton(
              icon: Icon(LucideIcons.trash2, color: scheme.onSurfaceVariant),
              onPressed: () => _delete(spec),
            )
          : null,
      onTap: (isActive || _downloadingId != null)
          ? null
          : () => _activate(spec),
    );
  }

  Future<void> _activate(MoodLlmSpec spec) async {
    final downloaded = _manager.isDownloaded(spec);
    final sizeMb = (spec.sizeBytes / (1024 * 1024)).round();
    final confirmed = await MAlert.confirm(
      context,
      title: l10n.app.moodSuggestEnableTitle,
      message: downloaded
          ? l10n.app.moodSuggestActivateLocalMessage
          : l10n.app.moodSuggestActivateDownloadMessage(size: '$sizeMb MB'),
      confirmLabel: l10n.app.semanticEnableConfirm,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _downloadingId = spec.id;
      _progress = 0;
    });
    try {
      if (!downloaded) {
        await _manager.download(
          spec,
          onProgress: (received, total) {
            if (!mounted) return;
            setState(() => _progress = total > 0 ? received / total : 0);
          },
        );
      }
      if (mounted) setState(() => _progress = -1);
      _manager.activate(spec);
      toast.success(message: l10n.app.moodSuggestEnabled);
      if (mounted) Navigator.of(context).pop();
    } catch (e, s) {
      logger.e('activate mood llm failed', error: e, stackTrace: s);
      toast.error(message: l10n.app.semanticEnableFailed);
    } finally {
      if (mounted) setState(() => _downloadingId = null);
    }
  }

  Future<void> _delete(MoodLlmSpec spec) async {
    final confirmed = await MAlert.confirm(
      context,
      title: l10n.app.semanticDeleteTitle,
      message: l10n.app.semanticDeleteMessage,
      confirmLabel: l10n.app.semanticDeleteConfirm,
      isDestructive: true,
    );
    if (!confirmed) return;
    await _manager.delete(spec);
    if (mounted) setState(() {});
  }

  Future<void> _disable() async {
    final confirmed = await MAlert.confirm(
      context,
      title: l10n.app.moodSuggestDisableTitle,
      message: l10n.app.moodSuggestDisableMessage,
      confirmLabel: l10n.app.semanticDisableConfirm,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    _manager.deactivate();
    await getIt<MoodLlmEngine>().dispose();
    if (mounted) Navigator.of(context).pop();
  }
}

class _QweatherSection extends ConsumerWidget {
  const _QweatherSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.theme.colors;
    return MSliverSettingGroup(
      title: context.l10n.app.servicesQweather,
      children: [
        _SecretKvTile(
          kv: .qweatherKey,
          title: 'API Key',
          leading: Icon(LucideIcons.key, color: scheme.onSurfaceVariant),
        ),
        _KvTile(
          kv: .qweatherApiHost,
          title: 'API Host',
          subtitleWhenEmpty: context.l10n.app.servicesQweatherHostHint,
          leading: Icon(LucideIcons.server, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _TiandituSection extends ConsumerWidget {
  const _TiandituSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.theme.colors;
    return MSliverSettingGroup(
      title: context.l10n.app.servicesTianditu,
      children: [
        _SecretKvTile(
          kv: .tiandituKey,
          title: 'API Key',
          leading: Icon(LucideIcons.map, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _KvTile extends StatelessWidget {
  final MoodiaryKVs<String> kv;
  final String title;
  final Widget? leading;
  final String? subtitleWhenEmpty;

  const _KvTile({
    required this.kv,
    required this.title,
    this.leading,
    this.subtitleWhenEmpty,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: kv.getNotifierOr(''),
      builder: (context, value, _) {
        return SettingInputTile(
          title: title,
          leading: leading,
          value: value,
          subtitle: value.isEmpty
              ? (subtitleWhenEmpty ?? context.l10n.common.notConfigured)
              : context.l10n.common.configured,
          onValue: (v) async {
            kv.set(v);
            toast.success(message: l10n.app.servicesSaved);
          },
        );
      },
    );
  }
}

/// 同 [_KvTile]，但值在 SecureKV 里：读是异步的、也没有 [KVNotifier]，
/// 所以走 `secretKvProvider` 并在写完 invalidate。
class _SecretKvTile extends ConsumerWidget {
  final MoodiarySecureKVs kv;
  final String title;
  final Widget? leading;

  const _SecretKvTile({required this.kv, required this.title, this.leading});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 钥匙串读的这一小段空窗按「未配置」渲染，与真的没配一致，不闪骨架。
    final value = ref.watch(secretKvProvider(kv)).value ?? '';
    return SettingInputTile(
      title: title,
      leading: leading,
      value: value,
      subtitle: value.isEmpty
          ? context.l10n.common.notConfigured
          : context.l10n.common.configured,
      onValue: (v) async {
        // 写钥匙串会抛（设备锁定 / Keystore 故障）；吞掉的话磁贴还显示旧值，
        // 看起来像存成功了。ref 在 await 之后用，先确认还挂着。
        try {
          await kv.set(v);
        } catch (e, s) {
          logger.e('保存 $kv 失败', error: e, stackTrace: s);
          toast.error(message: l10n.app.servicesSaveFailed);
          return;
        }
        if (!context.mounted) return;
        ref.invalidate(secretKvProvider(kv));
        toast.success(message: l10n.app.servicesSaved);
      },
    );
  }
}
