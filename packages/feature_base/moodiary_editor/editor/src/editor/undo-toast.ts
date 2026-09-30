import { reactive } from 'vue'

const DURATION = 4000

export const undoToast = reactive<{ message: string; visible: boolean }>({
  message: '',
  visible: false,
})

let action: (() => void) | null = null
let timer = 0

export function showUndoToast(message: string, onUndo: () => void): void {
  window.clearTimeout(timer)
  undoToast.message = message
  undoToast.visible = true
  action = onUndo
  timer = window.setTimeout(hideUndoToast, DURATION)
}

export function hideUndoToast(): void {
  window.clearTimeout(timer)
  undoToast.visible = false
  action = null
}

export function runUndoToast(): void {
  const fn = action
  hideUndoToast()
  fn?.()
}
