import Flutter
import UserNotifications

final class ReminderNotifications: ReminderNotificationsApi {
  private let center = UNUserNotificationCenter.current()
  private let events: ReminderNotificationsEvents
  private static let prefix = "reminder."
  private static let testId = "reminder.test"
  @MainActor private static var lastWrite: Task<Void, Error>?

  init(messenger: FlutterBinaryMessenger) {
    events = ReminderNotificationsEvents(binaryMessenger: messenger)
  }

  private func content(title: String, body: String) -> UNMutableNotificationContent {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    content.userInfo = ["moodiary": "reminder"]
    return content
  }

  @MainActor private func write(_ operation: @escaping () async throws -> Void) async throws {
    let previous = Self.lastWrite
    let task = Task {
      _ = await previous?.result
      try await operation()
    }
    Self.lastWrite = task
    try await task.value
  }

  @MainActor func setSchedule(schedule: ReminderSchedule) async throws {
    try await write { [self] in
      var desired = [UNNotificationRequest]()
      for slot in schedule.slots {
        let content = content(title: slot.title, body: slot.body)
        for weekday in slot.weekdays {
          let components = DateComponents(
            hour: Int(slot.hour), minute: Int(slot.minute), weekday: Int(weekday % 7 + 1))
          let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
          desired.append(UNNotificationRequest(
            identifier: "\(Self.prefix)\(slot.id).\(weekday)", content: content, trigger: trigger))
        }
      }

      let ids = Set(desired.map(\.identifier))
      let isObsolete = { (id: String) in
        id.hasPrefix(Self.prefix) && id != Self.testId && !ids.contains(id)
      }
      let pending = await center.pendingNotificationRequests().map(\.identifier)
      center.removePendingNotificationRequests(withIdentifiers: pending.filter(isObsolete))
      let delivered = await center.deliveredNotifications().map(\.request.identifier)
      center.removeDeliveredNotifications(withIdentifiers: delivered.filter(isObsolete))
      // Adding fails while notifications are off; the resume handler reapplies the schedule.
      let status = await center.notificationSettings().authorizationStatus
      if status == .denied || status == .notDetermined { return }
      var firstError: Error?
      for request in desired {
        do {
          try await center.add(request)
        } catch {
          firstError = firstError ?? error
        }
      }
      if let firstError { throw firstError }
    }
  }

  @MainActor func clear() async throws {
    try await write { [self] in
      let pending = await center.pendingNotificationRequests().map(\.identifier)
      center.removePendingNotificationRequests(withIdentifiers: pending.filter { $0.hasPrefix(Self.prefix) })
      let delivered = await center.deliveredNotifications().map(\.request.identifier)
      center.removeDeliveredNotifications(withIdentifiers: delivered.filter { $0.hasPrefix(Self.prefix) })
    }
  }

  @MainActor func showTest(title: String, body: String, channelName: String) async throws {
    try await write { [self] in
      try await center.add(UNNotificationRequest(
        identifier: Self.testId, content: content(title: title, body: body), trigger: nil))
    }
  }

  func isChannelEnabled() -> Bool { true }

  static func owns(_ notification: UNNotification) -> Bool {
    notification.request.content.userInfo["moodiary"] as? String == "reminder"
  }

  private struct Tap: Hashable {
    let identifier: String
    let date: Date
  }

  private static let tapLock = NSLock()
  private static var handled = Set<Tap>()
  private static var pendingTap = false
  private static weak var liveEvents: ReminderNotificationsEvents?

  static func receive(_ notification: UNNotification) {
    let tap = Tap(identifier: notification.request.identifier, date: notification.date)
    tapLock.withLock {
      guard handled.insert(tap).inserted else { return }
      if let liveEvents {
        Task { @MainActor in try? await liveEvents.onTap() }
      } else {
        pendingTap = true
      }
    }
  }

  func consumeLaunchTap() -> Bool {
    Self.tapLock.withLock {
      Self.liveEvents = events
      defer { Self.pendingTap = false }
      return Self.pendingTap
    }
  }

  func detach() {
    Self.tapLock.withLock {
      if Self.liveEvents === events { Self.liveEvents = nil }
    }
  }
}
