import { describe, expect, it } from 'vitest'
import { i18n, setLocale } from './index'

describe('editor i18n', () => {
  it('interpolates named params', () => {
    setLocale('zh')
    expect(i18n.global.t('wordCount', { count: 12 })).toBe('12 字')
  })

  it('switches locale from the boot payload', () => {
    setLocale('en-US')
    expect(i18n.global.t('code.copy')).toBe('Copy')
    setLocale(undefined)
    expect(i18n.global.t('code.copy')).toBe('复制')
  })
})
