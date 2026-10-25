import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_logging/moodiary_logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'diary_repository.dart';
import 'mood_insights.dart';
import 'mood_insights_repository.dart';

part 'mood_insights_controller.g.dart';

class MoodInsightsCardData {
  final MoodInsightsSummary month;
  final double? delta;
  final List<MoodInsightDay?> lastSevenDays;
  final bool hasRecordedMood;
  final DateTime today;
  const MoodInsightsCardData({
    required this.month,
    required this.delta,
    required this.lastSevenDays,
    required this.hasRecordedMood,
    required this.today,
  });
}

@riverpod
class MoodInsightsController extends _$MoodInsightsController {
  bool _stale = false;
  DateTime? _loadedDay;
  late final _repository = getIt<MoodInsightsRepository>();

  @override
  Future<MoodInsightsCardData> build() async {
    final sub = getIt<DiaryRepository>().diaryEvents.listen(
      (_) => _stale = true,
    );
    ref.onDispose(sub.cancel);
    _stale = false;
    try {
      return await _compute();
    } catch (e, s) {
      _stale = true;
      logger.e('Mood card load failed', error: e, stackTrace: s);
      rethrow;
    }
  }

  Future<void> refreshIfStale() async {
    if (!_stale && _loadedDay == moodDayKey(DateTime.now())) return;
    _stale = false;
    try {
      final data = await _compute();
      if (ref.mounted) state = AsyncData(data);
    } catch (e, s) {
      _stale = true;
      logger.e('Mood card refresh failed', error: e, stackTrace: s);
      if (ref.mounted) state = AsyncError(e, s);
    }
  }

  Future<MoodInsightsCardData> _compute() async {
    final today = moodDayKey(DateTime.now());
    _loadedDay = today;
    final start = DateTime(today.year, today.month);
    final previousStart = DateTime(today.year, today.month - 1);
    final rows = await _repository.entries(
      previousStart,
      moodDayOffset(today, 1),
    );
    final current = summarizeMood(
      rows.where((e) => !moodDayKey(e.time).isBefore(start)),
    );
    final previous = summarizeMood(
      rows.where((e) => moodDayKey(e.time).isBefore(start)),
    );
    final days = moodDays(rows);
    return MoodInsightsCardData(
      month: current,
      delta: moodPeriodDelta(current, previous),
      lastSevenDays: [
        for (var i = -6; i <= 0; i++) days[moodDayOffset(today, i)],
      ],
      hasRecordedMood: await _repository.hasRecordedMood(),
      today: today,
    );
  }
}
