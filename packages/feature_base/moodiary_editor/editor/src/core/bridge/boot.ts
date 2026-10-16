import { setLocale } from '@/core/i18n'
import { modeStore } from '@/core/state/editable'
import { applyTheme, type EditorTheme } from './theme'

export interface EditorBoot {
  editable: boolean
  locale: string
  theme: EditorTheme
}

export function bootstrap(boot: EditorBoot): void {
  setLocale(boot.locale)
  modeStore.setState({ editable: boot.editable })
  applyTheme(boot.theme)
}
