import { createStore } from '../lib/store'

export const title = createStore('')

export function setTitle(value: string): void {
  title.set(value ?? '')
}

let focusHandler: (() => void) | null = null

export function registerTitleFocus(handler: (() => void) | null): void {
  focusHandler = handler
}

export function focusTitle(): void {
  focusHandler?.()
}
