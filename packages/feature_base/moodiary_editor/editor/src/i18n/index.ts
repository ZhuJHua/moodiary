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

export function setLocale(locale?: string): void {
  i18n.global.locale.value = locale?.toLowerCase().startsWith('en') ? 'en' : 'zh'
}
