// Flutter 只下发「种子色 + 明暗 + 配色变体」，本模块用 material-color-utilities 生成整套
// Material 3 配色并注入 `--app-*` CSS 变量。与 Flutter 端
// `ColorScheme.fromSeed(seed, brightness, variant).harmonized()` 同算法 / 同角色映射 / 同 error
// 调和，故编辑器配色与 App 完全一致。

import {
  Blend,
  Hct,
  MaterialDynamicColors,
  SchemeMonochrome,
  SchemeTonalSpot,
  argbFromHex,
  blueFromArgb,
  greenFromArgb,
  redFromArgb,
  type DynamicColor,
  type DynamicScheme,
} from '@material/material-color-utilities'

/** Flutter 下发的配色种子，与 Flutter 端 buildColorScheme 一一对应。 */
export interface SeedTheme {
  /** 种子色 `#RRGGBB`。 */
  seed: string
  dark: boolean
  /** 默认 tonalSpot。 */
  variant?: 'tonalSpot' | 'monochrome'
  /** -1..1，对应 material-color-utilities 的 contrastLevel（默认 0）。 */
  contrast?: number
}

export let isDark = false

export function applyTheme(theme: SeedTheme): void {
  if (!theme?.seed) return
  const scheme = buildScheme(theme)
  const root = document.documentElement
  // 编辑器自用的 --app-* token（驱动 TipTap/ProseMirror 样式，见 moodiary-editor.css）。
  for (const [key, value] of Object.entries(appVars(rolesOf(scheme)))) {
    root.style.setProperty(key, value)
  }
  isDark = theme.dark
  root.setAttribute('data-theme', isDark ? 'dark' : 'light')
  // 让原生表单控件 / 滚动条跟随明暗。
  root.style.colorScheme = isDark ? 'dark' : 'light'
  // TipTap 自身无需 JS 切主题：编辑器配色由上面在 :root 重算的整套 --app-* token 经 CSS 驱动
  // （见 ../styles/moodiary-editor.css）。data-theme 仅用于：① 代码高亮 token 的 github/github-dark
  // 两套配色切换；② colorScheme 让原生 UA 控件（滚动条 / 表单）跟随明暗。
}

function buildScheme(theme: SeedTheme): DynamicScheme {
  const source = Hct.fromInt(argbFromHex(theme.seed))
  const contrast = theme.contrast ?? 0
  return theme.variant === 'monochrome'
    ? new SchemeMonochrome(source, theme.dark, contrast)
    : new SchemeTonalSpot(source, theme.dark, contrast)
}

/** 解析整套 Material 3 角色为 `角色名(kebab) → argb`。error 朝 primary 调和，复刻 Flutter 的 harmonized()。 */
function rolesOf(scheme: DynamicScheme): Record<string, number> {
  const M = MaterialDynamicColors
  const v = (c: DynamicColor) => c.getArgb(scheme)
  const primary = v(M.primary)
  return {
    'primary': primary,
    'on-primary': v(M.onPrimary),
    'secondary-container': v(M.secondaryContainer),
    'on-secondary-container': v(M.onSecondaryContainer),
    'error': Blend.harmonize(v(M.error), primary),
    'surface': v(M.surface),
    'on-surface': v(M.onSurface),
    'on-surface-variant': v(M.onSurfaceVariant),
    'surface-container-low': v(M.surfaceContainerLow),
    'surface-container': v(M.surfaceContainer),
    'surface-container-high': v(M.surfaceContainerHigh),
    'surface-container-highest': v(M.surfaceContainerHighest),
    'inverse-surface': v(M.inverseSurface),
    'inverse-on-surface': v(M.inverseOnSurface),
    'outline-variant': v(M.outlineVariant),
  }
}

/** `--app-*` 用「编辑器视角」映射 M3 角色（注意 background 取 surface、surface 取 surfaceContainer）。 */
function appVars(roles: Record<string, number>): Record<string, string> {
  const r = (key: string) => roles[key]
  return {
    '--app-background': rgbHex(r('surface')),
    '--app-on-background': rgbHex(r('on-surface')),
    '--app-surface': rgbHex(r('surface-container')),
    '--app-surface-low': rgbHex(r('surface-container-low')),
    '--app-on-surface': rgbHex(r('on-surface')),
    '--app-on-surface-variant': rgbHex(r('on-surface-variant')),
    '--app-outline': rgbHex(r('outline-variant')),
    '--app-primary': rgbHex(r('primary')),
    '--app-on-primary': rgbHex(r('on-primary')),
    '--app-secondary': rgbHex(r('secondary-container')),
    '--app-on-secondary': rgbHex(r('on-secondary-container')),
    '--app-inverse': rgbHex(r('inverse-surface')),
    '--app-on-inverse': rgbHex(r('inverse-on-surface')),
    '--app-inline-code': rgbHex(r('error')),
    '--app-error': rgbHex(r('error')),
    '--app-hover': rgbHex(r('surface-container-high')),
    '--app-selected': rgbHex(r('surface-container-highest')),
    '--app-inline-area': rgbHex(r('surface-container-high')),
    // 半透明色：与 Flutter 端一致（选区高亮 primary@30%、滚动条 onSurfaceVariant@40/60%）。
    '--app-text-selection': rgbaHex(r('primary'), 0.3),
    '--app-scrollbar': rgbaHex(r('on-surface-variant'), 0.4),
    '--app-scrollbar-hover': rgbaHex(r('on-surface-variant'), 0.6),
  }
}

function rgbHex(argb: number): string {
  return (
    '#' +
    toHex2(redFromArgb(argb)) +
    toHex2(greenFromArgb(argb)) +
    toHex2(blueFromArgb(argb))
  )
}

/** `#RRGGBBAA`：给需要半透明的注入色用（WebKit / Chromium 均支持 8 位 hex）。 */
function rgbaHex(argb: number, alpha: number): string {
  const a = Math.round(Math.min(1, Math.max(0, alpha)) * 255)
  return rgbHex(argb) + toHex2(a)
}

function toHex2(n: number): string {
  return n.toString(16).padStart(2, '0')
}
