// Flutter 下发**已解析好的 Material 3 角色色表**，本模块只把它铺成 `--app-*` CSS 变量。
//
// 早先的协议是下发种子色 + 变体名，由这里用 material-color-utilities 再生成一遍配色。
// 那等于两端各跑一套算法：宿主侧的灰阶覆盖（NeutralRamp）根本传不过去，而且两边的
// MCU 版本一漂（web 侧 0.4.0 / Flutter 侧 0.13.0）就会静默不一致，没有任何测试能发现。
// 现在 ColorScheme 是唯一真源。

import { post } from './post'

/** Flutter 下发的角色色表，键名与宿主 `ThemeManager.editorRoles` 一一对应。 */
export type EditorRoles = Record<string, string>

export interface EditorTheme {
  /** `{角色名: '#RRGGBB'}`。缺失的角色由 [FALLBACK] 兜底。 */
  roles: EditorRoles
  /** 还要单独给：它另外驱动 data-theme、color-scheme 与代码高亮的亮暗切换。 */
  dark: boolean
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

export function applyTheme(theme: EditorTheme): void {
  if (!theme?.roles) return
  const root = document.documentElement
  // 编辑器自用的 --app-* token（驱动 TipTap/ProseMirror 样式，见 moodiary-editor.css）。
  for (const [key, value] of Object.entries(appVars(theme.roles, theme.dark))) {
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

/** 宿主漏给某个角色时的兜底，只为不让变量变成空串导致 CSS 整条声明失效。 */
const FALLBACK: Record<'light' | 'dark', string> = {
  light: '#000000',
  dark: '#ffffff',
}

/** `--app-*` 用「编辑器视角」映射 M3 角色（注意 background 取 surface、surface 取 surfaceContainer）。 */
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
    // 行内代码走正文墨色而不是 error：无彩主题下一段红字读起来像报错。
    '--app-inline-code': r('onSurface'),
    '--app-error': r('error'),
    '--app-hover': r('surfaceContainerHigh'),
    '--app-selected': r('surfaceContainerHighest'),
    '--app-inline-area': r('surfaceContainerHigh'),
    // 半透明色：与 Flutter 端一致（选区高亮 primary@30%、滚动条 onSurfaceVariant@40/60%）。
    '--app-text-selection': withAlpha(r('primary'), 0.3),
    '--app-scrollbar': withAlpha(r('onSurfaceVariant'), 0.4),
    '--app-scrollbar-hover': withAlpha(r('onSurfaceVariant'), 0.6),
  }
}

/** `#RRGGBB` → `#RRGGBBAA`（WebKit / Chromium 均支持 8 位 hex）。 */
function withAlpha(hex: string, alpha: number): string {
  const a = Math.round(Math.min(1, Math.max(0, alpha)) * 255)
  return hex + a.toString(16).padStart(2, '0')
}
