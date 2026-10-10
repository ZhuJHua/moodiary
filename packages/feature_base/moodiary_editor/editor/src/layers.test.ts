import { describe, expect, it } from 'vitest'

const ALLOWED: Record<string, string[]> = {
  lib: ['lib'],
  core: ['lib', 'core'],
  ui: ['lib', 'core', 'ui'],
  shell: ['lib', 'core', 'ui', 'shell'],
}

const sources = import.meta.glob<string>('./**/*.{ts,tsx}', {
  query: '?raw',
  import: 'default',
  eager: true,
})

const SPECIFIER = /(?:from|import)\s*\(?\s*['"]([^'"]+)['"]/g

// 相对路径按 import 方的目录折算到 src 下的顶层目录；越出 src 的（仓库根 i18n json）不属任何层
function layerOf(importer: string, spec: string): string | null {
  if (spec.startsWith('@/')) return spec.slice(2).split('/')[0]
  if (!spec.startsWith('.')) return null
  const parts = importer.split('/').slice(0, -1)
  for (const seg of spec.split('/')) {
    if (seg === '..') parts.pop()
    else if (seg !== '.') parts.push(seg)
  }
  return parts.length > 0 ? parts[0] : null
}

describe('editor layers', () => {
  it('no layer imports upward', () => {
    const violations: string[] = []
    for (const [path, text] of Object.entries(sources)) {
      if (/\.test\.tsx?$/.test(path)) continue
      const rel = path.replace(/^\.\//, '')
      const allowed = ALLOWED[rel.split('/')[0]]
      if (!allowed) continue
      for (const m of text.matchAll(SPECIFIER)) {
        const target = layerOf(rel, m[1])
        if (target && target in ALLOWED && !allowed.includes(target)) {
          violations.push(`${rel} -> ${m[1]}`)
        }
      }
    }
    expect(violations).toEqual([])
  })
})
