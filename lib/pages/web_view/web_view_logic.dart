import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:refreshed/refreshed.dart';

import 'web_view_state.dart';

class WebViewLogic extends GetxController {
  final state = WebViewState();
  late final InAppWebViewController webViewController;
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
    if (progress == 100) {
      state.progress.value = 0.0;
    }
  }

  void reload() {
    webViewController.reload();
  }

  void handleBack() async {
    if (await webViewController.canGoBack()) {
      await webViewController.goBack();
    } else {
      Get.back();
    }
  }
}
