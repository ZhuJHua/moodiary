import type { EditorBoot } from './boot'
import { applyTheme } from './theme'
import { setLocale } from '@/core/i18n'
import { editable } from '@/core/state/editable'

// 首次渲染前跑完，首帧不按 store 默认值画
export function bootstrap(boot: EditorBoot): void {
  setLocale(boot.locale)
  editable.set(boot.editable ?? true)
  if (boot.theme) applyTheme(boot.theme)
}
