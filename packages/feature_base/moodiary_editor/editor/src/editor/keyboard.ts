export function dismissKeyboard(): void {
  const el = document.activeElement
  if (el instanceof HTMLElement) el.blur()
}
