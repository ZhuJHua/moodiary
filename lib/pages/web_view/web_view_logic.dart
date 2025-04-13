import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';

import 'web_view_state.dart';

class WebViewLogic extends GetxController {
  final state = WebViewState();
  late final InAppWebViewController webViewController;

  // late final PullToRefreshController pullToRefreshController =
  //     PullToRefreshController(
  //   onRefresh: () async {
  //     if (defaultTargetPlatform == TargetPlatform.android) {
  //       webViewController.reload();
  //     } else if (defaultTargetPlatform == TargetPlatform.iOS) {
  //       webViewController.loadUrl(
  //           urlRequest: URLRequest(url: await webViewController.getUrl()));
  //     }
  //   },
  // );
  final InAppWebViewSettings webSettings = InAppWebViewSettings(
    javaScriptEnabled: true,
    javaScriptCanOpenWindowsAutomatically: true,
    mediaPlaybackRequiresUserGesture: false,
  );

  @override
  void onClose() {
    //webViewController.dispose();
    super.onClose();
  }

  void onProgressChanged(int progress) {
    state.progress.value = progress / 100;
  }

  void reload() {
    InAppWebViewController.clearAllCache();
    webViewController.reload();
  }

  void handleBack() async {
    if (await webViewController.canGoBack()) {
      await webViewController.goBack();
    } else {
      Get.back();
    }
  }

  void updatePosition(DraggableDetails draggableDetails, context) {
    state.isTop.value =
        (draggableDetails.offset.dy < (MediaQuery.of(context).size.height) / 2);
    state.isRight.value =
        (draggableDetails.offset.dx > (MediaQuery.of(context).size.width) / 2);
  }
}
