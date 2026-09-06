import 'dart:collection';

import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';

import 'editor_transport.dart';

class WindowsInAppWebViewTransport extends EditorTransport {
  PlatformInAppWebViewWidget? _widget;
  PlatformInAppWebViewController? _controller;

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
        UserScript(source: _shim, injectionTime: .AT_DOCUMENT_START),
      ]),
      initialSettings: InAppWebViewSettings(
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
        if (message.messageLevel == .ERROR) {
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
  Future<Object?> runForResult(String source) async {
    try {
      return await _controller?.evaluateJavascript(source: source);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget buildView() {
    final widget = _widget;
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
