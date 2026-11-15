import Flutter

public class MoodiaryNativePlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger()
    HtmlClipboardApiSetup.setUp(binaryMessenger: messenger, api: HtmlClipboard())
    ImageTransferApiSetup.setUp(binaryMessenger: messenger, api: ImageTransfer())
    KeyboardHeightStreamHandler.register(with: messenger, streamHandler: KeyboardHeight())
    SystemPasteApiSetup.setUp(binaryMessenger: messenger, api: SystemPaste(messenger: messenger))
  }
}
