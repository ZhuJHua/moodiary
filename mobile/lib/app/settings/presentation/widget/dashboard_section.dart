import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moodiary_ui/moodiary_ui.dart';
import 'package:moodiary_core/moodiary_core.dart';
import 'package:moodiary_data/moodiary_data.dart';

class DashboardSection extends ConsumerWidget {
  const DashboardSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.colorScheme;
    final async = ref.watch(dashboardControllerProvider);
    final stats = async.value;
    return Card.filled(
      color: scheme.surfaceContainerLow,
      margin: .zero,
      child: Padding(
        padding: const .symmetric(horizontal: 12, vertical: 16),
        child: Column(
          children: [
            Row(
              children: [
                _Metric(label: '使用天数', value: stats?.useDays),
                _Metric(label: '日记总数', value: stats?.diaryCount),
                _Metric(label: '总字数', value: stats?.wordCount),
                _Metric(label: '分类数', value: stats?.categoryCount),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _Metric(label: '连续打卡', value: stats?.streakDays),
                _Metric(label: '本月新增', value: stats?.thisMonthCount),
                _Metric(label: '平均心情', value: stats?.averageMood, suffix: '%'),
                _Metric(label: '标签数', value: stats?.tagCount),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final int? value;
  final String? suffix;

  const _Metric({required this.label, required this.value, this.suffix});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final display = value == null ? '' : '${value!}${suffix ?? ''}';
    return Expanded(
      child: Column(
        mainAxisSize: .min,
        children: [
          AdaptiveText(
            label,
            style: context.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedText(
            display,
            style: context.textTheme.titleMedium?.copyWith(
              color: scheme.secondary,
              fontFeatures: const [.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
