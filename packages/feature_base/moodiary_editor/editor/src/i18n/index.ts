import messages from '@intlify/unplugin-vue-i18n/messages'
import { createI18n } from 'vue-i18n'

type MessageSchema = typeof import('../../../../../../i18n/web/zh.json')

declare module 'vue-i18n' {
  export interface DefineLocaleMessage extends MessageSchema {}
}

export const i18n = createI18n({
  legacy: false,
  locale: 'zh',
  fallbackLocale: 'zh',
  messages,
})

let intlLocale = 'zh-CN'

export function setLocale(locale?: string): void {
  const en = locale?.toLowerCase().startsWith('en') ?? false
  i18n.global.locale.value = en ? 'en' : 'zh'
  intlLocale = locale ? locale.replace('_', '-') : en ? 'en-US' : 'zh-CN'
}

export function dateLocale(): string {
  return intlLocale
}
