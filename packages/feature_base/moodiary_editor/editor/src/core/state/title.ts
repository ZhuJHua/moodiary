import { createStore } from 'zustand/vanilla'

export const titleStore = createStore(() => ({ title: '' }))

export function setTitle(value: string): void {
  titleStore.setState({ title: value })
}

let focusHandler: (() => void) | null = null

export function registerTitleFocus(handler: (() => void) | null): void {
  focusHandler = handler
}

export function focusTitle(): void {
  focusHandler?.()
}
