import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      body: ListView(
        padding: const .symmetric(horizontal: 8, vertical: 8),
        children: const [
          _Note(),
          SizedBox(height: 4),
          _AiSection(),
          SizedBox(height: 4),
          _SemanticSection(),
          SizedBox(height: 4),
          _SentimentSection(),
          SizedBox(height: 4),
          _QweatherSection(),
          SizedBox(height: 4),
          _TiandituSection(),
          SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note();

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    return Card.filled(
      color: scheme.surfaceContainerHighest,
      margin: const .symmetric(horizontal: 8),
      child: Padding(
        padding: const .all(12),
        child: Row(
          children: [
            Icon(LucideIcons.waypoints, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.l10n.app.servicesIntro,
                style: context.theme.typography.bodySmall.onSurfaceVariant,
              ),
            ),
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
    final scheme = context.theme.colors;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        SettingTitleTile(title: context.l10n.app.servicesAssistant),
        Card.filled(
          color: scheme.surfaceContainerLow,
          margin: .zero,
          child: ValueListenableBuilder<String>(
            valueListenable: MoodiaryKVs.assistantActiveProviderId
                .getNotifier(),
            builder: (context, _, _) => const AssistantSummaryTile(),
          ),
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
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        SettingTitleTile(title: context.l10n.app.semanticTitle),
        Card.filled(
          color: scheme.surfaceContainerLow,
          margin: .zero,
          child: ValueListenableBuilder<String>(
            valueListenable: MoodiaryKVs.embeddingModelId.getNotifier(),
            builder: (context, _, _) {
              final active = _manager.active;
              return Column(
                children: [
                  SettingListTile(
                    isFirst: true,
                    isLast: active == null,
                    leading: Icon(
                      LucideIcons.sparkles,
                      color: scheme.onSurfaceVariant,
                    ),
                    title: context.l10n.app.semanticModelTitle,
                    subtitle:
                        active?.displayName ??
                        context.l10n.app.semanticStateOff,
                    trailing: const Icon(LucideIcons.chevronRight),
                    onTap: _openPicker,
                  ),
                  if (active != null)
                    SettingListTile(
                      isLast: true,
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
          ),
        ),
      ],
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
    final l10nApp = context.l10n.app;
    return switch (spec.id) {
      'bge-small-zh-v1.5-int8' => l10nApp.semanticDescBgeSmall,
      'bge-base-zh-v1.5-int8' => l10nApp.semanticDescBgeBase,
      'bge-large-zh-v1.5-int8' => l10nApp.semanticDescBgeLarge,
      'bge-m3-int8' => l10nApp.semanticDescBgeM3,
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

/// 心情建议：情感分析模型下载/启停。启用后写日记自动保存时在本机建议心情指数
/// （仅新建且用户未动过滑条的日记，见 diary_page 的 _maybeSuggestMood）。
class _SentimentSection extends StatefulWidget {
  const _SentimentSection();

  @override
  State<_SentimentSection> createState() => _SentimentSectionState();
}

class _SentimentSectionState extends State<_SentimentSection> {
  final _manager = getIt<SentimentModelManager>();

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colors;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        SettingTitleTile(title: context.l10n.app.sentimentTitle),
        Card.filled(
          color: scheme.surfaceContainerLow,
          margin: .zero,
          child: ValueListenableBuilder<String>(
            valueListenable: MoodiaryKVs.sentimentModelId.getNotifier(),
            builder: (context, _, _) {
              final active = _manager.active;
              return SettingListTile(
                isFirst: true,
                isLast: true,
                leading: Icon(
                  LucideIcons.smilePlus,
                  color: scheme.onSurfaceVariant,
                ),
                title: context.l10n.app.sentimentModelTitle,
                subtitle:
                    active?.displayName ?? context.l10n.app.semanticStateOff,
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: _openPicker,
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _openPicker() async {
    await MSheet.show<void>(
      context,
      builder: (_) => _SentimentPickerSheet(manager: _manager),
    );
    if (mounted) setState(() {});
  }
}

class _SentimentPickerSheet extends StatefulWidget {
  final SentimentModelManager manager;

  const _SentimentPickerSheet({required this.manager});

  @override
  State<_SentimentPickerSheet> createState() => _SentimentPickerSheetState();
}

class _SentimentPickerSheetState extends State<_SentimentPickerSheet> {
  /// 正在下载的模型 id 与进度（0~1；-1 = 校验中）。
  String? _downloadingId;
  double _progress = 0;

  SentimentModelManager get _manager => widget.manager;

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
              context.l10n.app.sentimentPickTitle,
              style: context.theme.typography.titleMedium.onSurface,
            ),
          ),
          for (final (i, spec) in sentimentModelCatalog.indexed)
            _modelTile(
              context,
              spec,
              isFirst: i == 0,
              isLast: i == sentimentModelCatalog.length - 1 && active == null,
              isActive: spec.id == active?.id,
            ),
          if (active != null)
            SettingListTile(
              isLast: true,
              leading: Icon(LucideIcons.circleOff, color: scheme.error),
              title: context.l10n.app.sentimentDisableTitle,
              onTap: _downloadingId != null ? null : _disable,
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _modelTile(
    BuildContext context,
    SentimentModelSpec spec, {
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
        : '$sizeMb MB · ${context.l10n.app.sentimentDescMultilingual}';
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

  Future<void> _activate(SentimentModelSpec spec) async {
    final downloaded = _manager.isDownloaded(spec);
    final sizeMb = (spec.sizeBytes / (1024 * 1024)).round();
    final confirmed = await MAlert.confirm(
      context,
      title: l10n.app.sentimentEnableTitle,
      message: downloaded
          ? l10n.app.sentimentActivateLocalMessage
          : l10n.app.sentimentActivateDownloadMessage(size: '$sizeMb MB'),
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
      toast.success(message: l10n.app.sentimentEnabled);
      if (mounted) Navigator.of(context).pop();
    } catch (e, s) {
      logger.e('activate sentiment model failed', error: e, stackTrace: s);
      toast.error(message: l10n.app.semanticEnableFailed);
    } finally {
      if (mounted) setState(() => _downloadingId = null);
    }
  }

  Future<void> _delete(SentimentModelSpec spec) async {
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
      title: l10n.app.sentimentDisableTitle,
      message: l10n.app.sentimentDisableMessage,
      confirmLabel: l10n.app.semanticDisableConfirm,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    _manager.deactivate();
    await getIt<SentimentEngine>().dispose();
    if (mounted) Navigator.of(context).pop();
  }
}

class _QweatherSection extends ConsumerWidget {
  const _QweatherSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.theme.colors;
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        SettingTitleTile(title: context.l10n.app.servicesQweather),
        Card.filled(
          color: scheme.surfaceContainerLow,
          margin: .zero,
          child: Column(
            children: [
              _SecretKvTile(
                kv: .qweatherKey,
                title: 'API Key',
                leading: Icon(LucideIcons.key, color: scheme.onSurfaceVariant),
                isFirst: true,
              ),
              _KvTile(
                kv: .qweatherApiHost,
                title: 'API Host',
                subtitleWhenEmpty: context.l10n.app.servicesQweatherHostHint,
                leading: Icon(
                  LucideIcons.server,
                  color: scheme.onSurfaceVariant,
                ),
                isLast: true,
              ),
            ],
          ),
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
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        SettingTitleTile(title: context.l10n.app.servicesTianditu),
        Card.filled(
          color: scheme.surfaceContainerLow,
          margin: .zero,
          child: Column(
            children: [
              _SecretKvTile(
                kv: .tiandituKey,
                title: 'API Key',
                leading: Icon(LucideIcons.map, color: scheme.onSurfaceVariant),
                isFirst: true,
                isLast: true,
              ),
            ],
          ),
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
  final bool isLast;

  const _KvTile({
    required this.kv,
    required this.title,
    this.leading,
    this.subtitleWhenEmpty,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: kv.getNotifierOr(''),
      builder: (context, value, _) {
        return SettingInputTile(
          isLast: isLast,
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
  final bool isFirst;
  final bool isLast;

  const _SecretKvTile({
    required this.kv,
    required this.title,
    this.leading,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 钥匙串读的这一小段空窗按「未配置」渲染，与真的没配一致，不闪骨架。
    final value = ref.watch(secretKvProvider(kv)).value ?? '';
    return SettingInputTile(
      isFirst: isFirst,
      isLast: isLast,
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
