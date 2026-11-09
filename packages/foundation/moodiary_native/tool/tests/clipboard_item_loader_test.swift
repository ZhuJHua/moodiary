import Foundation

@main
struct ClipboardItemLoaderTest {
  static func main() async throws {
    let html = Data("<p><strong>promised HTML</strong></p>".utf8)
    let image = Data([137, 80, 78, 71, 13, 10, 26, 10])
    for (type, expected) in [("public.html", html), ("public.png", image)] {
      let provider = NSItemProvider()
      provider.registerDataRepresentation(forTypeIdentifier: type, visibility: .all) { completion in
        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(20)) {
          completion(expected, nil)
        }
        return nil
      }
      let actual = try await ClipboardItemLoader.load(provider, type: type)
      precondition(actual == expected, "Promised representation was not awaited")
    }
    let failing = NSItemProvider()
    failing.registerDataRepresentation(forTypeIdentifier: "public.html", visibility: .all) { completion in
      completion(nil, NSError(domain: "clipboard-test", code: 42))
      return nil
    }
    do {
      _ = try await ClipboardItemLoader.load(failing, type: "public.html")
      preconditionFailure("Provider errors must propagate")
    } catch { }
    precondition(ClipboardItemLoader.text(Data([0xff, 0xfe, 0x41, 0])) == "A")
    precondition(ClipboardItemLoader.text(html) == String(data: html, encoding: .utf8))
    print("ClipboardItemLoader: promised HTML/image, provider errors and UTF-16 passed")
  }
}
