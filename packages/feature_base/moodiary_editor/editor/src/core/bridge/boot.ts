import type { EditorTheme } from './theme'

export interface EditorBoot {
  editable?: boolean
  locale?: string
  theme?: EditorTheme | null
}
