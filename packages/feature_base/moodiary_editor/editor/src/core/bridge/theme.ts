import { post } from './post'

export interface EditorTheme {
  roles: Record<string, string>
  dark: boolean
  font?: string
  fontUrl?: string
  fontV?: string
  firstLineIndent: boolean
  fontScale: number
}

const DEFAULT_SANS =
  "system-ui, -apple-system, 'Segoe UI', 'Microsoft YaHei UI', 'PingFang SC', sans-serif"

const ROLE_VARS: Record<string, string> = {
  surface: '--app-surface',
  onSurface: '--app-on-surface',
  onSurfaceVariant: '--app-on-surface-variant',
  surfaceContainerLow: '--app-surface-container-low',
  surfaceContainer: '--app-surface-container',
  surfaceContainerHigh: '--app-surface-container-high',
  surfaceContainerHighest: '--app-surface-container-highest',
  primary: '--app-primary',
  onPrimary: '--app-on-primary',
  secondaryContainer: '--app-secondary-container',
  onSecondaryContainer: '--app-on-secondary-container',
  inverseSurface: '--app-inverse-surface',
  onInverseSurface: '--app-on-inverse-surface',
  outlineVariant: '--app-outline-variant',
  error: '--app-error',
}

let activeFontKey = ''
let activeFontFace: FontFace | null = null

function applyFont(family?: string, url?: string, version?: string): void {
  const root = document.documentElement
  const key = family && url ? `${family}@${version ?? ''}` : ''
  if (key === activeFontKey) return
  activeFontKey = key
  if (activeFontFace) {
    document.fonts.delete(activeFontFace)
    activeFontFace = null
  }
  if (!family || !url) {
    root.style.removeProperty('--app-font-sans')
    return
  }
  // file:// 地址不能带 query：iOS 会把 ?v= 当成文件名的一部分
  const face = new FontFace(family, `url("${url}")`, { display: 'swap' })
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
  const root = document.documentElement
  for (const [role, cssVar] of Object.entries(ROLE_VARS)) {
    root.style.setProperty(cssVar, theme.roles[role])
  }
  // 47 = 0.28 不透明度；角色色恒为 #rrggbb
  root.style.setProperty('--app-selection', `${theme.roles.primary}47`)
  applyFont(theme.font, theme.fontUrl, theme.fontV)
  root.style.setProperty('--app-text-indent', theme.firstLineIndent ? '2em' : '0')
  root.style.setProperty('--app-font-scale', String(theme.fontScale))
  root.setAttribute('data-theme', theme.dark ? 'dark' : 'light')
  root.style.colorScheme = theme.dark ? 'dark' : 'light'
}
