import 'package:moodiary_ml/moodiary_ml.dart';
import 'package:moodiary_models/moodiary_models.dart';

const _emotionSentinel = '__emotion__';

const _themeQuestion =
    'Which option best describes what this diary entry is mainly about?';

const _emotionQuestion =
    "What is the writer's dominant emotion in this diary entry?";

// key 就是 DiaryMood.name（哨兵除外），映射靠 DiaryMood.fromName
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
