import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:mood_diary/pages/web_view/web_view_state.dart';
import 'package:refreshed/refreshed.dart';

import 'web_view_logic.dart';

class WebViewPage extends StatelessWidget {
  const WebViewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final WebViewLogic logic = Bind.find<WebViewLogic>();
    final WebViewState state = Bind.find<WebViewLogic>().state;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (canPop, _) {
        if (canPop) return;
        logic.handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
            title: Text(state.title),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: Get.back,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: logic.reload,
              )
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(2.0),
              child: Obx(
                () => LinearProgressIndicator(
                  value: state.progress.value,
                  backgroundColor: Colors.transparent,
                  minHeight: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(colorScheme.primary),
                ),
              ),
            )),
        body: SafeArea(
          child: InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(state.url)),
            initialSettings: logic.webSettings,
            onWebViewCreated: (controller) {
              logic.webViewController = controller;
            },
            onProgressChanged: (controller, progress) {
              logic.onProgressChanged(progress);
            },
          ),
        ),
      ),
    );
  }
}
