import Flutter

public class MoodiaryNativePlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger()
    HtmlClipboardApiSetup.setUp(binaryMessenger: messenger, api: HtmlClipboard())
    let images = ImageTransfer(registrar: registrar)
    ImageTransferApiSetup.setUp(binaryMessenger: messenger, api: images)
    KeyboardHeightStreamHandler.register(with: messenger, streamHandler: KeyboardHeight())
    SystemPasteApiSetup.setUp(binaryMessenger: messenger, api: SystemPaste(messenger: messenger))
  }
}
