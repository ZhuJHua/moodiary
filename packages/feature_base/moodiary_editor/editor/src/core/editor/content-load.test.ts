import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import type { JSONContent } from '@tiptap/core'
import { DOMParser, DOMSerializer } from '@tiptap/pm/model'
import { CHANGE_DEBOUNCE_MS } from '@/core/bridge/change'
import { doc, flush, p, renderEditor, type EditorFixture } from '@/test/editor'
import { HR_VARIANTS, clampWidthPercent, docVersion, normalizeDoc } from './normalize'
import { countCharacters, plainTextOf } from './plain-text'

let h: EditorFixture

beforeEach(() => {
  h = renderEditor()
})

afterEach(() => {
  h.destroy()
  vi.useRealTimers()
})

const undoTimes = (n: number): void => {
  for (let i = 0; i < n; i += 1) h.editor.commands.undo()
}

describe('loading content', () => {
  it('upgrades a v1 document on the fly without complaint', () => {
    h.load({
      type: 'doc',
      content: [
        { type: 'image', attrs: { src: 'image-1.png', width: 10, height: 10, widthPercent: 50 } },
        { type: 'paragraph', content: [{ type: 'diaryLink', attrs: { id: 'd1', label: 'x', mentionSuggestionChar: '@' } }] },
        { type: 'audio', attrs: { filename: 'audio-1.m4a' } },
        { type: 'horizontalRule' },
      ],
    })
    expect(h.lastPost('contentError')).toBeUndefined()
    const json = h.editor.getJSON()
    expect(json.attrs).toEqual({ v: 2 })
    expect(h.nodes('image')[0].attrs).toEqual({ src: 'image-1.png', name: null, widthPercent: 50 })
    expect(h.nodes('diaryLink')[0].attrs).toEqual({ id: 'd1', label: 'x' })
    expect(h.nodes('audio')[0].attrs).toEqual({ src: 'audio-1.m4a', name: null })
    expect(h.nodes('horizontalRule')[0].attrs).toEqual({ variant: 'solid', label: null })
    expect(h.editor.isEditable).toBe(true)
  })

  it('folds image alt/title into the name of a v2 document too', () => {
    h.load({
      type: 'doc',
      attrs: { v: 2 },
      content: [
        { type: 'image', attrs: { src: 'image-1.png', alt: '海', title: '日落' } },
        { type: 'image', attrs: { src: 'image-2.png', alt: '', title: '日落' } },
        { type: 'image', attrs: { src: 'image-3.png', name: '自定', alt: '海' } },
      ],
    })
    expect(h.lastPost('contentError')).toBeUndefined()
    expect(h.nodes('image').map((n) => n.attrs)).toEqual([
      { src: 'image-1.png', name: '海', widthPercent: null },
      { src: 'image-2.png', name: '日落', widthPercent: null },
      { src: 'image-3.png', name: '自定', widthPercent: null },
    ])
  })

  it('plain text marks named media on their own line, unnamed ones take none', () => {
    h.load(
      doc([
        { type: 'attachment', attrs: { src: 'file-x.pdf', name: '报告.pdf' } },
        p('正文'),
        { type: 'image', attrs: { src: 'image-a.png', name: '封面' } },
        { type: 'audio', attrs: { src: 'audio-a.m4a', name: '晨间录音' } },
        { type: 'video', attrs: { src: 'video-a.mp4', name: '海边' } },
        { type: 'attachment', attrs: { src: 'file-y.pdf', name: '' } },
        p('尾'),
      ]),
    )
    const text = plainTextOf(h.editor.state.doc)
    expect(text).toBe('\uFDD4报告.pdf\uFDD0\n正文\n\uFDD1封面\uFDD0\n\uFDD3晨间录音\uFDD0\n\uFDD2海边\uFDD0\n尾')
    expect(countCharacters(text)).toBe(3)
  })

  it('reserved characters in user text and names never reach plain text', () => {
    h.load(
      doc([
        {
          type: 'paragraph',
          content: [
            { type: 'text', text: '\uFDD1假\uFDD0图' },
            { type: 'diaryLink', attrs: { id: 'a1', label: '\uFDEF链' } },
          ],
        },
        { type: 'image', attrs: { src: 'image-a.png', name: ' 晚\uFDD0霞\n海边 ' } },
        { type: 'audio', attrs: { src: 'audio-a.m4a', name: '\uFDD0' } },
        { type: 'video', attrs: { src: 'video-a.mp4', name: '\u0085影' } },
        p('尾'),
      ]),
    )
    expect(plainTextOf(h.editor.state.doc)).toBe('假图链\n\uFDD1晚霞 海边\uFDD0\n\uFDD2\u0085影\uFDD0\n尾')
  })

  it('an empty string is a fresh empty document', () => {
    h.load('')
    expect(h.lastPost('contentError')).toBeUndefined()
    expect(h.editor.isEmpty).toBe(true)
  })

  it('a non-JSON string loads as plain paragraphs', () => {
    h.load('# not markdown\n\nsecond')
    expect((h.editor.getJSON() as JSONContent).content!.map((n) => n.content?.[0]?.text)).toEqual([
      '# not markdown',
      undefined,
      'second',
    ])
  })
})

