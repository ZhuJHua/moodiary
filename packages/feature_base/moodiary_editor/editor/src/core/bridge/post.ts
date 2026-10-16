export function post(type: string, payload?: unknown): void {
  window.MoodiaryEditor?.postMessage(JSON.stringify({ type, payload }))
}
