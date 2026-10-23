import { describe, expect, it } from 'vitest'
import en from '../../../../../../../i18n/web/en.json'
import zh from '../../../../../../../i18n/web/zh.json'
import { setLocale, t } from '.'

const keys = (node: unknown, prefix = ''): string[] =>
  Object.entries(node as Record<string, unknown>).flatMap(([k, v]) =>
    typeof v === 'string' ? [`${prefix}${k}`] : keys(v, `${prefix}${k}.`),
  )

describe('web strings', () => {
  it('zh and en carry the same keys', () => {
    expect(keys(en).sort()).toEqual(keys(zh).sort())
  })

  it('switches by locale and fills parameters', () => {
    setLocale('en')
    expect(t('wordCount', { count: 3 })).toBe('3 characters')
    setLocale('zh')
    expect(t('wordCount', { count: 3 })).toBe('3 字')
  })
})
