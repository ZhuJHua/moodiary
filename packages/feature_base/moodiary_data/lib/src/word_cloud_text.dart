// 词云的文本侧规则：把 jieba_query() 的输出拆回词表并判断候选词。
//
// 分词只有一条来源 —— SQLite 里的 jieba_query(text, 0)（即 cppjieba 的 Cut，
// sqlite3_simple 提供）。它返回的是 FTS5 MATCH 表达式而不是词表，形状见
// jiebaMatchExpressionToWords()；本文件是唯一依赖那个形状的地方。

/// `jieba_query(text, 0)` 里连接两个 token 的字面量。
///
/// 一定是大写：表达式由 C++ 侧 `append_result` 拼出，而其中的拉丁词会被
/// 小写化，所以正文里出现 "and" 只会是 `and*`，不会撞上这个分隔符。
const String _and = ' AND ';

/// 单字/单词长度上限：跑飞的 URL、文件名之类不进词云。
const int wordCloudMaxWordLength = 24;

final RegExp _wordChar = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// 把分词结果归一化成统计用的键。
///
/// jieba 已经把拉丁词小写化；这里再统一一次，好让用户输入的屏蔽词能用
/// 同样的小写形式比较（汉字不受影响）。全角/半角、繁简不转换。
String normalizeWordCloudWord(String word) => word.trim().toLowerCase();

/// 词云候选词：长度合适，且至少含一个字母、数字或汉字。
///
/// 标点单独成 token（`，`、`。`、`——`）是 jieba 的正常输出，靠这一条剔除。
bool isWordCloudWord(String word) =>
    word.length <= wordCloudMaxWordLength && _wordChar.hasMatch(word);

/// 把 `jieba_query(text, 0)` 的输出拆回词表。
///
/// 逐条规则（都对应 C++ 侧 `simple_tokenizer.cc` 的 `append_result`）：
///  * 汉字词是带引号的短语 —— `"今天天气"`，因为 FTS5 索引里汉字是**按单字**
///    存的，短语要求这些字相邻；
///  * 拉丁词是小写的裸 token 加星号 —— `hello*`；
///  * 数字串是引号里再加星号 —— `"2024"*`，所以**先去星号再去引号**；
///  * 正文里的 `"` 会被复制成 `""`（FTS5 短语里的转义），还原时换回一个。
///
/// 只接受 `flags = 0` 的输出。`flags = 1` 会把拉丁词展开成拼音 OR 组
/// （`( h+e+l+l+o* OR hello* )`），那种形状这里不解析。
List<String> jiebaMatchExpressionToWords(String expression) {
  if (expression.isEmpty) return const [];
  final words = <String>[];
  for (final raw in expression.split(_and)) {
    var token = raw.trim();
    if (token.isEmpty) continue;
    if (token.endsWith('*')) {
      token = token.substring(0, token.length - 1);
    }
    if (token.length >= 2 && token.startsWith('"') && token.endsWith('"')) {
      token = token.substring(1, token.length - 1).replaceAll('""', '"');
    }
    if (token.isNotEmpty) words.add(token);
  }
  return words;
}

/// 是否保留这个词：[normalized] 必须先过 [normalizeWordCloudWord]。
///
/// 优先级（用户显式表达的 > 内置默认 > 泛化规则）：
///   1. [blocked] 屏蔽词 —— 一定不出现；
///   2. [keep] 自定义词典 —— **豁免**内置停用词表与单字规则，这样内置表误砍的
///      实义词（比如「书」）可以靠加词典找回来；
///   3. 标点 / 超长一律不要（词典也救不了，因为它们不是词）；
///   4. [hideSingleChars] 与内置停用词表。
bool keepWordCloudWord(
  String normalized, {
  required Set<String> blocked,
  Set<String> keep = const {},
  bool hideSingleChars = false,
}) {
  if (normalized.isEmpty) return false;
  if (blocked.contains(normalized)) return false;
  if (!isWordCloudWord(normalized)) return false;
  if (keep.contains(normalized)) return true;
  if (hideSingleChars && normalized.length == 1) return false;
  return !wordCloudStopWords.contains(normalized);
}

