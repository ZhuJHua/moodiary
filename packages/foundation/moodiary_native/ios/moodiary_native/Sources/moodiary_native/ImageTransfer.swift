import Flutter
import UIKit
import UniformTypeIdentifiers

final class ImageTransfer: NSObject, ImageTransferApi, UIDropInteractionDelegate {
  private weak var registrar: FlutterPluginRegistrar?
  private weak var dropView: UIView?
  private var interaction: UIDropInteraction?
  private var target: Int64?
  private var bounds = CGRect.zero
  private let client: ImageTransferClient

  init(registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
    client = ImageTransferClient(binaryMessenger: registrar.messenger())
    super.init()
  }

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

  func setDropTarget(target: Int64, left: Double, top: Double, width: Double, height: Double) throws {
    self.target = target
    bounds = CGRect(x: left, y: top, width: width, height: height)
    guard let view = registrar?.viewController?.view else { return }
    if dropView !== view {
      if let interaction { dropView?.removeInteraction(interaction) }
      let interaction = UIDropInteraction(delegate: self)
      interaction.allowsSimultaneousDropSessions = false
      view.addInteraction(interaction)
      self.interaction = interaction
      dropView = view
    }
  }

  func clearDropTarget(target: Int64) throws {
    guard self.target == target else { return }
    self.target = nil
    if let interaction { dropView?.removeInteraction(interaction) }
    interaction = nil
    dropView = nil
  }

  func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
    target != nil && session.hasItemsConforming(toTypeIdentifiers: [UTType.image.identifier])
  }

  func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
    let point = session.location(in: interaction.view!)
    return UIDropProposal(operation: bounds.contains(point) ? .copy : .forbidden)
  }

  func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
    guard let id = target, let view = interaction.view else { return }
    let point = session.location(in: view)
    guard bounds.contains(point) else { return }
    let group = DispatchGroup()
    var images = [Int: TransferredImage]()
    for (index, item) in session.items.enumerated() {
      let provider = item.itemProvider
      guard let identifier = provider.registeredTypeIdentifiers.first(where: {
        UTType($0)?.conforms(to: .image) == true
      }), let type = UTType(identifier) else { continue }
      group.enter()
      // File representations cover image files from Files and promised iCloud
      // assets as well as images from Photos/Safari. Consume temporary URLs here.
      provider.loadFileRepresentation(forTypeIdentifier: identifier) { url, _ in
        let data = url.flatMap { try? Data(contentsOf: $0) }
        DispatchQueue.main.async {
          if let data {
            images[index] = Self.image(data, type: type, name: provider.suggestedName)
          }
          group.leave()
        }
      }
    }
    group.notify(queue: .main) { [weak self] in
      guard let self, self.target == id, !images.isEmpty else { return }
      let drop = ImageDrop(target: id, x: point.x, y: point.y,
        images: images.keys.sorted().compactMap { images[$0] })
      Task { @MainActor in try? await self.client.onDrop(drop: drop) }
    }
  }
}
