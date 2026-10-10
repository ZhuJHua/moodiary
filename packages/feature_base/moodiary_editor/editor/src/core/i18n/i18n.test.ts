import { describe, expect, it } from 'vitest'
import { setLocale, t } from './index'

describe('editor i18n', () => {
  it('interpolates named params', () => {
    setLocale('zh')
    expect(t('wordCount', { count: 12 })).toBe('12 字')
  })

  it('switches locale from the boot payload', () => {
    setLocale('en-US')
    expect(t('code.copy')).toBe('Copy')
    setLocale(undefined)
    expect(t('code.copy')).toBe('复制')
  })
})
