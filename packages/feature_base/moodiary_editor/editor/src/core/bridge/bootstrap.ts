import { readBoot } from './boot'
import { installBridge } from './index'
import { applyTheme, setFontBase } from './theme'
import { setMediaInfoPrefix, setMediaPrefix } from '@/core/editor/media'
import { setLocale } from '@/core/i18n'
import { editable } from '@/core/state/editable'

// 首次渲染前跑完，首帧不按 store 默认值画
export function bootstrap(): void {
  const boot = readBoot()
  if (boot.mediaBase) setMediaPrefix(boot.mediaBase)
  if (boot.mediaInfoBase) setMediaInfoPrefix(boot.mediaInfoBase)
  // 字体文件基址须先于 applyTheme 注入：applyTheme 里用它拼 @font-face 的 src
  if (boot.fontBase) setFontBase(boot.fontBase)
  setLocale(boot.locale)
  editable.set(boot.editable ?? true)
  installBridge()
  if (boot.theme) applyTheme(boot.theme)
}
