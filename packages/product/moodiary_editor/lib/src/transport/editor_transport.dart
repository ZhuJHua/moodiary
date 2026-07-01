import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';

import 'inappwebview_windows_transport.dart';
import 'webview_flutter_transport.dart';

/// JS → Flutter 通道名。webview_flutter 用它做命名 JavaScriptChannel（自动注入
/// `window.MoodiaryEditor.postMessage`）；inappwebview 用它做 addJavaScriptHandler，并由
/// 一个 document-start UserScript 把 `window.MoodiaryEditor.postMessage` 转发到
/// `window.flutter_inappwebview.callHandler(同名)` —— 两端 web 侧调用形状一致，post.ts 无需分支。
const String kEditorChannel = 'MoodiaryEditor';

typedef OnTransportMessage = void Function(String raw);
typedef OnTransportConsoleError = void Function(String message);
typedef OnTransportWebError = void Function(String description, int code);

/// 编辑器 webview 传输层：屏蔽 webview_flutter（Android/iOS/macOS）与
/// flutter_inappwebview_windows（Windows，WebView2，中文输入法候选窗定位正确）的差异，
/// 对 [MoodiaryEditor] 暴露统一的「装载页面 / 执行 JS / 取视图 / 释放」。桥语义、状态机、
/// 加载遮罩等仍由 [MoodiaryEditor] 持有，两端共用。
abstract class EditorTransport {
  /// 配置 webview 并开始加载 [pageUri]。webview_flutter 在此即建控制器并 loadRequest；
  /// inappwebview 仅登记参数，真正实例化随 [buildView] 的平台视图挂载发生。两端都需宿主
  /// 在 prepare 完成后 setState 触发重建以挂载 [buildView]。
  Future<void> prepare({
    required Uri pageUri,
    required OnTransportMessage onMessage,
    required OnTransportConsoleError onConsoleError,
    required OnTransportWebError onWebError,
    required bool debug,
  });

  /// 执行 JS（fire-and-forget）；吞掉 JS 运行时异常 —— WebKit / WebView2 会把异常包成
  /// PlatformException 抛出，按「JS 异常不上抛」契约处理，避免打断 10s 就绪超时兜底。
  Future<void> run(String source);

  /// 承载 webview 的 widget；prepare 完成并 setState 后挂载。
  Widget buildView();

  void dispose();
}

/// 按平台选传输实现：Windows 走 inappwebview，其余（Android/iOS/macOS）走 webview_flutter。
EditorTransport createEditorTransport() => Platform.isWindows
    ? WindowsInAppWebViewTransport()
    : WebViewFlutterTransport();
