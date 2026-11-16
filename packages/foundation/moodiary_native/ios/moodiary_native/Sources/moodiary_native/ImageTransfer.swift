import Flutter
import UIKit
import UniformTypeIdentifiers

final class ImageTransfer: ImageTransferApi {
  func readContentUri(uri: String) async throws -> FlutterStandardTypedData? {
    nil // Android content:// is never a valid iOS file source.
  }

  func readClipboardImage() async throws -> TransferredImage? {
    if let image = try await MainActor.run(body: { try clipboardImage() }) { return image }
    let providers = await MainActor.run { UIPasteboard.general.itemProviders }
    for provider in providers {
      guard let identifier = provider.registeredTypeIdentifiers.first(where: {
        UTType($0)?.conforms(to: .image) == true
      }), let type = UTType(identifier),
        let data = try? await ClipboardItemLoader.load(provider, type: identifier) else { continue }
      return Self.image(data, type: type, name: provider.suggestedName)
    }
    return nil
  }

  private func clipboardImage() throws -> TransferredImage? {
    let pasteboard = UIPasteboard.general
    for item in pasteboard.items {
      for (identifier, value) in item {
        guard let type = UTType(identifier), type.conforms(to: .image) else { continue }
        if let data = value as? Data {
          return Self.image(data, type: type, name: nil)
        }
        if let image = value as? UIImage, let data = image.pngData() {
          return Self.image(data, type: .png, name: nil)
        }
      }
    }
    if let image = pasteboard.image, let data = image.pngData() {
      return Self.image(data, type: .png, name: nil)
    } else if let url = pasteboard.url, url.isFileURL,
      let type = UTType(filenameExtension: url.pathExtension), type.conforms(to: .image) {
      let access = url.startAccessingSecurityScopedResource()
      defer { if access { url.stopAccessingSecurityScopedResource() } }
      return Self.image(try Data(contentsOf: url), type: type, name: url.lastPathComponent)
    } else {
      return nil
    }
  }

  private static func image(_ data: Data, type: UTType, name: String?) -> TransferredImage {
    TransferredImage(bytes: FlutterStandardTypedData(bytes: data),
      mime: type.preferredMIMEType ?? "image/png",
      name: name ?? "image.\(type.preferredFilenameExtension ?? "png")")
  }
}
