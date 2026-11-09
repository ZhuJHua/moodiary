import AVFoundation
import Flutter
import Foundation
import UIKit
import UserNotifications

// 通知 API 的回调在系统自己的队列上执行，这里用一个带锁的盒子把结果带回调用线程
private final class NotificationResultBox<T>: @unchecked Sendable {
  private let lock = NSLock()
  private var stored: T?

  func set(_ value: T) {
    lock.lock()
    defer { lock.unlock() }
    stored = value
  }

  var value: T? {
    lock.lock()
    defer { lock.unlock() }
    return stored
  }
}

// iOS 侧靠循环播放静音音频让进程在后台继续存活；通知权限只决定常驻时的通知能否显示
final class BackgroundKeepAlive: NSObject, BackgroundKeepAliveApi {
  private var player: AVAudioPlayer?

  // Pigeon 的 HostApi 是同步调用，而通知状态是异步回调的：阻塞等一小会儿。
  // 不会死锁——getNotificationSettings / requestAuthorization 的回调在系统私有队列上
  // 执行，不排在主队列后面；即便真的超时，也只是按未授权返回，页面回前台会重新读。
  private static let notificationTimeout: TimeInterval = 2

  func isExempt() throws -> Bool {
    true
  }

  func requestExemption() throws -> Bool {
    true
  }

  func isNotificationsEnabled() throws -> Bool {
    Self.isAuthorized(Self.notificationSettings())
  }

  func requestNotifications() throws -> Bool {
    if Self.isAuthorized(Self.notificationSettings()) {
      return true
    }
    let box = NotificationResultBox<Bool>()
    let semaphore = DispatchSemaphore(value: 0)
    UNUserNotificationCenter.current()
      .requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
        box.set(granted)
        semaphore.signal()
      }
    // 系统弹窗要等用户点击，回调通常晚于这里等待的上限：超时就先当未授权，
    // 真正结果由页面回到前台时重新读状态得到。
    _ = semaphore.wait(timeout: .now() + Self.notificationTimeout)
    return box.value ?? false
  }

  func openAppSettings() throws {
    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
    UIApplication.shared.open(url)
  }

  func setSilentAudio(enabled: Bool) throws {
    if enabled {
      guard player == nil else { return }
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, options: [.mixWithOthers])
      try session.setActive(true)
      do {
        let player = try AVAudioPlayer(data: Self.silentWav())
        player.numberOfLoops = -1
        player.volume = 0
        player.play()
        self.player = player
      } catch {
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
        throw error
      }
    } else {
      player?.stop()
      player = nil
      try? AVAudioSession.sharedInstance().setActive(
        false, options: .notifyOthersOnDeactivation)
    }
  }

  private static func notificationSettings() -> UNNotificationSettings? {
    let box = NotificationResultBox<UNNotificationSettings>()
    let semaphore = DispatchSemaphore(value: 0)
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      box.set(settings)
      semaphore.signal()
    }
    _ = semaphore.wait(timeout: .now() + notificationTimeout)
    return box.value
  }

  // 静默推送（provisional）也允许发通知，一并算作已授权
  private static func isAuthorized(_ settings: UNNotificationSettings?) -> Bool {
    switch settings?.authorizationStatus {
    case .authorized?, .provisional?, .ephemeral?:
      return true
    default:
      return false
    }
  }

  // 1 秒、单声道、8 kHz、16 bit 的静音 WAV：44 字节头 + 全零采样
  private static func silentWav() -> Data {
    let sampleRate: UInt32 = 8000
    let channels: UInt16 = 1
    let bitsPerSample: UInt16 = 16
    let dataSize = sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8)
    var bytes = [UInt8]()
    bytes.reserveCapacity(44 + Int(dataSize))

    func appendU32(_ value: UInt32) {
      bytes.append(UInt8(value & 0xFF))
      bytes.append(UInt8((value >> 8) & 0xFF))
      bytes.append(UInt8((value >> 16) & 0xFF))
      bytes.append(UInt8((value >> 24) & 0xFF))
    }

    func appendU16(_ value: UInt16) {
      bytes.append(UInt8(value & 0xFF))
      bytes.append(UInt8((value >> 8) & 0xFF))
    }

    bytes.append(contentsOf: Array("RIFF".utf8))
    appendU32(36 + dataSize)
    bytes.append(contentsOf: Array("WAVE".utf8))
    bytes.append(contentsOf: Array("fmt ".utf8))
    appendU32(16)
    appendU16(1)  // PCM
    appendU16(channels)
    appendU32(sampleRate)
    appendU32(sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8))
    appendU16(channels * (bitsPerSample / 8))
    appendU16(bitsPerSample)
    bytes.append(contentsOf: Array("data".utf8))
    appendU32(dataSize)
    bytes.append(contentsOf: [UInt8](repeating: 0, count: Int(dataSize)))
    return Data(bytes)
  }
}
