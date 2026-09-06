import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';

import 'inappwebview_windows_transport.dart';
import 'webview_flutter_transport.dart';

const String kEditorChannel = 'MoodiaryEditor';

typedef OnTransportMessage = void Function(String raw);
typedef OnTransportConsoleError = void Function(String message);
typedef OnTransportWebError = void Function(String description, int code);

abstract class EditorTransport {
  Future<void> prepare({
    required Uri pageUri,
    required OnTransportMessage onMessage,
    required OnTransportConsoleError onConsoleError,
    required OnTransportWebError onWebError,
    required bool debug,
  });

  Future<void> run(String source);

  Future<Object?> runForResult(String source);

  Widget buildView();

  void dispose();
}

EditorTransport createEditorTransport() => Platform.isWindows
    ? WindowsInAppWebViewTransport()
    : WebViewFlutterTransport();
