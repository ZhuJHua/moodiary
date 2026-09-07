import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'editor_transport.dart';

class WebViewFlutterTransport extends EditorTransport {
  WebViewController? _web;

  @override
  Future<void> prepare({
    required Uri pageUri,
    required OnTransportMessage onMessage,
    required OnTransportConsoleError onConsoleError,
    required OnTransportWebError onWebError,
    required bool debug,
  }) async {
    final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }
    final controller = WebViewController.fromPlatformCreationParams(params);
    await controller.setJavaScriptMode(.unrestricted);
    await controller.addJavaScriptChannel(
      kEditorChannel,
      onMessageReceived: (message) => onMessage(message.message),
    );
    await controller.setOnConsoleMessage((message) {
      if (message.level != .error) return;
      onConsoleError(message.message);
    });
    await controller.setNavigationDelegate(
      NavigationDelegate(
        onWebResourceError: (error) =>
            onWebError(error.description, error.errorCode),
      ),
    );
    final platform = controller.platform;
    if (platform is AndroidWebViewController) {
      await platform.setMediaPlaybackRequiresUserGesture(false);
      // Android WebView textZoom 会跟随系统字体缩放，与下发的 --app-font-scale 相乘，故钉死 100。
      await platform.setTextZoom(100);
      if (debug) await AndroidWebViewController.enableDebugging(true);
    } else if (platform is WebKitWebViewController) {
      if (debug) await platform.setInspectable(true);
    }
    _web = controller;
    await controller.loadRequest(pageUri);
  }

  @override
  Future<void> run(String source) async {
    try {
      await _web?.runJavaScript(source);
    } catch (_) {}
  }

  @override
  Future<Object?> runForResult(String source) async {
    try {
      return await _web?.runJavaScriptReturningResult(source);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget buildView() {
    final web = _web;
    return web == null
        ? const SizedBox.shrink()
        : WebViewWidget(controller: web);
  }

  @override
  void dispose() {
    _web = null;
  }
}
