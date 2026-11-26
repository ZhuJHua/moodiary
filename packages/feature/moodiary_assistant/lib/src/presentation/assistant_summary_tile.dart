import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_assistant/src/assistant_providers.dart';
import 'package:moodiary_components/moodiary_components.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_router/moodiary_router.dart';

class AssistantSummaryTile extends ConsumerStatefulWidget {
  const AssistantSummaryTile({super.key});

  @override
  ConsumerState<AssistantSummaryTile> createState() =>
      _AssistantSummaryTileState();
}

class _AssistantSummaryTileState extends ConsumerState<AssistantSummaryTile> {
  LlmProvider? _active;
  bool _keyConfigured = false;
  bool _loaded = false;
  StreamSubscription<void>? _sub;

  late final _repo = ref.read(llmProviderRepositoryProvider);

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
