enum DiaryMood {
  awful,
  bad,
  okay,
  good,
  great;

  int get score => index + 1;

  static DiaryMood? fromName(String? name) => values.asNameMap()[name];

  static DiaryMood? fromScore(int? score) =>
      score != null && score >= 1 && score <= 5 ? values[score - 1] : null;
}

/// Scene tags for legacy imports. Callers resolve these in the UI locale.
enum LegacyMoodScene { study, work, travel, sports, food, slacking }

/// Converts legacy mood names into levels and optional scene tags.
class LegacyMood {
  final DiaryMood? mood;
  final LegacyMoodScene? scene;

  const LegacyMood(this.mood, [this.scene]);

  static LegacyMood? fromName(String? name) => switch (name) {
    'fulfilled' || 'love' => const LegacyMood(.great),
    'positive' => const LegacyMood(.good),
    'neutral' => const LegacyMood(null),
    'negative' ||
    'anxious' ||
    'tired' ||
    'speechless' ||
    'sick' => const LegacyMood(.bad),
    'angry' => const LegacyMood(.awful),
    'study' => const LegacyMood(null, .study),
    'work' => const LegacyMood(null, .work),
    'travel' => const LegacyMood(null, .travel),
    'sports' => const LegacyMood(null, .sports),
    'food' => const LegacyMood(null, .food),
    'slacking' => const LegacyMood(null, .slacking),
    _ => null,
  };
}
