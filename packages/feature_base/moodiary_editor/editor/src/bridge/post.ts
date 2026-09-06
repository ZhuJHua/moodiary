export function post(type: string, payload?: unknown): void {
  try {
    window.MoodiaryEditor?.postMessage(JSON.stringify({ type, payload }))
  } catch {
  }
}
