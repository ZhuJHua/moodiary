import AVFoundation
import Flutter

// iOS 侧靠循环播放静音音频让进程在后台继续存活
final class BackgroundKeepAlive: NSObject, BackgroundKeepAliveApi {
  private var player: AVAudioPlayer?

  func isExempt() throws -> Bool {
    true
  }

  func requestExemption() throws -> Bool {
    true
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
