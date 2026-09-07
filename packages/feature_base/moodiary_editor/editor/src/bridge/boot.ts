import type { EditorTheme } from './theme'

export interface EditorBoot {
  platform?: 'mobile' | 'desktop'
  editable?: boolean
  placeholder?: string
  titlePlaceholder?: string
  theme?: EditorTheme | null
  saveStatus?: string
  mediaBase?: string
  fontBase?: string
  mediaInfoBase?: string
  audioDefaultName?: string
}

let cached: EditorBoot | null = null

export function readBoot(): EditorBoot {
  if (cached) return cached
  try {
    const raw = new URLSearchParams(location.search).get('boot')
    if (raw) {
      const b64 = raw.replace(/-/g, '+').replace(/_/g, '/')
      const bytes = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0))
      cached = JSON.parse(new TextDecoder().decode(bytes)) as EditorBoot
      return cached
    }
  } catch {
  }
  cached = window.__BOOT__ ?? {}
  return cached
}
