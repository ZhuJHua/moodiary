import Flutter
import ObjectiveC
import UIKit

// Flutter's input view pastes only plain text and hides Paste for images.
// Reading the clipboard after the system's Paste needs no permission prompt, so
// the editor takes the action over while it has focus.
final class SystemPaste: SystemPasteApi {
  private static weak var current: SystemPaste?
  private static let install: Void = {
    guard let view = NSClassFromString("FlutterTextInputView") else { return }
    replacePaste(in: view)
    replaceCanPerformAction(in: view)
  }()

  private let client: SystemPasteClient
  private var enabled = false

  init(messenger: FlutterBinaryMessenger) {
    client = SystemPasteClient(binaryMessenger: messenger)
    SystemPaste.current = self
    _ = SystemPaste.install
  }

  func setEnabled(enabled: Bool) throws {
    self.enabled = enabled
  }

  // Only a method the class defines itself, or a superclass would change too.
  private static func ownMethod(of view: AnyClass, _ selector: Selector) -> Method? {
    guard let method = class_getInstanceMethod(view, selector),
      let parent = class_getSuperclass(view),
      method_getImplementation(method) != class_getMethodImplementation(parent, selector)
    else { return nil }
    return method
  }

  private static func replacePaste(in view: AnyClass) {
    let selector = #selector(UIResponderStandardEditActions.paste(_:))
    guard let method = ownMethod(of: view, selector) else { return }
    typealias Paste = @convention(c) (AnyObject, Selector, Any?) -> Void
    let original = unsafeBitCast(method_getImplementation(method), to: Paste.self)
    let replacement: @convention(block) (AnyObject, Any?) -> Void = { target, sender in
      guard let current = SystemPaste.current, current.enabled else {
        original(target, selector, sender)
        return
      }
      Task { @MainActor in try? await current.client.onPaste() }
    }
    method_setImplementation(method, imp_implementationWithBlock(replacement))
  }

  private static func replaceCanPerformAction(in view: AnyClass) {
    let selector = #selector(UIResponder.canPerformAction(_:withSender:))
    guard let method = ownMethod(of: view, selector) else { return }
    typealias CanPerform = @convention(c) (AnyObject, Selector, Selector, Any?) -> Bool
    let original = unsafeBitCast(method_getImplementation(method), to: CanPerform.self)
    let replacement: @convention(block) (AnyObject, Selector, Any?) -> Bool = {
      target, action, sender in
      if action == #selector(UIResponderStandardEditActions.paste(_:)),
        SystemPaste.current?.enabled == true
      {
        let board = UIPasteboard.general
        return board.hasStrings || board.hasImages || board.hasURLs
      }
      return original(target, selector, action, sender)
    }
    method_setImplementation(method, imp_implementationWithBlock(replacement))
  }
}
