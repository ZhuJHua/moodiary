import type { SeedTheme } from './theme'

/** Flutter 注入的引导数据：挂在页面 URL 的 `?boot=<base64url(JSON)>` 上（同步可读，首帧即用）。 */
export interface EditorBoot {
  platform?: 'mobile' | 'desktop'
  editable?: boolean
  placeholder?: string
  theme?: SeedTheme | null
  /** 本篇自动保存状态初值：'saving' / 'saved' / 'failed' / 'idle'（驱动编辑器右下角气泡）。 */
  saveStatus?: string
  /** 本地媒体服务 URL 前缀（随机端口 + token，每次启动不同），如 `http://127.0.0.1:PORT/<token>/media/`。 */
  mediaBase?: string
  /** 自定义字体文件 URL（同一本地服务），作 @font-face 的 src；随主题里的 font 家族名一起用。 */
  fontBase?: string
}

let cached: EditorBoot | null = null

/**
 * 读取引导数据：URL `?boot=` 为主（本地回环 HTTP 加载，四端一致）；兼容旧的
 * DOCUMENT_START 注入 `window.__BOOT__` 作兜底。缺省返回 {}（页面仍可用，仅无主题 / 桌面态）。
 */
export function readBoot(): EditorBoot {
  if (cached) return cached
  try {
    const raw = new URLSearchParams(location.search).get('boot')
    if (raw) {
      // base64url → base64；atob 为 forgiving-base64，无填充也可解。UTF-8 经 TextDecoder 还原
      // （placeholder 等字段可能含中文）。
      const b64 = raw.replace(/-/g, '+').replace(/_/g, '/')
      const bytes = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0))
      cached = JSON.parse(new TextDecoder().decode(bytes)) as EditorBoot
      return cached
    }
  } catch {
    /* fall through */
  }
  cached = window.__BOOT__ ?? {}
  return cached
}
