import { createStore } from '@/lib/store'
import { editable } from './editable'

const DURATION = 4000

export const undoToast = createStore<{ message: string; visible: boolean }>({
  message: '',
  visible: false,
})

let action: (() => void) | null = null
let timer = 0

export function showUndoToast(message: string, onUndo: () => void): void {
  window.clearTimeout(timer)
  undoToast.set({ message, visible: true })
  action = onUndo
  timer = window.setTimeout(hideUndoToast, DURATION)
}

export function hideUndoToast(): void {
  window.clearTimeout(timer)
  if (undoToast.get().visible) undoToast.patch({ visible: false })
  action = null
}

editable.subscribe(() => {
  if (!editable.get()) hideUndoToast()
})

export function runUndoToast(): void {
  const fn = action
  hideUndoToast()
  fn?.()
}
