import { ref } from 'vue'

export const title = ref('')

export function setTitle(value: string): void {
  title.value = value ?? ''
}

let focusHandler: (() => void) | null = null

export function registerTitleFocus(handler: (() => void) | null): void {
  focusHandler = handler
}

export function focusTitle(): void {
  focusHandler?.()
}
