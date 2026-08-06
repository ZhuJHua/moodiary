import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_models/moodiary_models.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_data/moodiary_data.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'analyse_page.g.dart';

@riverpod
Future<List<Diary>> allShownDiaries(Ref ref) async {
  return DiaryRepository.get().getAllDiariesSorted();
}

class AnalysePage extends ConsumerWidget {
  const AnalysePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(allShownDiariesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('数据分析')),
      body: async.buildLoading(
        data: (diaries) => _AnalyseBody(diaries: diaries),
      ),
    );
  }
}

class _AnalyseBody extends StatelessWidget {
  final List<Diary> diaries;
  const _AnalyseBody({required this.diaries});

  @override
  Widget build(BuildContext context) {
    if (diaries.isEmpty) {
      return const Center(child: Text('暂无日记，去写一篇吧！'));
    }
    final now = DateTime.now();
    final thisMonth = diaries
        .where((d) => _sameMonth(d.time.toLocal(), now))
        .length;
    final moodSum = diaries.fold<double>(0, (acc, d) => acc + d.mood);
    final moodAvg = moodSum / diaries.length;
    final streak = _continuousDays(diaries);
    final monthCounts = _last6Months(diaries, now);

    return ListView(
      padding: const .all(16),
      children: [
        _StatGrid(
          items: [
            ('日记总数', diaries.length.toString(), LucideIcons.book),
            ('本月', thisMonth.toString(), LucideIcons.calendarDays),
            (
              '心情均值',
              '${(moodAvg * 100).toStringAsFixed(0)}%',
              LucideIcons.smile,
            ),
            ('连续天数', '$streak', LucideIcons.flame),
          ],
        ),
        const SizedBox(height: 24),
        Text('近 6 个月写作量', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        _BarChart(data: monthCounts),
      ],
    );
  }

  List<(String, int)> _last6Months(List<Diary> diaries, DateTime now) {
    final months = <DateTime>[];
    for (var i = 5; i >= 0; i--) {
      months.add(DateTime(now.year, now.month - i, 1));
    }
    return [
      for (final m in months)
        (
          '${m.month}月',
          diaries.where((d) => _sameMonth(d.time.toLocal(), m)).length,
        ),
    ];
  }

  static bool _sameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  int _continuousDays(List<Diary> diaries) {
    final days = <String>{};
    for (final d in diaries) {
      final t = d.time.toLocal();
      days.add('${t.year}-${t.month}-${t.day}');
    }
    int count = 0;
    var cursor = DateTime.now();
    while (days.contains('${cursor.year}-${cursor.month}-${cursor.day}')) {
      count += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }
}

class _StatGrid extends StatelessWidget {
  final List<(String, String, IconData)> items;
  const _StatGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.8,
      children: [
        for (final (label, value, icon) in items)
          Card(
            margin: .zero,
            child: Padding(
              padding: const .all(12),
              child: Column(
                crossAxisAlignment: .start,
                mainAxisAlignment: .center,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(label, style: theme.textTheme.labelMedium),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(value, style: theme.textTheme.headlineSmall),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _BarChart extends StatelessWidget {
  final List<(String, int)> data;
  const _BarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxV = data.fold<int>(0, (m, e) => e.$2 > m ? e.$2 : m);
    final theme = Theme.of(context);
    return SizedBox(
      height: 160,
      child: Row(
        crossAxisAlignment: .end,
        children: [
          for (final (label, count) in data)
            Expanded(
              child: Column(
                mainAxisAlignment: .end,
                children: [
                  Text('$count', style: theme.textTheme.labelSmall),
                  const SizedBox(height: 4),
                  Container(
                    margin: const .symmetric(horizontal: 4),
                    height: maxV == 0 ? 0 : 120 * count / maxV,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: .circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(label, style: theme.textTheme.labelSmall),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
