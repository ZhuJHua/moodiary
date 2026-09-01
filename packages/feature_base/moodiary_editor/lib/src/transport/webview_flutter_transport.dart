import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'editor_transport.dart';

/// Android / iOS / macOS 实现：webview_flutter（官方联邦插件）。命名 [JavaScriptChannel]
/// 注入的 `window.MoodiaryEditor.postMessage` 正是 web 侧 post.ts 的调用形状，无需 shim。
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
      // iOS/macOS：音视频内联播放、无需用户手势。
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }
    final controller = WebViewController.fromPlatformCreationParams(params);
    await controller.setJavaScriptMode(.unrestricted);
    // 不依赖透明 webview：保持不透明，由页面 CSS 自绘主题底色（readBoot 首帧即应用，
    // 加载期由加载遮罩盖住）。
    await controller.addJavaScriptChannel(
      kEditorChannel,
      onMessageReceived: (message) => onMessage(message.message),
    );
    await controller.setOnConsoleMessage((message) {
      // 只保留 JS 异常日志：info/warning 不记录（每条 console 都回 Dart 拖性能）。
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
      // Android WebView 默认 textZoom 自己跟随系统字体缩放，会与下发的
      // --app-font-scale 相乘（那个值同样来自系统缩放）。钉死 100 断掉这条，
      // 让 Flutter 侧算出来的倍率成为唯一来源，两个平台才是同一个行为。
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
    // webview_flutter 控制器无显式 dispose，置空即可。
    _web = null;
  }
}
