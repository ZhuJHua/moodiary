import 'dart:collection';

import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';

import 'editor_transport.dart';

// 依赖 flutter_inappwebview_windows（见 pubspec）但无需在此 import：所有类型都出自
// platform_interface，而 Windows 原生实现经 dartPluginClass(WindowsInAppWebViewPlatform)
// 由生成的插件注册器在 Windows 上注册为 InAppWebViewPlatform.instance，与 Dart import 无关。

/// Windows 实现：flutter_inappwebview 的 Windows 联邦包（WebView2，仅声明
/// `platforms: windows`，不污染其它三端构建）。webview_flutter 无 Windows 实现，且
/// WebView2 的中文输入法候选窗定位正确（其 composition controller 挂在跟踪 widget 屏幕
/// 坐标的真子窗口上，而非 webview_windows 那种永不移动的 HWND_MESSAGE 窗口）。
///
/// 没有 umbrella 的 `InAppWebView` 便捷组件，直接用平台接口的
/// [PlatformInAppWebViewWidget]（工厂分派到已注册的 WindowsInAppWebViewWidget），
/// 控制器从 onWebViewCreated 取。
class WindowsInAppWebViewTransport extends EditorTransport {
  PlatformInAppWebViewWidget? _widget;
  PlatformInAppWebViewController? _controller;

  /// document-start shim：把 web 侧统一调用的 `window.MoodiaryEditor.postMessage` 转发到
  /// inappwebview 的 `callHandler`（与 webview_flutter 命名 channel 同形），web 侧零分支。
  static const String _shim =
      'window.$kEditorChannel={postMessage:function(m){'
      "window.flutter_inappwebview.callHandler('$kEditorChannel',m);}};";

  @override
  Future<void> prepare({
    required Uri pageUri,
    required OnTransportMessage onMessage,
    required OnTransportConsoleError onConsoleError,
    required OnTransportWebError onWebError,
    required bool debug,
  }) async {
    final params = PlatformInAppWebViewWidgetCreationParams(
      controllerFromPlatform: (controller) => controller,
      initialUrlRequest: URLRequest(url: WebUri(pageUri.toString())),
      initialUserScripts: UnmodifiableListView<UserScript>([
        UserScript(
          source: _shim,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        ),
      ]),
      initialSettings: InAppWebViewSettings(
        // 媒体内联自动播放（音视频用原生 <audio>/<video>）；不透明背景由页面 CSS 自绘底色。
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        transparentBackground: false,
        isInspectable: debug,
      ),
      onWebViewCreated: (controller) {
        _controller = controller;
        controller.addJavaScriptHandler(
          handlerName: kEditorChannel,
          callback: (args) {
            if (args.isNotEmpty && args.first is String) {
              onMessage(args.first as String);
            }
          },
        );
      },
      onConsoleMessage: (controller, message) {
        // 只保留 JS 异常日志，与 webview_flutter 对齐。
        if (message.messageLevel == ConsoleMessageLevel.ERROR) {
          onConsoleError(message.message);
        }
      },
      onReceivedError: (controller, request, error) {
        onWebError(error.description, 0);
      },
    );
    _widget = PlatformInAppWebViewWidget(params);
  }

  @override
  Future<void> run(String source) async {
    try {
      await _controller?.evaluateJavascript(source: source);
    } catch (_) {}
  }

  @override
  Widget buildView() {
    final widget = _widget;
    // PlatformInAppWebViewWidget.build 需要 context；用 Builder 取一个。
    return widget == null
        ? const SizedBox.shrink()
        : Builder(builder: widget.build);
  }

  @override
  void dispose() {
    _widget?.dispose();
    _widget = null;
    _controller = null;
  }
}
