import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mood_diary/common/values/icons.dart';
import 'package:mood_diary/components/mood_icon/mood_icon_view.dart';
import 'package:mood_diary/utils/utils.dart';

import 'analyse_logic.dart';

class AnalysePage extends StatelessWidget {
  const AnalysePage({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Bind.find<AnalyseLogic>();
    final state = Bind.find<AnalyseLogic>().state;
    final textStyle = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    //柱状图
    Widget buildBarChart(String title, Map<String, IconData> iconMap,
        Map<String, int> countMap, List<String> itemList) {
      //去重
      itemList = Utils().arrayUtil.toSetList(itemList);
      return Container(
        padding: const EdgeInsets.all(20.0),
        margin: const EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 10.0),
        decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10.0)),
        child: Column(
          children: [
            Text(
              title,
              style:
                  textStyle.titleMedium!.copyWith(color: colorScheme.onSurface),
            ),
            const SizedBox(
              height: 10,
            ),
            AspectRatio(
              aspectRatio: 1.0,
              child: itemList.isNotEmpty
                  ? BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        borderData: FlBorderData(
                          show: true,
                          border: Border.symmetric(
                            horizontal: BorderSide(
                              color: colorScheme.onSurface
                                  .withAlpha((255 * 0.6).toInt()),
                            ),
                          ),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 1.0,
                                  getTitlesWidget: (value, meta) {
                                    return Text(value.toInt().toString());
                                  })),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  return SideTitleWidget(
                                      axisSide: meta.axisSide,
                                      child: Icon(
                                          iconMap[itemList[value.toInt()]]));
                                }),
                          ),
                          topTitles: const AxisTitles(),
                          rightTitles: const AxisTitles(),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          checkToShowHorizontalLine: (value) {
                            return value.toInt() == value;
                          },
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: colorScheme.onSurface
                                  .withAlpha((255 * 0.2).toInt()),
                              strokeWidth: 1,
                            );
                          },
                        ),
                        barGroups: List.generate(
                          itemList.length,
                          (index) => BarChartGroupData(x: index, barRods: [
                            BarChartRodData(
                                fromY: 0,
                                toY: countMap[itemList[index]]!.toDouble(),
                                color: colorScheme.primary)
                          ]),
                        ),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (state.finished) ...[
                          Text(
                            '暂无数据',
                            style: textStyle.titleLarge!
                                .copyWith(color: colorScheme.onSurface),
                          ),
                        ] else ...[
                          const CircularProgressIndicator(),
                        ],
                      ],
                    ),
            )
          ],
        ),
      );
    }

    Widget buildMoodWrap(String title, List<double> itemList) {
      return Container(
        padding: const EdgeInsets.all(20.0),
        margin: const EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 10.0),
        decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10.0)),
        child: Column(
          children: [
            Text(
              title,
              style:
                  textStyle.titleMedium!.copyWith(color: colorScheme.onSurface),
            ),
            const SizedBox(
              height: 10,
            ),
            AspectRatio(
              aspectRatio: 1.0,
              child: itemList.isNotEmpty
                  ? SingleChildScrollView(
                      child: Wrap(
                        spacing: 10.0,
                        runSpacing: 10.0,
                        children: List.generate(state.moodList.length, (index) {
                          return MoodIconComponent(
                              value: state.moodList[index]);
                        }),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (state.finished) ...[
                          Text(
                            '暂无数据',
                            style: textStyle.titleLarge!
                                .copyWith(color: colorScheme.onSurface),
                          ),
                        ] else ...[
                          const CircularProgressIndicator(),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '分析',
        ),
      ),
      body: GetBuilder<AnalyseLogic>(builder: (_) {
        return ListView(
          children: [
            Container(
              padding: const EdgeInsets.all(10.0),
              margin: const EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 10.0),
              decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10.0)),
              child: Row(
                children: [
                  IconButton.filled(
                      onPressed: () {
                        logic.openDatePicker(context);
                      },
                      icon: const Icon(Icons.date_range)),
                  const SizedBox(
                    width: 10,
                  ),
                  Expanded(
                    child: Text(
                      '${state.dateRange[0].year}年${state.dateRange[0].month}月${state.dateRange[0].day}日 至 ${state.dateRange[1].year}年${state.dateRange[1].month}月${state.dateRange[1].day}日',
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(10.0),
              margin: const EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 10.0),
              decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10.0)),
              child: Column(
                children: [
                  TextButton(
                      onPressed: () {
                        logic.getAi();
                      },
                      child: const Text('AI 分析')),
                  if (state.reply != '') ...[Text(state.reply)]
                ],
              ),
            ),
            buildBarChart(
                '天气', WeatherIcon.map, state.weatherMap, state.weatherList),
            buildMoodWrap('心情', state.moodList),
          ],
        );
      }),
    );
  }
}
