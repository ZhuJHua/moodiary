import Flutter
import UserNotifications

public class MoodiaryNativePlugin: NSObject, FlutterPlugin, FlutterSceneLifeCycleDelegate {
  private let reminders: ReminderNotifications

  private init(messenger: FlutterBinaryMessenger) {
    reminders = ReminderNotifications(messenger: messenger)
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger()
    let plugin = MoodiaryNativePlugin(messenger: messenger)
    registrar.publish(plugin)
    registrar.addApplicationDelegate(plugin)
    registrar.addSceneDelegate(plugin)
    NotificationPermissionApiSetup.setUp(binaryMessenger: messenger, api: NotificationPermission())
    ReminderNotificationsApiSetup.setUp(binaryMessenger: messenger, api: plugin.reminders)
    HtmlClipboardApiSetup.setUp(binaryMessenger: messenger, api: HtmlClipboard())
    ImageTransferApiSetup.setUp(binaryMessenger: messenger, api: ImageTransfer())
    KeyboardHeightStreamHandler.register(with: messenger, streamHandler: KeyboardHeight())
    SystemPasteApiSetup.setUp(binaryMessenger: messenger, api: SystemPaste(messenger: messenger))
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    reminders.detach()
  }

  public func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler(ReminderNotifications.owns(notification) ? [.banner, .list, .sound] : [])
  }

  public func userNotificationCenter(
    _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    handle(response)
    completionHandler()
  }

  public func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    guard let response = connectionOptions?.notificationResponse else { return false }
    return handle(response)
  }

  @discardableResult private func handle(_ response: UNNotificationResponse) -> Bool {
    guard response.actionIdentifier == UNNotificationDefaultActionIdentifier,
      ReminderNotifications.owns(response.notification) else { return false }
    ReminderNotifications.receive(response.notification)
    return true
  }
}
