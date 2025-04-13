import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/components/base/text.dart';
import 'package:moodiary/l10n/l10n.dart';

import 'dashboard_logic.dart';

class DashboardComponent extends StatelessWidget {
  const DashboardComponent({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(DashboardLogic());

    Widget buildSection({required String title, required String count}) {
      return Column(
        spacing: 8.0,
        children: [
          AdaptiveText(
            title,
            style: context.textTheme.labelMedium?.copyWith(
              color: context.theme.colorScheme.onSurface,
            ),
          ),
          AnimatedText(
            count,
            style: context.textTheme.titleMedium?.copyWith(
              color: context.theme.colorScheme.secondary,
            ),
            isFetching: count.isEmpty,
          ),
        ],
      );
    }

    Widget buildDashBoard() {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        spacing: 8.0,
        children: [
          Flexible(
            flex: 1,
            child: Obx(() {
              return buildSection(
                title: context.l10n.dashboardUseDays,
                count: logic.useTime.value,
              );
            }),
          ),
          Flexible(
            flex: 1,
            child: Obx(() {
              return buildSection(
                title: context.l10n.dashboardTotalDiary,
                count: logic.diaryCount.value,
              );
            }),
          ),
          Flexible(
            flex: 1,
            child: Obx(() {
              return buildSection(
                title: context.l10n.dashboardTotalText,
                count: logic.contentCount.value,
              );
            }),
          ),
          Flexible(
            flex: 1,
            child: Obx(() {
              return buildSection(
                title: context.l10n.dashboardTotalCategory,
                count: logic.categoryCount.value,
              );
            }),
          ),
        ],
      );
    }

    return GetBuilder<DashboardLogic>(
      assignId: true,
      builder: (_) {
        return Card.filled(
          color: context.theme.colorScheme.surfaceContainerLow,
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: buildDashBoard(),
          ),
        );
      },
    );
  }
}