/// 停用词表：代码里的常量，不入 KV、不跟着用户屏蔽词走。
///
/// 中文部分只有虚词 + 泛化时间词（的/了/我们/今天/时候…），凡是有实义的
/// 名词、动词、形容词都不在这里 —— 用户想再砍就用屏蔽词。英文部分同理。
///
/// 不读 cppjieba 的 `stop_words.utf8`：那张表只在 `Extract` 里生效，SQL 层
/// 没有暴露，从磁盘读它会耦合 sqlite3_simple 的内部布局。
final Set<String> wordCloudStopWords = {
  for (final word in '$_stopWordsZh $_stopWordsEn'.split(RegExp(r'\s+')))
    if (word.isNotEmpty) word,
};

/// 中文：虚词、代词、连词、介词、量词、泛化时间词、语气词，以及实测里最容易
/// 占据词云前排的**非实义单字**。
///
/// 单字是刻意列的：jieba 的 `Cut` 会把这些字单独切出来（这是它的正常行为），
/// 而它们对"我看这一年写了什么"没有信息量。加进来就砍不回去了 —— 实义单字
/// （猫、雨、书、聊、读、吃、喝、玩、学…）**不在这里**，如果确实误砍，
/// 用户可以用自定义词典把它们"保留"回来（词典优先于本表）。
/// 更彻底的一键方案是「隐藏单个字」开关。
/// 空白分隔即可增删，不必维护 Dart 字面量。
const String _stopWordsZh = '''
的 地 得 了 着 过 是 在 和 与 及 或 也 都 就 才 又 再 还 更 最 很 太 挺 蛮
只 仅 单 被 把 让 给 对 向 往 从 自 于 为 以 因 由 按 据 随 除 连 跟 同 并
而 但 却 则 若 如 即 便 乃 之 其 此 该 各 每 某 些 个 位 件 种 次 遍 趟
一 二 三 我 你 他 她 它 您 咱 我们 你们 他们 她们 它们 咱们 大家 自己 别人
这 那 这些 那些 这样 那样 这么 那么 这里 那里 这儿 那儿 哪 哪个 哪里 哪儿
谁 什么 怎么 怎样 如何 为什么 何时 多少 几 啥
不 没 没有 无 非 未 别 莫 勿
可以 可能 应该 必须 需要 会 能 要 想 也许 大概 差不多 好像 似乎 当然 其实
真的 非常 特别 比较 有点 稍微 一直 一起 一样 一定 不是 不能 不会 不要 不用
不过 就是 还是 只是 已经 正在 曾经 刚 刚刚 马上 立刻 终于 居然 竟然 果然
甚至 尤其 反正 总之 因此 于是 然而 否则 要不 要么 或者 还有 另外 此外
比如 例如 关于 对于 由于 为了 通过 根据 按照 除了 直到 自从 随着 无论
不管 即使 只要 只有 除非 万一 因为 所以 以及 等等 之类 之一
之后 之前 以后 以前 以来 之间 之中 之内 之外 当时 那时 这时 此时
时候 现在 今天 昨天 明天 后天 前天 早上 上午 中午 下午 晚上 夜里 半夜
一天 每天 天天 有时 有时候 经常 总是 时间
而且 但是 这件 那件 一件 这种 那种 一些 有些 到底 那边 这边 有没有 太大
太小 太多 太少 很好 觉得 打算 没看 再读 很受
吧 呢 啊 呀 哦 嗯 吗 啦 嘛 哈 哎 唉 喂 喔 诶 嗨 嘿 哇 咦
去 来 到 出 进 走 看 做 用 说 找 拿 放 起 开 站 坐 回 干 搞 弄
有 事 懂 试 该 让 得 过 着
上 下 中 里 外 前 后 左 右 内 间 头 面 边
点 分 秒 号 元 块 岁 条 张 本 名 只 儿
好 大 小 多 少 真 高 低 长 短 新 旧
天 年 月 日 时 早 晚
''';

/// 英文：虚词与泛化词。
const String _stopWordsEn = '''
the a an and or but if of to in on at for with is are was were be been being
am do does did have has had i you he she it we they me him her us them my your
his its our their this that these those not no so as by from up down out about
just very really too also then than there here what which who when where why
how can could will would should shall may might must ok okay yeah yes well
get got make made one two go going thing things something anything nothing
''';
