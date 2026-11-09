import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_storage/moodiary_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'word_cloud_settings.g.dart';

/// 词云词表上限：KV 的一个值就是一段 JSON，不该无界增长。
const int wordCloudWordsMax = 500;

/// 屏蔽词：加进来的词一定不出现在词云里。
@riverpod
class WordCloudBlocked extends _$WordCloudBlocked {
  @override
  List<String> build() {
    final notifier = MoodiaryKVs.wordCloudBlockedWords.getNotifierOr(
      const <String>[],
    );
    void onChanged() => ref.invalidateSelf();
    notifier.addListener(onChanged);
    ref.onDispose(() => notifier.removeListener(onChanged));
    return List<String>.unmodifiable(notifier.value);
  }

  /// 归一化后入库；已存在或到上限返回 false（调用方据此提示）。
  bool add(String raw) {
    final word = normalizeWordCloudWord(raw);
    if (word.isEmpty || state.contains(word)) return false;
    if (state.length >= wordCloudWordsMax) return false;
    _write([...state, word]);
    return true;
  }

  void remove(String word) => _write([
    for (final w in state)
      if (w != word) w,
  ]);

  void clear() => _write(const []);

  void _write(List<String> next) =>
      _writeWordCloudList(MoodiaryKVs.wordCloudBlockedWords, next);
}

/// 自定义词典：按整词统计，用来修正 jieba 的错切；同时是「保留名单」
/// （优先于内置停用词表，所以内置表误砍的实义词可以在这里找回来）。
@riverpod
class WordCloudLexiconList extends _$WordCloudLexiconList {
  @override
  List<String> build() {
    final notifier = MoodiaryKVs.wordCloudLexicon.getNotifierOr(
      const <String>[],
    );
    void onChanged() => ref.invalidateSelf();
    notifier.addListener(onChanged);
    ref.onDispose(() => notifier.removeListener(onChanged));
    return List<String>.unmodifiable(notifier.value);
  }

  bool add(String raw) {
    final word = normalizeWordCloudWord(raw);
    if (word.isEmpty || state.contains(word)) return false;
    if (state.length >= wordCloudWordsMax) return false;
    _write([...state, word]);
    return true;
  }

  void remove(String word) => _write([
    for (final w in state)
      if (w != word) w,
  ]);

  void clear() => _write(const []);

  void _write(List<String> next) =>
      _writeWordCloudList(MoodiaryKVs.wordCloudLexicon, next);
}

/// 是否隐藏单个字（中英文都一样）。默认关：先靠扩容后的停用词表，
/// 打开它会把「雨 / 猫 / 书」这类实义单字一起去掉。
@riverpod
class WordCloudHideSingleChars extends _$WordCloudHideSingleChars {
  @override
  bool build() {
    final notifier = MoodiaryKVs.wordCloudHideSingleChars.getNotifier();
    void onChanged() => ref.invalidateSelf();
    notifier.addListener(onChanged);
    ref.onDispose(() => notifier.removeListener(onChanged));
    return notifier.value;
  }

  void toggle(bool value) => MoodiaryKVs.wordCloudHideSingleChars.set(value);
}

/// 双写：updateFromStorage 让缓存里的 notifier（provider 监听的那个）立刻通知，
/// set 才落盘。IKVStorage.set 自己也会推一次，这里显式写一遍是与 place / category
/// 排序同一套写法，不依赖那条隐式链路。
void _writeWordCloudList(MoodiaryKVs<List<String>> key, List<String> next) {
  key.getNotifierOr(const <String>[]).updateFromStorage(next);
  key.set(next);
}
