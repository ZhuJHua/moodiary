import en from '../../../../../../../i18n/web/en.json'
import zh from '../../../../../../../i18n/web/zh.json'

type Messages = typeof zh

type Leaves<T, P extends string = ''> = {
  [K in keyof T & string]: T[K] extends string ? `${P}${K}` : Leaves<T[K], `${P}${K}.`>
}[keyof T & string]

type MessageKey = Leaves<Messages>

let messages: Messages = zh

export function setLocale(languageCode: string): void {
  messages = languageCode === 'en' ? en : zh
}

export function t(key: MessageKey, params?: Record<string, string | number>): string {
  let node: unknown = messages
  for (const part of key.split('.')) node = (node as Record<string, unknown>)[part]
  const raw = node as string
  if (!params) return raw
  return raw.replace(/\{(\w+)\}/g, (_, name: string) => String(params[name]))
}
