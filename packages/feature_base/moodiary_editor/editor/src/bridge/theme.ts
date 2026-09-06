import { post } from './post'

export type EditorRoles = Record<string, string>

export interface EditorTheme {
  roles: EditorRoles
  dark: boolean
  font?: string
  fontV?: string
  firstLineIndent?: boolean
  fontScale?: number
}

export let isDark = false

let fontBase = ''

export function setFontBase(url: string): void {
  fontBase = url
}

const DEFAULT_SANS =
  "system-ui, -apple-system, 'Segoe UI', 'Microsoft YaHei UI', 'PingFang SC', sans-serif"

let activeFontKey = ''
let activeFontFace: FontFace | null = null

function applyFont(family?: string, version?: string): void {
  const root = document.documentElement
  const key = family && fontBase ? `${family}@${version ?? ''}` : ''
  if (key === activeFontKey) return
  activeFontKey = key
  if (activeFontFace) {
    document.fonts.delete(activeFontFace)
    activeFontFace = null
  }
  if (!family || !fontBase) {
    root.style.removeProperty('--app-font-sans')
    return
  }
  const url = `${fontBase}?v=${encodeURIComponent(version ?? family)}`
  const face = new FontFace(family, `url('${url}')`, { display: 'swap' })
  activeFontFace = face
  document.fonts.add(face)
  const esc = family.replace(/\\/g, '\\\\').replace(/'/g, "\\'")
  root.style.setProperty('--app-font-sans', `'${esc}', ${DEFAULT_SANS}`)
  face.load().then(
    () => post('fontReady'),
    () => {
      if (activeFontFace === face) {
        document.fonts.delete(face)
        activeFontFace = null
        activeFontKey = ''
      }
      post('fontReady')
    },
  )
}

export function applyTheme(theme: EditorTheme): void {
  if (!theme?.roles) return
  const root = document.documentElement
  for (const [key, value] of Object.entries(appVars(theme.roles, theme.dark))) {
    root.style.setProperty(key, value)
  }
  applyFont(theme.font, theme.fontV)
  root.style.setProperty('--app-text-indent', theme.firstLineIndent ? '2em' : '0')
  root.style.setProperty('--app-font-scale', String(theme.fontScale ?? 1))
  isDark = theme.dark
  root.setAttribute('data-theme', isDark ? 'dark' : 'light')
  root.style.colorScheme = isDark ? 'dark' : 'light'
}

const FALLBACK: Record<'light' | 'dark', string> = {
  light: '#000000',
  dark: '#ffffff',
}

function appVars(roles: EditorRoles, dark: boolean): Record<string, string> {
  const r = (key: string) => roles[key] ?? FALLBACK[dark ? 'dark' : 'light']
  return {
    '--app-background': r('surface'),
    '--app-on-background': r('onSurface'),
    '--app-surface': r('surfaceContainer'),
    '--app-surface-low': r('surfaceContainerLow'),
    '--app-on-surface': r('onSurface'),
    '--app-on-surface-variant': r('onSurfaceVariant'),
    '--app-outline': r('outlineVariant'),
    '--app-primary': r('primary'),
    '--app-on-primary': r('onPrimary'),
    '--app-secondary': r('secondaryContainer'),
    '--app-on-secondary': r('onSecondaryContainer'),
    '--app-inverse': r('inverseSurface'),
    '--app-on-inverse': r('onInverseSurface'),
    '--app-inline-code': r('onSurface'),
    '--app-error': r('error'),
    '--app-hover': r('surfaceContainerHigh'),
    '--app-selected': r('surfaceContainerHighest'),
    '--app-inline-area': r('surfaceContainerHigh'),
    '--app-text-selection': withAlpha(r('primary'), 0.3),
    '--app-scrollbar': withAlpha(r('onSurfaceVariant'), 0.4),
    '--app-scrollbar-hover': withAlpha(r('onSurfaceVariant'), 0.6),
  }
}

function withAlpha(hex: string, alpha: number): string {
  const a = Math.round(Math.min(1, Math.max(0, alpha)) * 255)
  return hex + a.toString(16).padStart(2, '0')
}
