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
import { post } from './post'

/** Flutter 下发的配色种子，与 Flutter 端 buildColorScheme 一一对应。 */
export interface SeedTheme {
  /** 种子色 `#RRGGBB`。 */
  seed: string
  dark: boolean
  /** 默认 tonalSpot。 */
  variant?: 'tonalSpot' | 'monochrome'
  /** -1..1，对应 material-color-utilities 的 contrastLevel（默认 0）。 */
  contrast?: number
  /** App 当前自定义字体家族名；缺省 / 空表示系统字体（用 CSS 兜底字体栈）。 */
  font?: string
  /** 字体文件版本串（family + mtime），作字体 URL 的破缓存参数；缺省退回 family。 */
  fontV?: string
  /** 全局「首行缩进」：true 时正文段落首行缩进 2 字符（经 --app-text-indent 驱动 CSS）。 */
  firstLineIndent?: boolean
  /** 全局「字号」缩放（1.0 = 标准），经 --app-font-scale 缩放正文/标题根字号。 */
  fontScale?: number
}

export let isDark = false

/** 字体文件 URL（boot.fontBase，随机端口 + token），作 @font-face 的 src；boot 时经 [setFontBase] 注入。 */
let fontBase = ''

export function setFontBase(url: string): void {
  fontBase = url
}

// 与 moodiary-editor.css `:root` 的 --app-font-sans 兜底一致：system-ui 领头以跟随系统当前
// 默认字体（OEM 换字体经它生效），故不显式写 Roboto（sans-serif 已覆盖，写死反而钉在原生 Roboto）。
const DEFAULT_SANS =
  "system-ui, -apple-system, 'Segoe UI', 'Microsoft YaHei UI', 'PingFang SC', sans-serif"

let activeFontKey = ''
let activeFontFace: FontFace | null = null

/**
 * 应用 App 自定义字体：家族名有值且 fontBase 就绪时，用 FontFace API 注册并**立即** load
 * （@font-face 是惰性加载，要等首个用到该 family 的文本渲染才发请求，抢不回加载窗口），并把
 * --app-font-sans 置为「自定义字体, 系统兜底栈」；加载成败都 post('fontReady')，Flutter 据此
 * 在撤加载遮罩前等字体就绪（带超时兜底），避免露出兜底字体后整篇换脸闪动。
 * 否则移除注册与内联 --app-font-sans，回落到 :root 的系统字体栈。
 * 不声明 font-weight，静态 / 可变字体的加粗都交给浏览器合成，避免可变字体单一 face 吃掉粗体。
 */
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
      // 加载失败：撤注册并清 key，让下一次主题推送重试（否则本 webview 生命周期内永远兜底字体）。
      if (activeFontFace === face) {
        document.fonts.delete(face)
        activeFontFace = null
        activeFontKey = ''
      }
      post('fontReady')
    },
  )
}

export function applyTheme(theme: SeedTheme): void {
  if (!theme?.seed) return
  const scheme = buildScheme(theme)
  const root = document.documentElement
  // 编辑器自用的 --app-* token（驱动 TipTap/ProseMirror 样式，见 moodiary-editor.css）。
  for (const [key, value] of Object.entries(appVars(rolesOf(scheme)))) {
    root.style.setProperty(key, value)
  }
  applyFont(theme.font, theme.fontV)
  // 首行缩进：置 --app-text-indent（moodiary-editor.css 里顶层段落 `> p` 读它）。2em ≈ 2 字符，
  // 与旧版 Quill text_indent 值 "2" 对齐；关闭时置 0。
  root.style.setProperty('--app-text-indent', theme.firstLineIndent ? '2em' : '0')
  // 字号：置 --app-font-scale（正文/标题根字号 calc 读它，em 层级自动跟随）。
  root.style.setProperty('--app-font-scale', String(theme.fontScale ?? 1))
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
