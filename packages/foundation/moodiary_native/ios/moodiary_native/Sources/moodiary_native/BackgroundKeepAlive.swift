import Foundation
import UIKit

// iOS 侧不做后台保活：MCP 只在 App 处于前台时对外提供接口。
//
// 之前靠循环播放静音音频撑住后台执行权，代价是整个 App 声明 UIBackgroundModes: audio
// （后台音频的审核风险），而且要接管全局 AVAudioSession —— 会与 App 自己的录音、
// 媒体播放互相打断。现在 setKeepAlive 保留成 no-op，后台保活只由安卓的前台服务提供。
final class BackgroundKeepAlive: NSObject, BackgroundKeepAliveApi {
  // 安卓专属的权限接口：iOS 没有对应的系统限制，按“已满足”返回即可
  func isExempt() throws -> Bool {
    true
  }

  func requestExemption() throws -> Bool {
    true
  }

  func isNotificationsEnabled() throws -> Bool {
    true
  }

  func requestNotifications() throws -> Bool {
    true
  }

  func openAppSettings() throws {
    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
    UIApplication.shared.open(url)
  }

  // 签名由 pigeon 的 HostApi 两平台共享，所以保留；iOS 上没有对应的后台保活机制，
  // App 离开前台后 MCP 端口不可达，通知文案参数在 iOS 也没有意义，因此这里什么都不做。
  func setKeepAlive(
    enabled: Bool,
    notificationTitle: String,
    notificationText: String
  ) throws {}
}
