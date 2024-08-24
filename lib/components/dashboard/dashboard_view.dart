import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mood_diary/common/values/icons.dart';
import 'package:mood_diary/components/mood_icon/mood_icon_view.dart';

import 'dashboard_logic.dart';

class DashboardComponent extends StatelessWidget {
  const DashboardComponent({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(DashboardLogic());
    final state = Bind.find<DashboardLogic>().state;
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme;

    Widget buildManagerButton(IconData icon, String label, Widget content, Function()? onTap) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: Card.outlined(
          color: colorScheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Icon(
                      icon,
                      color: colorScheme.secondary,
                      size: 32,
                    ),
                    Text(
                      label,
                      style: textStyle.labelLarge,
                    )
                  ],
                ),
                const SizedBox(
                  width: 8.0,
                ),
                Expanded(child: Center(child: content))
              ],
            ),
          ),
        ),
      );
    }

    Widget buildDetail(String content, String unit) {
      return content == ''
          ? const CircularProgressIndicator()
          : RichText(
              text: TextSpan(children: [
                TextSpan(text: '$content ', style: textStyle.displaySmall!.copyWith(color: colorScheme.tertiary)),
                TextSpan(text: unit, style: textStyle.labelLarge)
              ]),
            );
    }

    Widget buildDiaryDetail(String content1, String unit1, String content2, String unit2) {
      return content1 == '' || content2 == ''
          ? const CircularProgressIndicator()
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(children: [
                      TextSpan(text: '$content1 ', style: textStyle.titleLarge!.copyWith(color: colorScheme.tertiary)),
                      TextSpan(text: unit1, style: textStyle.labelLarge)
                    ]),
                  ),
                  const SizedBox(
                    height: 8.0,
                  ),
                  RichText(
                    text: TextSpan(children: [
                      TextSpan(text: '$content2 ', style: textStyle.titleLarge!.copyWith(color: colorScheme.tertiary)),
                      TextSpan(text: unit2, style: textStyle.labelLarge)
                    ]),
                  ),
                ],
              ),
            );
    }

    Widget buildAnalyse(String mood, String weather) {
      return mood == '' || weather == ''
          ? const CircularProgressIndicator()
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (weather != 'none') ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Text(
                        '天气',
                        style: textStyle.labelLarge,
                      ),
                      Icon(
                        WeatherIcon.map[weather],
                        color: colorScheme.tertiary,
                      ),
                    ],
                  ),
                ],
                if (weather != 'none' && mood != 'none') ...[
                  const SizedBox(
                    height: 8.0,
                  )
                ],
                if (mood != 'none') ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Text(
                        '心情',
                        style: textStyle.labelLarge,
                      ),
                      MoodIconComponent(
                        value: double.parse(mood),
                        width: 24.0,
                      )
                    ],
                  )
                ],
                if (weather == 'none' && mood == 'none') ...[const Text('暂无')]
              ],
            );
    }

    return GetBuilder<DashboardLogic>(
      init: logic,
      assignId: true,
      autoRemove: false,
      builder: (logic) {
        return GridView(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200,
            mainAxisSpacing: 8.0,
            crossAxisSpacing: 8.0,
            childAspectRatio: 1.618,
          ),
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          children: [
            buildManagerButton(Icons.calendar_month, '使用', Obx(() {
              return buildDetail(state.useTime.value, '天');
            }), null),
            buildManagerButton(Icons.article, '日记', Obx(() {
              return buildDiaryDetail(state.diaryCount.value, '篇', state.contentCount.value, '字');
            }), () {
              logic.toDiaryManager();
            }),
            buildManagerButton(Icons.category, '分类', Obx(() {
              return buildDetail(state.categoryCount.value, '个');
            }), () {
              logic.toCategoryManager();
            }),
            buildManagerButton(Icons.analytics, '分析', Obx(() {
              return buildAnalyse(state.recentMood.value, state.recentWeather.value);
            }), () {
              logic.toAnalysePage();
            }),
          ],
        );
      },
    );
  }
}
