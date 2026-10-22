import Flutter

public class MoodiaryNativePlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger()
    let keyboard = EditorKeyboard(registrar: registrar)
    EditorKeyboardApiSetup.setUp(binaryMessenger: messenger, api: keyboard)
    KeyboardEventsStreamHandler.register(with: messenger, streamHandler: keyboard.events)
  }
}
