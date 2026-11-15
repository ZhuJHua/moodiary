import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_diary/src/application/word_cloud_settings.dart';
import 'package:moodiary_i18n/moodiary_i18n.dart';
import 'package:mui/mui.dart';

/// 词云词典：三个分区 —— 自定义词（修分词）、屏蔽词（不出现）、单字开关。
///
/// 优先级：**屏蔽词 > 自定义词 > 内置停用词表**。所以自定义词同时也是一份
/// 「保留名单」：内置表误砍的实义词（书、雨…）加进来就能回到词云里。
class WordCloudDictionaryPage extends ConsumerStatefulWidget {
  const WordCloudDictionaryPage({super.key});

  @override
  ConsumerState<WordCloudDictionaryPage> createState() =>
      _WordCloudDictionaryPageState();
}

class _WordCloudDictionaryPageState
    extends ConsumerState<WordCloudDictionaryPage> {
  final _lexiconInput = TextEditingController();
  final _blockedInput = TextEditingController();

  @override
  void dispose() {
    _lexiconInput.dispose();
    _blockedInput.dispose();
    super.dispose();
  }

  void _add(TextEditingController controller, bool lexicon) {
    if (controller.text.trim().isEmpty) return;
    final added = lexicon
        ? ref.read(wordCloudLexiconListProvider.notifier).add(controller.text)
        : ref.read(wordCloudBlockedProvider.notifier).add(controller.text);
    if (added) {
      controller.clear();
      HapticFeedback.mediumImpact();
      return;
    }
    toast.error(message: l10n.wordcloud.wordsRejected);
  }

  Future<void> _clear(bool lexicon, int count) async {
    final confirmed = await MAlert.confirm(
      context,
      title: lexicon
          ? l10n.wordcloud.lexiconClear
          : l10n.wordcloud.blockedClear,
      message: lexicon
          ? l10n.wordcloud.lexiconClearMessage(count: count)
          : l10n.wordcloud.blockedClearMessage(count: count),
      confirmLabel: l10n.common.delete,
      isDestructive: true,
    );
    if (!confirmed) return;
    if (lexicon) {
      ref.read(wordCloudLexiconListProvider.notifier).clear();
    } else {
      ref.read(wordCloudBlockedProvider.notifier).clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lexicon = ref.watch(wordCloudLexiconListProvider);
    final blocked = ref.watch(wordCloudBlockedProvider);
    final hideSingle = ref.watch(wordCloudHideSingleCharsProvider);
    final l10n = context.l10n;
    final theme = context.theme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.wordcloud.dictionaryTitle)),
      body: CustomScrollView(
        slivers: [
          _WordsSection(
            title: l10n.wordcloud.lexiconTitle,
            hint: l10n.wordcloud.lexiconHint,
            inputHint: l10n.wordcloud.lexiconAddHint,
            addTooltip: l10n.wordcloud.lexiconAdd,
            input: _lexiconInput,
            words: lexicon,
            onAdd: () => _add(_lexiconInput, true),
            onRemove: (word) =>
                ref.read(wordCloudLexiconListProvider.notifier).remove(word),
            onClear: lexicon.isEmpty
                ? null
                : () => _clear(true, lexicon.length),
          ),
          _WordsSection(
            title: l10n.wordcloud.blockedTitle,
            hint: l10n.wordcloud.blockedHint,
            inputHint: l10n.wordcloud.blockedAddHint,
            addTooltip: l10n.wordcloud.blockedAdd,
            input: _blockedInput,
            words: blocked,
            onAdd: () => _add(_blockedInput, false),
            onRemove: (word) =>
                ref.read(wordCloudBlockedProvider.notifier).remove(word),
            onClear: blocked.isEmpty
                ? null
                : () => _clear(false, blocked.length),
          ),
          SliverPadding(
            padding: const .fromLTRB(8, 0, 8, 8),
            sliver: MSliverSettingGroup(
              title: l10n.wordcloud.singleCharsTitle,
              children: [
                SettingSwitchListTile(
                  title: l10n.wordcloud.hideSingleChars,
                  subtitle: l10n.wordcloud.hideSingleCharsHint,
                  value: hideSingle,
                  isFirst: true,
                  isLast: true,
                  onChanged: (value) => ref
                      .read(wordCloudHideSingleCharsProvider.notifier)
                      .toggle(value),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const .fromLTRB(20, 4, 20, 24),
              child: Text(
                l10n.wordcloud.priorityHint,
                style: theme.typography.labelSmall.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 一个词表分区：输入 + 添加、词条 chip 列表（可删）、右上角清空。
class _WordsSection extends StatelessWidget {
  final String title;
  final String hint;
  final String inputHint;
  final String addTooltip;
  final TextEditingController input;
  final List<String> words;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;
  final VoidCallback? onClear;

  const _WordsSection({
    required this.title,
    required this.hint,
    required this.inputHint,
    required this.addTooltip,
    required this.input,
    required this.words,
    required this.onAdd,
    required this.onRemove,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return SliverList.list(
      children: [
        Padding(
          padding: const .fromLTRB(20, 16, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  words.isEmpty ? title : '$title · ${words.length}',
                  style:
                      theme.typography.labelMedium.emphasized.onSurfaceVariant,
                ),
              ),
              if (onClear != null)
                IconButton(
                  tooltip: context.l10n.wordcloud.blockedClear,
                  icon: const Icon(LucideIcons.eraser, size: 20),
                  onPressed: onClear,
                ),
            ],
          ),
        ),
        Padding(
          padding: const .fromLTRB(16, 0, 16, 0),
          child: MField(
            controller: input,
            hintText: inputHint,
            textInputAction: .done,
            onSubmitted: (_) => onAdd(),
            trailing: IconButton(
              tooltip: addTooltip,
              icon: const Icon(LucideIcons.plus),
              onPressed: onAdd,
            ),
          ),
        ),
        Padding(
          padding: const .fromLTRB(20, 8, 20, 0),
          child: Text(hint, style: theme.typography.bodySmall.onSurfaceVariant),
        ),
        if (words.isEmpty)
          Padding(
            padding: const .fromLTRB(20, 10, 20, 0),
            child: Text(
              context.l10n.wordcloud.wordsEmpty,
              style: theme.typography.labelSmall.outline,
            ),
          )
        else
          Padding(
            padding: const .fromLTRB(16, 10, 16, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final word in words)
                  InputChip(
                    label: Text(word),
                    onDeleted: () => onRemove(word),
                    deleteIcon: const Icon(LucideIcons.x, size: 16),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
