import Flutter
import ObjectiveC
import UIKit
import WebKit
import webview_flutter_wkwebview

final class EditorKeyboard: NSObject, EditorKeyboardApi {
  private struct State: Equatable {
    var visible: Bool
    var height: Double
    var floating: Bool

    static let hidden = State(visible: false, height: 0, floating: false)
  }

  final class Events: KeyboardEventsStreamHandler {
    weak var owner: EditorKeyboard?

    override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<KeyboardEvent>) {
      owner?.sink = sink
      owner?.refresh()
    }

    override func onCancel(withArguments arguments: Any?) {
      owner?.sink = nil
      owner?.refresh()
    }
  }

  // WKWebView 自带的处理按 Flutter 调整布局前的键盘高度滚动内容，而 Flutter 已把它摆在键盘上方
  private static let webViewKeyboardNotifications: [Notification.Name] = [
    UIResponder.keyboardWillShowNotification,
    UIResponder.keyboardWillHideNotification,
    UIResponder.keyboardWillChangeFrameNotification,
    UIResponder.keyboardDidChangeFrameNotification,
  ]

  let events = Events()
  private weak var registrar: FlutterPluginRegistrar?
  private weak var webView: WKWebView?
  private var sink: PigeonEventSink<KeyboardEvent>?
  private var observers: [NSObjectProtocol] = []
  private var lastStart: State?
  private var lastEnd: State?
  private var pendingEnd = false

  init(registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
    super.init()
    events.owner = self
  }

  func attach(webViewId: Int64) throws {
    guard let registrar,
      let webView = FWFWebViewFlutterWKWebViewExternalAPI.webView(
        forIdentifier: webViewId, withPluginRegistrar: registrar)
    else {
      throw PigeonError(
        code: "no-webview", message: "No WKWebView with identifier \(webViewId)", details: nil)
    }
    if self.webView !== webView {
      release()
    }
    WebViewInputHook.install()
    if webView.moodiaryInput == nil {
      webView.moodiaryInput = WebViewInputState()
    }
    for name in Self.webViewKeyboardNotifications {
      NotificationCenter.default.removeObserver(webView, name: name, object: nil)
    }
    self.webView = webView
    Self.firstResponder(in: webView)?.reloadInputViews()
    refresh()
  }

  func detach() throws {
    release()
    refresh()
  }

  func setKeyboardSuppressed(suppressed: Bool) throws -> Bool {
    guard let webView, let input = webView.moodiaryInput else { return false }
    guard let responder = Self.firstResponder(in: webView) else {
      // 照样清标志，否则下次聚焦会拿到零高的 inputView
      if !suppressed { input.setSuppressed(false, responder: nil) }
      return false
    }
    input.setSuppressed(suppressed, responder: responder)
    return true
  }

  func focusWebView() throws {
    guard let webView, Self.firstResponder(in: webView) == nil else { return }
    webView.becomeFirstResponder()
  }

  private func release() {
    guard let webView else { return }
    let responder = Self.firstResponder(in: webView)
    webView.moodiaryInput?.setSuppressed(false, responder: nil)
    webView.moodiaryInput = nil
    responder?.reloadInputViews()
    self.webView = nil
  }

  private func refresh() {
    let active = sink != nil && webView != nil
    guard active == observers.isEmpty else { return }
    let center = NotificationCenter.default
    if !active {
      observers.forEach { center.removeObserver($0) }
      observers.removeAll()
      return
    }
    lastStart = nil
    lastEnd = nil
    pendingEnd = false
    let starts: [Notification.Name] = [
      UIResponder.keyboardWillShowNotification,
      UIResponder.keyboardWillHideNotification,
      UIResponder.keyboardWillChangeFrameNotification,
    ]
    let ends: [Notification.Name] = [
      UIResponder.keyboardDidShowNotification,
      UIResponder.keyboardDidHideNotification,
      UIResponder.keyboardDidChangeFrameNotification,
    ]
    for (names, isStart) in [(starts, true), (ends, false)] {
      for name in names {
        observers.append(
          center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
            self?.handle(note, isStart: isStart)
          })
      }
    }
  }

  private func handle(_ note: Notification, isStart: Bool) {
    guard sink != nil, let view = registrar?.viewController?.view, let info = note.userInfo,
      let end = (info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
    else {
      return
    }
    if (info[UIResponder.keyboardIsLocalUserInfoKey] as? Bool) == false {
      return
    }
    let hiding =
      note.name == UIResponder.keyboardWillHideNotification
      || note.name == UIResponder.keyboardDidHideNotification
    let frameChange =
      note.name == UIResponder.keyboardWillChangeFrameNotification
      || note.name == UIResponder.keyboardDidChangeFrameNotification
    // 帧变化时全零 frame 表示键盘正被拖动
    if !hiding && frameChange && end == .zero {
      return
    }
    let state =
      hiding ? State.hidden : Self.state(for: end, screen: note.object as? UIScreen, in: view)
    let seconds = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0
    if isStart {
      // UIKit 一次过渡会重复发 WillShow / WillChangeFrame
      guard state != lastStart else { return }
      lastStart = state
      pendingEnd = true
    } else {
      guard pendingEnd || state != lastEnd else { return }
      pendingEnd = false
      lastEnd = state
      lastStart = state
    }
    sink?.success(
      KeyboardEvent(
        visible: state.visible,
        height: state.height,
        durationMs: Int64((seconds * 1000).rounded()),
        isStart: isStart,
        floating: state.floating
      ))
  }

  private static func state(for end: CGRect, screen: UIScreen?, in view: UIView) -> State {
    // 硬件键盘快捷栏收起时上报全零 frame
    if end == .zero {
      return State(visible: true, height: 0, floating: true)
    }
    guard !end.isEmpty, let screen = screen ?? view.window?.windowScene?.screen else {
      return .hidden
    }
    let overlap = view.bounds.intersection(screen.coordinateSpace.convert(end, to: view))
    if overlap.isNull || overlap.height.rounded() <= 0 || overlap.width <= 0 {
      return .hidden
    }
    let screenHeight = screen.bounds.height
    let docked = end.maxY.rounded() >= screenHeight.rounded()
    let floating = !docked || overlap.height < screenHeight * 0.2
    return State(visible: true, height: docked ? Double(overlap.height) : 0, floating: floating)
  }

  private static func firstResponder(in view: UIView) -> UIView? {
    if view.isFirstResponder {
      return view
    }
    for subview in view.subviews {
      if let found = firstResponder(in: subview) {
        return found
      }
    }
    return nil
  }
}

