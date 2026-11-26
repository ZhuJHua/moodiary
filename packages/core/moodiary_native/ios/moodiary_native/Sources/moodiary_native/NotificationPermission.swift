import UIKit
import UserNotifications

final class NotificationPermission: NotificationPermissionApi {
  private let center = UNUserNotificationCenter.current()

  func isEnabled() async -> Bool {
    let settings = await center.notificationSettings()
    switch settings.authorizationStatus {
    case .authorized, .provisional, .ephemeral: return true
    default: return false
    }
  }

  func request() async throws -> Bool {
    _ = try await center.requestAuthorization(options: [.alert, .sound])
    return await isEnabled()
  }

  func openSettings() {
    DispatchQueue.main.async {
      if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
        UIApplication.shared.open(url)
      }
    }
  }
}
