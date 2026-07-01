// JS → Flutter 事件。四端统一经 `window.MoodiaryEditor.postMessage(string)`：该对象由 Flutter
// 注入的 DOCUMENT_START shim 提供（转发到 flutter_inappwebview 的 callHandler，见
// moodiary_editor.dart 的 _bridgeShim）。
export function post(type: string, payload?: unknown): void {
  try {
    window.MoodiaryEditor?.postMessage(JSON.stringify({ type, payload }))
  } catch {
    /* no-op */
  }
}
