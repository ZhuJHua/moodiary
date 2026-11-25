import Foundation

// UIPasteboard may vend promised items (Photos, Safari) whose synchronous
// representation is nil. Keep the provider alive until its data is delivered.
enum ClipboardItemLoader {
  static func load(_ provider: NSItemProvider, type: String) async throws -> Data? {
    try await withCheckedThrowingContinuation { continuation in
      provider.loadDataRepresentation(forTypeIdentifier: type) { data, error in
        if let error { continuation.resume(throwing: error) }
        else { continuation.resume(returning: data) }
      }
    }
  }

  static func text(_ data: Data) -> String? {
    if data.starts(with: [0xff, 0xfe]) || data.starts(with: [0xfe, 0xff]) {
      return String(data: data, encoding: .utf16)
    }
    return String(data: data, encoding: .utf8)
  }
}
