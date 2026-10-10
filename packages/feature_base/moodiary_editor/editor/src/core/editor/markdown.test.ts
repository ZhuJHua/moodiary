import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import type { JSONContent } from '@tiptap/core'
import { flush, renderEditor, type EditorFixture } from '@/test/editor'

let h: EditorFixture

beforeEach(() => {
  h = renderEditor()
})

afterEach(() => {
  h.destroy()
})

const setMarkdown = (md: string): void => {
  h.editor.commands.setContent(md, { contentType: 'markdown', emitUpdate: false })
}
const blocks = (): JSONContent[] => {
  const content = (h.editor.getJSON() as JSONContent).content ?? []
  const last = content[content.length - 1]
  return last?.type === 'paragraph' && !last.content ? content.slice(0, -1) : content
}
const types = (): string[] => blocks().map((n) => n.type!)

describe('official markdown: parse', () => {
  it('task lists, tables with alignment and fenced code come through', () => {
    setMarkdown('- [ ] open\n- [x] done\n\n| a | b |\n|:--|--:|\n| 1 | 2 |\n\n```js\nlet a\n```')
    expect(types()).toEqual(['taskList', 'table', 'codeBlock'])
    const items = blocks()[0].content!
    expect(items.map((i) => i.attrs!.checked)).toEqual([false, true])
    const headerCells = blocks()[1].content![0].content!
    expect(headerCells.map((c) => c.attrs!.align)).toEqual(['left', 'right'])
    expect(blocks()[2].attrs!.language).toBe('js')
  })

  it('media images route by filename prefix into audio / video nodes', () => {
    setMarkdown('![](image-1.png)\n\n![](audio-1.m4a)\n\n![](video-1.mp4)')
    expect(types()).toEqual(['image', 'audio', 'video'])
    expect(blocks()[1].attrs).toEqual({ filename: 'audio-1.m4a' })
    expect(blocks()[2].attrs).toEqual({ filename: 'video-1.mp4', widthPercent: null })
  })

  it('[[label]](moodiary://diary/<id>) becomes a diaryLink, bare [[label]] stays text', () => {
    setMarkdown('看 [[那天]](moodiary://diary/d1) 和 [[没id]] 吧')
    const inline = blocks()[0].content!
    expect(inline.map((n) => n.type)).toEqual(['text', 'diaryLink', 'text'])
    expect(inline[1].attrs).toEqual({ id: 'd1', label: '那天' })
    expect(inline[2].text).toBe(' 和 [[没id]] 吧')
  })

  it('brackets and backslashes in a label survive the round trip', () => {
    const label = '[游记] 杭州\\西湖'
    h.api.setContent(
      JSON.stringify({
        type: 'doc',
        content: [{ type: 'paragraph', content: [{ type: 'diaryLink', attrs: { id: 'd2', label } }] }],
      }),
    )
    const md = h.editor.getMarkdown()
    expect(md).toContain('[[\\[游记\\] 杭州\\\\西湖]](moodiary://diary/d2)')
    setMarkdown(md)
    expect(h.nodes('diaryLink')[0]?.attrs).toEqual({ id: 'd2', label })
  })
})

describe('official markdown: serialize', () => {
  it('every stored node type survives getMarkdown (nothing is silently dropped)', () => {
    h.api.setContent(
      JSON.stringify({
        type: 'doc',
        content: [
          { type: 'heading', attrs: { level: 2 }, content: [{ type: 'text', text: 'H' }] },
          {
            type: 'paragraph',
            content: [{ type: 'text', text: '看 ' }, { type: 'diaryLink', attrs: { id: 'd1', label: '那天' } }],
          },
          { type: 'image', attrs: { src: 'image-1.png', widthPercent: 50 } },
          { type: 'audio', attrs: { filename: 'audio-1.m4a' } },
          { type: 'video', attrs: { filename: 'video-1.mp4', widthPercent: 75 } },
          {
            type: 'taskList',
            content: [
              {
                type: 'taskItem',
                attrs: { checked: true },
                content: [{ type: 'paragraph', content: [{ type: 'text', text: 't' }] }],
              },
            ],
          },
          {
            type: 'bulletList',
            content: [{ type: 'listItem', content: [{ type: 'paragraph', content: [{ type: 'text', text: 'b' }] }] }],
          },
          { type: 'blockquote', content: [{ type: 'paragraph', content: [{ type: 'text', text: 'q' }] }] },
          { type: 'codeBlock', attrs: { language: 'js' }, content: [{ type: 'text', text: 'x' }] },
          {
            type: 'table',
            content: [
              {
                type: 'tableRow',
                content: [{ type: 'tableHeader', content: [{ type: 'paragraph', content: [{ type: 'text', text: 'c' }] }] }],
              },
            ],
          },
          { type: 'horizontalRule' },
          {
            type: 'paragraph',
            content: [
              { type: 'text', text: 'a' },
              { type: 'hardBreak' },
              { type: 'text', marks: [{ type: 'bold' }], text: 'b' },
              { type: 'text', marks: [{ type: 'link', attrs: { href: 'https://x.y' } }], text: 'l' },
            ],
          },
        ],
      }),
    )
    const md = h.editor.getMarkdown()
    for (const fragment of [
      '## H',
      '[[那天]](moodiary://diary/d1)',
      '![](image-1.png)',
      '![](audio-1.m4a)',
      '![](video-1.mp4)',
      '- [x] t',
      '- b',
      '> q',
      '```js',
      '| c',
      '---',
      '**b**',
      '[l](https://x.y)',
    ]) {
      expect(md, fragment).toContain(fragment)
    }
  })

  it('every node and mark in the schema declares a markdown renderer', () => {
    const missing = h.editor.extensionManager.extensions
      .filter(
        (e) =>
          (e.type === 'node' || e.type === 'mark') &&
          !['doc', 'text', 'tableRow', 'tableCell', 'tableHeader'].includes(e.name),
      )
      .filter(
        (e) =>
          !(e.config as { renderMarkdown?: unknown }).renderMarkdown &&
          !(e.parent?.config as { renderMarkdown?: unknown } | undefined)?.renderMarkdown,
      )
      .map((e) => e.name)
    expect(missing).toEqual([])
  })
})

describe('paste and legacy content', () => {
  it('plain-text paste is parsed as markdown', async () => {
    const event = new Event('paste', { bubbles: true, cancelable: true })
    Object.defineProperty(event, 'clipboardData', {
      value: { files: [], types: ['text/plain'], getData: () => '# 标题\n\n- [ ] 事' },
    })
    h.editor.view.dom.dispatchEvent(event)
    await flush()
    expect(types()).toEqual(['heading', 'taskList'])
  })

  it('a non-document string loads as plain paragraphs instead of being parsed', () => {
    h.api.setContent('# not markdown\n\nsecond')
    expect(
      (h.editor.getJSON() as JSONContent).content!.map((n) => [n.type, n.content?.[0]?.text]),
    ).toEqual([
      ['paragraph', '# not markdown'],
      ['paragraph', undefined],
      ['paragraph', 'second'],
    ])
  })
})
