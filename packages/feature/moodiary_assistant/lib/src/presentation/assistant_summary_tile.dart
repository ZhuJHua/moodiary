import 'dart:async';

import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';

import '../routes.dart';

/// 设置页可嵌入的「AI 助手配置」摘要磁贴：展示当前供应商 / 模型 / Key 状态，点击进入
/// 助手设置页。自监听 [LlmProviderRepository.providerEvents]，由 app 侧 `const
/// AssistantSummaryTile()` 组合进设置页。
class AssistantSummaryTile extends StatefulWidget {
  const AssistantSummaryTile({super.key});

  @override
  State<AssistantSummaryTile> createState() => _AssistantSummaryTileState();
}

class _AssistantSummaryTileState extends State<AssistantSummaryTile> {
  LlmProvider? _active;
  bool _keyConfigured = false;
  bool _loaded = false;
  StreamSubscription<void>? _sub;

  LlmProviderRepository get _repo => .get();

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
    final active = await _repo.getActiveProvider();
    final key = active == null ? null : await _repo.getKey(active.id);
    if (!mounted) return;
    setState(() {
      _active = active;
      _keyConfigured = key != null && key.isNotEmpty;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final active = _active;
    final subtitle = !_loaded
        ? context.l10n.assistant.summaryLoading
        : active == null
        ? context.l10n.assistant.summaryNoProvider
        : '${active.name} · ${active.defaultModel} · '
              '${_keyConfigured ? context.l10n.assistant.summaryKeySet : context.l10n.assistant.summaryKeyUnset}';
    return SettingListTile(
      isFirst: true,
      isLast: true,
      title: context.l10n.assistant.summaryTitle,
      subtitle: subtitle,
      leading: const Icon(LucideIcons.bot),
      trailing: const Icon(LucideIcons.chevronRight),
      onTap: () async {
        await const AssistantSettingRoute().push(context);
        await _load();
      },
    );
  }
}
