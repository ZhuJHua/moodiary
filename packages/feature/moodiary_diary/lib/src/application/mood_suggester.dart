import 'package:moodiary_ml/moodiary_ml.dart';
import 'package:moodiary_models/moodiary_models.dart';

/// 两段式心情建议：先问「记录哪类事情」（8 主题 + 都不沾边），路由到情绪时
/// 再问「最主要的情绪」（8 情绪）。一次问 16 类小模型顶不住（同套 22 条样例
/// 单问 7/12 量级、两段式 16/22，2026-08-31 本机 int8 实测）；思考模式与
/// few-shot 均实测更差或更贵，别再重推。释义是给模型看的，中文写死不进 i18n
/// （英文 scaffold 实测差一倍）。
const _emotionSentinel = '__emotion__';

const _themeQuestion = '这篇日记主要在记录下面哪类事情？';

const _emotionQuestion = '这篇日记里作者最主要的情绪是什么？';

/// key 就是 [DiaryMood.name]（哨兵除外），映射靠 [DiaryMood.fromName]。
const _themeOptions = <MoodOption>[
  (key: 'love', description: '恋爱：爱情、心动、和恋人有关'),
  (key: 'study', description: '学习：上课、考试、刷题、读书'),
  (key: 'slacking', description: '摸鱼：偷懒、躺平、无所事事'),
  (key: 'food', description: '美食：吃饭、做饭、餐厅、小吃'),
  (key: 'work', description: '工作：上班、项目、会议、加班'),
  (key: 'travel', description: '旅行：出游、观光、逛景点'),
  (key: 'sports', description: '运动：健身、跑步、球赛'),
  (key: 'sick', description: '生病：不舒服、症状、看病吃药'),
  (key: _emotionSentinel, description: '以上都不沾边'),
];

const _emotionOptions = <MoodOption>[
  (key: 'positive', description: '开心：心情好、满足、愉快'),
  (key: 'neutral', description: '平静：没有明显情绪起伏'),
  (key: 'negative', description: '难过：伤心、失落、沮丧'),
  (key: 'excited', description: '兴奋：激动、庆祝、欣喜若狂'),
  (key: 'angry', description: '生气：恼火、愤怒、不爽'),
  (key: 'anxious', description: '焦虑：担心、紧张、睡不着、压力大'),
  (key: 'tired', description: '疲惫：累、筋疲力尽、只想睡'),
  (key: 'speechless', description: '无语：无奈、气到没话说、服了'),
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