final class WebViewInputState: NSObject {
  private(set) var suppressed = false
  lazy var emptyInputView = UIView(frame: .zero)
  private var shortcutGroups: (leading: [UIBarButtonItemGroup], trailing: [UIBarButtonItemGroup])?
  private weak var shortcutOwner: UIResponder?

  // iPad 快捷栏只有清空分组才不会压在自定义 inputView 上方
  func setSuppressed(_ value: Bool, responder: UIResponder?) {
    guard value != suppressed else { return }
    suppressed = value
    if value, let item = responder?.inputAssistantItem {
      shortcutGroups = (item.leadingBarButtonGroups, item.trailingBarButtonGroups)
      shortcutOwner = responder
      item.leadingBarButtonGroups = []
      item.trailingBarButtonGroups = []
    } else if !value, let groups = shortcutGroups, let item = shortcutOwner?.inputAssistantItem {
      item.leadingBarButtonGroups = groups.leading
      item.trailingBarButtonGroups = groups.trailing
      shortcutGroups = nil
    }
    responder?.reloadInputViews()
  }
}

private var inputStateKey: UInt8 = 0

extension WKWebView {
  fileprivate var moodiaryInput: WebViewInputState? {
    get { objc_getAssociatedObject(self, &inputStateKey) as? WebViewInputState }
    set { objc_setAssociatedObject(self, &inputStateKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
  }
}

// 真正的第一响应者 WKContentView 向 WKWebView 要这两个视图；按类 swizzle 加实例标志，不能 object_setClass（webview_flutter 已对实例做 KVO 子类化）
private enum WebViewInputHook {
  private static let installed: Void = {
    WebViewInputHook.hook(#selector(getter: UIResponder.inputView)) { webView, original in
      guard let input = webView.moodiaryInput, input.suppressed else { return original() }
      return input.emptyInputView
    }
    WebViewInputHook.hook(#selector(getter: UIResponder.inputAccessoryView)) { webView, original in
      webView.moodiaryInput == nil ? original() : nil
    }
  }()

  static func install() {
    _ = installed
  }

  private static func hook(
    _ selector: Selector, _ body: @escaping (WKWebView, () -> UIView?) -> UIView?
  ) {
    let method = class_getInstanceMethod(WKWebView.self, selector)!
    typealias Getter = @convention(c) (AnyObject, Selector) -> UIView?
    let original = unsafeBitCast(method_getImplementation(method), to: Getter.self)
    let block: @convention(block) (WKWebView) -> UIView? = { webView in
      body(webView) { original(webView, selector) }
    }
    let imp = imp_implementationWithBlock(block)
    // WKWebView 只继承 getter 时用 add 而非替换，免得改到 UIResponder
    if !class_addMethod(WKWebView.self, selector, imp, method_getTypeEncoding(method)) {
      method_setImplementation(method, imp)
    }
  }
}
