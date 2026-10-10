import { post } from '@/core/bridge/post'

export interface Overlay {
  dismiss(): void
}

const stack: Overlay[] = []

export function openOverlay(overlay: Overlay): void {
  if (stack.includes(overlay)) return
  stack.push(overlay)
  post('overlay', true)
}

export function closeOverlay(overlay: Overlay): void {
  const i = stack.indexOf(overlay)
  if (i < 0) return
  stack.splice(i, 1)
  post('overlay', stack.length > 0)
}

export function dismissOverlay(): void {
  stack[stack.length - 1]?.dismiss()
}
