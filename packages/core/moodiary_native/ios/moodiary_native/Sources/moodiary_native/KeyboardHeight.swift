import Flutter
import UIKit

// The will-notifications carry the frame the keyboard animates to, so the
// final height arrives when the animation starts.
final class KeyboardHeight: KeyboardHeightStreamHandler {
  private var sink: PigeonEventSink<Double>?
  private var observers: [NSObjectProtocol] = []
  private var last: Double?

  override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<Double>) {
    self.sink = sink
    last = nil
    let center = NotificationCenter.default
    observers = [
      UIResponder.keyboardWillShowNotification,
      UIResponder.keyboardWillChangeFrameNotification,
    ].map { name in
      center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
        self?.report(Self.height(note))
      }
    }
    observers.append(
      center.addObserver(
        forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main
      ) { [weak self] _ in self?.report(0) })
  }

  override func onCancel(withArguments arguments: Any?) {
    observers.forEach(NotificationCenter.default.removeObserver)
    observers = []
    sink = nil
  }

  private func report(_ height: Double) {
    guard height != last else { return }
    last = height
    sink?.success(height)
  }

  // Only a keyboard docked to the bottom of the window counts; a floating or
  // undocked one covers nothing.
  private static func height(_ note: Notification) -> Double {
    guard
      let end = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?
        .cgRectValue,
      let window = keyWindow
    else { return 0 }
    let frame = window.convert(end, from: window.screen.coordinateSpace)
    let bounds = window.bounds
    guard frame.maxY >= bounds.maxY - 1, frame.minY < bounds.maxY else { return 0 }
    return Double(bounds.maxY - frame.minY)
  }

  private static var keyWindow: UIWindow? {
    UIApplication.shared.connectedScenes
      .compactMap { ($0 as? UIWindowScene)?.keyWindow }
      .first
  }
}
