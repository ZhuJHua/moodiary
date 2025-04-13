import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/components/base/loading.dart';
import 'package:moodiary/components/local_send/local_send_view.dart';
import 'package:moodiary/components/sync_dash_board/sync_dash_board_state.dart';
import 'package:moodiary/components/sync_dash_board/web_dav_dashboard/web_dav_dashboard_view.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import 'sync_dash_board_logic.dart';

class SyncDashBoardComponent extends StatelessWidget {
  const SyncDashBoardComponent({super.key});

  @override
  Widget build(BuildContext context) {
    final SyncDashBoardLogic logic = Get.put(SyncDashBoardLogic());
    final SyncDashBoardState state = Bind.find<SyncDashBoardLogic>().state;

    return GetBuilder<SyncDashBoardLogic>(
      assignId: true,
      builder: (_) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child:
              !state.isFetching
                  ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        child: PageView(
                          controller: logic.pageController,
                          children: const [
                            WebDavDashboardComponent(),
                            LocalSendComponent(isDashboard: true),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              onPressed: () {
                                logic.changePage(0);
                              },
                              icon: const Icon(Icons.chevron_left_rounded),
                            ),
                            Expanded(
                              child: Center(
                                child: SmoothPageIndicator(
                                  controller: logic.pageController,
                                  count: 2,
                                  axisDirection: Axis.horizontal,
                                  effect: ExpandingDotsEffect(
                                    dotWidth: 8.0,
                                    dotHeight: 8.0,
                                    activeDotColor:
                                        context.theme.colorScheme.primary,
                                    dotColor:
                                        context.theme.colorScheme.secondary,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                logic.changePage(1);
                              },
                              icon: const Icon(Icons.chevron_right_rounded),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                  : const MoodiaryLoading(),
        );
      },
    );
  }
}
