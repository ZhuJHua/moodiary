import { describe, expect, it } from 'vitest'

// 分层只能向下依赖：lib <- core <- ui <- shell；test/ 与 main.tsx 不受限
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

describe('editor layers', () => {
  it('no layer imports upward', () => {
    const violations: string[] = []
    for (const [path, text] of Object.entries(sources)) {
      if (/\.test\.tsx?$/.test(path)) continue
      const rel = path.replace(/^\.\//, '')
      const allowed = ALLOWED[rel.split('/')[0]]
      if (!allowed) continue
      for (const m of text.matchAll(/from\s+['"]@\/([^'"/]+)/g)) {
        if (!allowed.includes(m[1])) violations.push(`${rel} -> @/${m[1]}`)
      }
    }
    expect(violations).toEqual([])
  })
})
