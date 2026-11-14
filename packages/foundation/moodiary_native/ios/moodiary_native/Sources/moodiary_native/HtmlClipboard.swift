import Flutter
import UIKit
import UniformTypeIdentifiers

final class HtmlClipboard: HtmlClipboardApi {
  func read() async throws -> HtmlClipboardContent? {
    let immediate = await MainActor.run { () -> HtmlClipboardContent? in
      let board = UIPasteboard.general
      let html = board.data(forPasteboardType: "public.html").flatMap(ClipboardItemLoader.text)
        ?? board.value(forPasteboardType: "public.html") as? String
      return html != nil || board.hasStrings ? HtmlClipboardContent(text: board.string ?? "", html: html) : nil
    }
    if immediate?.html != nil { return immediate }
    let providers = await MainActor.run { UIPasteboard.general.itemProviders }
    var plain = immediate?.text ?? ""
    for provider in providers {
      if let type = provider.registeredTypeIdentifiers.first(where: {
        UTType($0)?.conforms(to: .plainText) == true
      }), let data = try? await ClipboardItemLoader.load(provider, type: type) {
        plain = ClipboardItemLoader.text(data) ?? plain
      }
      if provider.hasItemConformingToTypeIdentifier("public.html"),
        let data = try? await ClipboardItemLoader.load(provider, type: "public.html"),
        let html = ClipboardItemLoader.text(data) {
        return HtmlClipboardContent(text: plain, html: html)
      }
    }
    return plain.isEmpty ? immediate : HtmlClipboardContent(text: plain, html: nil)
  }

  func write(content: HtmlClipboardContent) throws {
    var item: [String: Any] = ["public.utf8-plain-text": content.text]
    if let html = content.html { item["public.html"] = Data(html.utf8) }
    UIPasteboard.general.items = [item]
  }
}
