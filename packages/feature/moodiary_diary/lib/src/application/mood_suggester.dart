import 'package:moodiary_ml/moodiary_ml.dart';
import 'package:moodiary_models/moodiary_models.dart';

/// 两段式心情建议：先问「记录哪类事情」（8 主题 + 都不沾边），路由到情绪时
/// 再问「最主要的情绪」（8 情绪）。领域概念是单一平铺的「心情状态」，
/// 主题/情绪的拆分只是这里的分类器实现细节——同套 22 条样例实测（2026-08-31
/// 本机 int8）：英文两段式 12/22 > 英文统一单问 10/22 > 全英文旧版 8/22，
/// 别照着「概念统一了」把它简化成单问。思考模式与 few-shot 均实测更差或更贵。
/// 提示词统一英文（用户拍板：状态要国际化、英文作基础）；中文两段式实测
/// 15/22，这 3 条差距是知情接受的代价。「日记可能是任意语言」的提示实测
/// 更差（9/22），别加回来。
const _emotionSentinel = '__emotion__';

const _themeQuestion =
    'Which option best describes what this diary entry is mainly about?';

const _emotionQuestion =
    "What is the writer's dominant emotion in this diary entry?";

/// key 就是 [DiaryMood.name]（哨兵除外），映射靠 [DiaryMood.fromName]。
const _themeOptions = <MoodOption>[
  (key: 'love', description: 'love — a partner, a date, romance'),
  (key: 'study', description: 'study — classes, exams, homework, reading'),
  (
    key: 'slacking',
    description:
        'slacking — lazing around, scrolling the phone, doing nothing all day',
  ),
  (
    key: 'food',
    description: 'food — a meal, cooking, a restaurant, dessert, snacks',
  ),
  (key: 'work', description: 'work — the job, projects, meetings, overtime'),
  (
    key: 'travel',
    description: 'travel — a trip, sightseeing, being away from home',
  ),
  (key: 'sports', description: 'sports — a workout, the gym, running, a match'),
  (
    key: 'sick',
    description:
        'sick — feeling ill, symptoms, seeing a doctor, taking medicine',
  ),
  (
    key: _emotionSentinel,
    description:
        'none of these activities — the entry is mainly about a feeling',
  ),
];

const _emotionOptions = <MoodOption>[
  (
    key: 'positive',
    description: 'happy — in a good mood, something worth celebrating',
  ),
  (key: 'neutral', description: 'calm — an ordinary day, nothing much to say'),
  (key: 'negative', description: 'sad — down, upset, heartbroken, grieving'),
  (
    key: 'fulfilled',
    description: 'fulfilled — got things done, effort paid off',
  ),
  (
    key: 'angry',
    description: 'angry — provoked by someone or something, annoyed',
  ),
  (
    key: 'anxious',
    description: "anxious — worried, nervous, can't sleep over something ahead",
  ),
  (key: 'tired', description: 'tired — exhausted, drained, only want to sleep'),
  (
    key: 'speechless',
    description: 'speechless — exasperated, fed up, done with it',
  ),
];

Future<DiaryMood> suggestMood(MoodLlmEngine engine, String text) async {
  final (theme, _) = await engine.ask(
    text,
    question: _themeQuestion,
    options: _themeOptions,
  );
  if (theme != _emotionSentinel) return DiaryMood.fromName(theme);
  final (emotion, _) = await engine.ask(
    text,
    question: _emotionQuestion,
    options: _emotionOptions,
  );
  return DiaryMood.fromName(emotion);
}