describe('content errors make the editor read-only and silent', () => {
  const brokenCases: Array<[string, string]> = [
    ['unknown node', JSON.stringify(doc([p('keep me'), { type: 'mysteryBlock', content: [p('inner')] }]))],
    [
      'structural mismatch',
      JSON.stringify(doc([{ type: 'bulletList', content: [{ type: 'listItem', content: [{ type: 'text', text: 'loose' }] }] }])),
    ],
    ['future schema version', JSON.stringify({ type: 'doc', attrs: { v: 3 }, content: [p('from the future')] })],
    ['corrupt JSON', '{"type":"doc","content":['],
  ]

  for (const [name, content] of brokenCases) {
    it(name, async () => {
      vi.useFakeTimers()
      h.api.setEditable(true)
      h.load(content)
      expect(h.lastPost('contentError')?.payload).toMatchObject({ message: expect.any(String) })
      expect(h.editor.isEditable).toBe(false)
      h.api.setEditable(true)
      expect(h.editor.isEditable).toBe(false)
      h.editor.commands.insertContent('x')
      await vi.advanceTimersByTimeAsync(CHANGE_DEBOUNCE_MS * 2)
      expect(h.lastPost('change')).toBeUndefined()
    })
  }

  it('still shows what it can of a document with an unknown node', () => {
    h.load(doc([p('keep me'), { type: 'mysteryBlock', content: [p('inner')] }]))
    expect(h.editor.getText()).toContain('keep me')
    expect(h.editor.getText()).toContain('inner')
  })

  it('a later valid document becomes editable again', () => {
    h.load(doc([{ type: 'mysteryBlock' }]))
    expect(h.editor.isEditable).toBe(false)
    h.load(doc([p('fine')]))
    expect(h.editor.isEditable).toBe(true)
  })
})

describe('loading resets the undo stack', () => {
  it('cannot undo past a freshly loaded document', async () => {
    h.load(doc([p('第一篇的正文')]))
    h.load(doc([p('第二篇的正文')]))
    h.editor.commands.insertContent('补一个字')
    await flush()
    undoTimes(5)
    expect(h.editor.getText()).toContain('第二篇的正文')
    expect(h.editor.getText()).not.toContain('第一篇的正文')
  })

  it('loading never emits a change', async () => {
    vi.useFakeTimers()
    h.load(doc([p('a')]))
    await vi.advanceTimersByTimeAsync(CHANGE_DEBOUNCE_MS * 2)
    expect(h.lastPost('change')).toBeUndefined()
  })
})

describe('pasted html images', () => {
  it('keeps the media name of a local path and drops paths that are not media files', () => {
    const el = document.createElement('div')
    el.innerHTML =
      '<img src="file:///data/user/0/app/files/image/image-0192.png"><img src="file:///data/cache/derived/9f3a.webp">' +
      '<img src="file:///data/cache/derived/77.webp" data-src="image-77.png">'
    const parsed = DOMParser.fromSchema(h.editor.schema).parse(el)
    const srcs: unknown[] = []
    parsed.descendants((n) => {
      if (n.type.name === 'image') srcs.push(n.attrs.src)
    })
    expect(srcs).toEqual(['image-0192.png', 'image-77.png'])
  })

  it('media names ride along in data-name, an image falls back to alt', () => {
    const { schema } = h.editor
    const source = schema.nodeFromJSON(
      doc([
        { type: 'image', attrs: { src: 'image-1.png', name: '海' } },
        { type: 'audio', attrs: { src: 'audio-1.m4a', name: '音' } },
        { type: 'attachment', attrs: { src: 'file-1.pdf', name: '件.pdf' } },
      ]),
    )
    const el = document.createElement('div')
    el.appendChild(DOMSerializer.fromSchema(schema).serializeFragment(source.content))
    el.insertAdjacentHTML('beforeend', '<img src="file:///x/image-2.png" alt="旧">')
    const names: unknown[] = []
    DOMParser.fromSchema(schema)
      .parse(el)
      .descendants((n) => {
        if (n.isAtom) names.push(n.attrs.name)
      })
    expect(names).toEqual(['海', '音', '件.pdf', '旧'])
  })
})

