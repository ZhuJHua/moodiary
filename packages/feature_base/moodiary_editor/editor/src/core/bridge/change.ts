import { post } from './post'

export const CHANGE_DEBOUNCE_MS = 300

let read: (() => string) | null = null
let timer: ReturnType<typeof setTimeout> | undefined

export function scheduleChange(serialize: () => string): void {
  read = serialize
  clearTimeout(timer)
  timer = setTimeout(flushChange, CHANGE_DEBOUNCE_MS)
}

export function flushChange(): void {
  clearTimeout(timer)
  timer = undefined
  const serialize = read
  read = null
  if (serialize) post('change', serialize())
}

export function cancelChange(): void {
  clearTimeout(timer)
  timer = undefined
  read = null
}

export function installChangeFlushers(): void {
  window.addEventListener('pagehide', flushChange)
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'hidden') flushChange()
  })
}
