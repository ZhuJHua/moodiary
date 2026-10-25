import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:moodiary_di/moodiary_di.dart';
import 'package:moodiary_models/moodiary_models.dart';

class _Repository implements MoodInsightsRepository {
  List<MoodInsightEntry> rows = [];
  int loads = 0;
  @override
  Future<List<MoodInsightEntry>> entries(DateTime start, DateTime end) async {
    loads++;
    return rows
        .where((e) => !e.time.isBefore(start) && e.time.isBefore(end))
        .toList();
  }

  @override
  Future<bool> hasRecordedMood() async => rows.any((e) => e.mood != null);
}

class _Diaries implements DiaryRepository {
  final events = StreamController<DiaryEvent>.broadcast(sync: true);
  @override
  Stream<DiaryEvent> get diaryEvents => events.stream;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Repository repository;
  late _Diaries diaries;
  late ProviderContainer container;
  setUp(() {
    repository = _Repository();
    diaries = _Diaries();
    getIt.registerSingleton<MoodInsightsRepository>(repository);
    getIt.registerSingleton<DiaryRepository>(diaries);
    container = ProviderContainer(retry: (_, _) => null);
  });
  tearDown(() async {
    container.dispose();
    await diaries.events.close();
    await getIt.reset();
  });

  test('card has day-weighted month mean, full previous-month delta and rolling seven days', () async {
    final today = moodDayKey(DateTime.now());
    final previous = DateTime(today.year, today.month, 0);
    repository.rows = [
      MoodInsightEntry(id: 'a', time: today, mood: .good),
      MoodInsightEntry(id: 'b', time: today, mood: .great),
      MoodInsightEntry(id: 'old', time: previous, mood: .awful),
    ];
    container.listen(moodInsightsControllerProvider, (_, _) {});
    final result = await container.read(moodInsightsControllerProvider.future);
    expect(result.month.average, 4.5);
    expect(result.month.recordedDays, 1);
    expect(result.delta, 3.5);
    expect(result.hasRecordedMood, isTrue);
    expect(result.lastSevenDays.length, 7);
    expect(result.lastSevenDays.last!.level, DiaryMood.great);
    expect(result.today, today);
  });

  test('events mark stale; refresh on return updates once and preserves ever-recorded flag', () async {
    final today = moodDayKey(DateTime.now());
    final historical = DateTime(today.year - 2);
    repository.rows = [
      MoodInsightEntry(id: 'old', time: historical, mood: .good),
    ];
    container.listen(moodInsightsControllerProvider, (_, _) {});
    final initial = await container.read(moodInsightsControllerProvider.future);
    expect(initial.month.average, isNull);
    expect(initial.hasRecordedMood, isTrue);
    final notifier = container.read(moodInsightsControllerProvider.notifier);
    await notifier.refreshIfStale();
    expect(repository.loads, 1);
    repository.rows.add(MoodInsightEntry(id: 'new', time: today, mood: .great));
    diaries.events.add(const DiaryEvent.deleted('old'));
    expect(repository.loads, 1);
    await notifier.refreshIfStale();
    expect(repository.loads, 2);
    expect(
      container.read(moodInsightsControllerProvider).requireValue.month.average,
      5,
    );
    await notifier.refreshIfStale();
    expect(repository.loads, 2);
  });
}
