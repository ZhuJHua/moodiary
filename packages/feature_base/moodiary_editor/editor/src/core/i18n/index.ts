import en from '../../../../../../../i18n/web/en.json'
import zh from '../../../../../../../i18n/web/zh.json'
import { createStore, useStore } from '@/lib/store'

type Messages = typeof zh

type Leaves<T, P extends string = ''> = {
  [K in keyof T & string]: T[K] extends string ? `${P}${K}` : Leaves<T[K], `${P}${K}.`>
}[keyof T & string]

export type MessageKey = Leaves<Messages>
export type Locale = 'zh' | 'en'

const messages: Record<Locale, Messages> = { zh, en: en as Messages }

export const localeStore = createStore<{ locale: Locale; intl: string }>({
  locale: 'zh',
  intl: 'zh-CN',
})

export function setLocale(locale?: string): void {
  const en = locale?.toLowerCase().startsWith('en') ?? false
  localeStore.set({
    locale: en ? 'en' : 'zh',
    intl: locale ? locale.replace('_', '-') : en ? 'en-US' : 'zh-CN',
  })
}

export function dateLocale(): string {
  return localeStore.get().intl
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
  const { locale } = localeStore.get()
  const raw = lookup(messages[locale], key) ?? lookup(messages.zh, key) ?? key
  if (!params) return raw
  return raw.replace(/\{(\w+)\}/g, (match, name: string) =>
    name in params ? String(params[name]) : match,
  )
}

export function useT(): typeof t {
  useStore(localeStore, (s) => s.locale)
  return t
}
