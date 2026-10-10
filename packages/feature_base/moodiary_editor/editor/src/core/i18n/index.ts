import en from '../../../../../../../i18n/web/en.json'
import zh from '../../../../../../../i18n/web/zh.json'

type Messages = typeof zh

type Leaves<T, P extends string = ''> = {
  [K in keyof T & string]: T[K] extends string ? `${P}${K}` : Leaves<T[K], `${P}${K}.`>
}[keyof T & string]

export type MessageKey = Leaves<Messages>
export type Locale = 'zh' | 'en'

const messages: Record<Locale, Messages> = { zh, en: en as Messages }

let locale: Locale = 'zh'
let intl = 'zh-CN'

// 语言只在 boot 时定一次，页面生命周期内不切换
export function setLocale(tag?: string): void {
  const en = tag?.toLowerCase().startsWith('en') ?? false
  locale = en ? 'en' : 'zh'
  intl = tag ? tag.replace('_', '-') : en ? 'en-US' : 'zh-CN'
}

export function dateLocale(): string {
  return intl
}

function lookup(table: Messages, key: string): string | undefined {
  let node: unknown = table
  for (const part of key.split('.')) {
    if (!node || typeof node !== 'object') return undefined
    node = (node as Record<string, unknown>)[part]
  }
  return typeof node === 'string' ? node : undefined
}

export function t(key: MessageKey, params?: Record<string, string | number>): string {
  const raw = lookup(messages[locale], key) ?? lookup(messages.zh, key) ?? key
  if (!params) return raw
  return raw.replace(/\{(\w+)\}/g, (match, name: string) =>
    name in params ? String(params[name]) : match,
  )
}