describe('custom node HTML serialization', () => {
  it('preserves every divider variant and label without creating extra dividers', () => {
    const { schema } = h.editor
    const source = schema.nodeFromJSON(
      doc(HR_VARIANTS.map((variant) => ({
        type: 'horizontalRule',
        attrs: { variant, label: variant === 'text' ? '章节 <一>' : null },
      }))),
    )
    const el = document.createElement('div')
    el.appendChild(DOMSerializer.fromSchema(schema).serializeFragment(source.content))
    expect(DOMParser.fromSchema(schema).parse(el).toJSON()).toEqual(source.toJSON())
  })

  it('imports a standard hr with the default divider attributes', () => {
    const el = document.createElement('div')
    el.innerHTML = '<hr>'
    expect(DOMParser.fromSchema(h.editor.schema).parse(el).firstChild?.toJSON()).toEqual({
      type: 'horizontalRule',
      attrs: { variant: 'solid', label: null },
    })
  })

  it('keeps absent and invalid attachment sizes unknown, including after an HTML round-trip', () => {
    const { schema } = h.editor
    const el = document.createElement('div')
    const source = schema.nodeFromJSON(doc([{ type: 'attachment', attrs: { src: 'file-1.pdf' } }]))
    el.appendChild(DOMSerializer.fromSchema(schema).serializeFragment(source.content))
    expect(DOMParser.fromSchema(schema).parse(el).firstChild?.attrs.size).toBeNull()
    for (const [raw, expected] of [['', null], [' ', null], ['-1', null], ['unknown', null], ['0', 0], ['2048', 2048]]) {
      el.innerHTML = `<div data-type="attachment" data-src="file-1.pdf" data-size="${raw}"></div>`
      expect(DOMParser.fromSchema(schema).parse(el).firstChild?.attrs.size).toBe(expected)
    }
  })
})

const v1 = {
  type: 'doc',
  content: [
    { type: 'image', attrs: { src: 'image-1.png', alt: null, title: null, width: 300, height: 200, widthPercent: 60 } },
    { type: 'audio', attrs: { filename: 'audio-1.m4a' } },
    { type: 'video', attrs: { filename: 'video-1.mp4' } },
    { type: 'horizontalRule' },
    {
      type: 'paragraph',
      content: [
        { type: 'diaryLink', attrs: { id: 'd1', label: '那天', mentionSuggestionChar: '[[' } },
        {
          type: 'text',
          text: 'x',
          marks: [{ type: 'link', attrs: { href: 'https://a.b', target: '_blank', rel: 'noopener', class: null } }],
        },
      ],
    },
    { type: 'mysteryBlock', attrs: { foo: 1 } },
  ],
}

describe('normalizeDoc (v1 → v2)', () => {
  const out = normalizeDoc(v1)
  const content = out.content!

  it('stamps the schema version', () => {
    expect(out.attrs).toEqual({ v: 2 })
    expect(docVersion(v1)).toBe(1)
    expect(docVersion(out)).toBe(2)
  })

  it('drops image pixel sizes and keeps widthPercent', () => {
    expect(content[0].attrs).toEqual({ src: 'image-1.png', name: null, widthPercent: 60 })
  })

  it('renames audio/video filename to src', () => {
    expect(content[1].attrs).toEqual({ src: 'audio-1.m4a' })
    expect(content[2].attrs).toEqual({ src: 'video-1.mp4' })
  })

  it('fills horizontal rule defaults', () => {
    expect(content[3].attrs).toEqual({ variant: 'solid', label: null })
  })

  it('drops the mention trigger char and non-href link attributes', () => {
    const inline = content[4].content!
    expect(inline[0].attrs).toEqual({ id: 'd1', label: '那天' })
    expect(inline[1].marks).toEqual([{ type: 'link', attrs: { href: 'https://a.b' } }])
  })

  it('keeps unknown nodes untouched', () => {
    expect(content[5]).toEqual({ type: 'mysteryBlock', attrs: { foo: 1 } })
  })

  it('is idempotent and does not mutate its input', () => {
    expect(normalizeDoc(out)).toEqual(out)
    expect(v1.content[1].attrs).toEqual({ filename: 'audio-1.m4a' })
  })

  it('clamps width to 25..100 without snapping', () => {
    expect([25, 37, 62.6, 88, 100, 10, 140].map(clampWidthPercent)).toEqual([25, 37, 63, 88, 100, 25, 100])
    expect(clampWidthPercent(null)).toBeNull()
    expect(clampWidthPercent('50')).toBeNull()
  })
})
