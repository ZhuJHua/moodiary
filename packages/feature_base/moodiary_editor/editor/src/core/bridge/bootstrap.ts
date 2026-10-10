import { readBoot, type Platform } from './boot'
import { installBridge } from './index'
import { applyTheme, setFontBase } from './theme'
import { setMediaInfoPrefix, setMediaPrefix } from '@/core/editor/media'
import { setLocale } from '@/core/i18n'
import { editable } from '@/core/state/editable'

// 首次渲染前跑完：壳层拿到的 store 已是 Flutter 下发的值，不会先按默认值画一帧
export function bootstrap(): { platform: Platform } {
  const boot = readBoot()
  if (boot.mediaBase) setMediaPrefix(boot.mediaBase)
  if (boot.mediaInfoBase) setMediaInfoPrefix(boot.mediaInfoBase)
  // 字体文件基址须先于 applyTheme 注入：applyTheme 里用它拼 @font-face 的 src
  if (boot.fontBase) setFontBase(boot.fontBase)
  setLocale(boot.locale)
  editable.set(boot.editable ?? true)
  installBridge()
  if (boot.theme) applyTheme(boot.theme)
  return { platform: boot.platform ?? 'desktop' }
}
