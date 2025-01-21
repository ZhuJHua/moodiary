import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:moodiary/common/values/colors.dart';
import 'package:moodiary/pages/web_view/web_view_state.dart';
import 'package:refreshed/refreshed.dart';

import 'web_view_logic.dart';

class WebViewPage extends StatelessWidget {
  const WebViewPage({super.key});

  Widget _buildBackToHomeButton(
      {required Color color, required Brightness brightness}) {
    final colorScheme =
        ColorScheme.fromSeed(seedColor: color, brightness: brightness);
    return FilledButton.icon(
      onPressed: Get.back,
      label: Text(
        '退出反馈',
        style: TextStyle(color: colorScheme.onPrimary),
      ),
      icon: Icon(
        Icons.outbound_rounded,
        color: colorScheme.onPrimary,
      ),
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(colorScheme.primary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final WebViewLogic logic = Bind.find<WebViewLogic>();
    final WebViewState state = Bind.find<WebViewLogic>().state;
    final padding = MediaQuery.paddingOf(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (canPop, _) {
        if (canPop) return;
        logic.handleBack();
      },
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: Column(
                children: [
                  Obx(() {
                    return Container(
                      height: padding.top,
                      color: state.progress.value == 1
                          ? AppColor.answerColor
                          : null,
                    );
                  }),
                  Expanded(
                    child: InAppWebView(
                      initialUrlRequest: URLRequest(url: WebUri(state.url)),
                      initialSettings: logic.webSettings,
                      pullToRefreshController: logic.pullToRefreshController,
                      onWebViewCreated: (controller) {
                        logic.webViewController = controller;
                      },
                      onProgressChanged: (controller, progress) {
                        logic.onProgressChanged(progress);
                      },
                    ),
                  ),
                ],
              ),
            ),
            Obx(
              () {
                return Visibility(
                  visible: state.progress.value == 1,
                  child: Positioned(
                    bottom: (state.isTop.value) ? null : 30,
                    top: (state.isTop.value) ? 30 : null,
                    right: (state.isRight.value) ? 30 : null,
                    left: (state.isRight.value) ? null : 30,
                    child: Draggable(
                      feedback: _buildBackToHomeButton(
                          color: AppColor.answerColor,
                          brightness: Brightness.light),
                      childWhenDragging: Container(),
                      onDragEnd: (draggableDetails) {
                        logic.updatePosition(draggableDetails, context);
                      },
                      child: _buildBackToHomeButton(
                          color: AppColor.answerColor,
                          brightness: Brightness.light),
                    ),
                  ),
                );
              },
            ),
            Center(
              child: CircularProgressIndicator(
                value: state.progress.value,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
