import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { renderEditor, type EditorFixture } from '@/test/editor'

let h: EditorFixture

beforeEach(() => {
  h = renderEditor()
})

afterEach(() => {
  h.destroy()
})

const docWith = (text: string): string =>
  JSON.stringify({ type: 'doc', content: [{ type: 'paragraph', content: [{ type: 'text', text }] }] })

const undoTimes = (n: number): void => {
  for (let i = 0; i < n; i += 1) h.editor.commands.undo()
}

describe('loadContent resets the undo stack', () => {
  it('cannot undo past a freshly loaded document', async () => {
    h.api.setContent(docWith('第一篇的正文'))
    h.api.setContent(docWith('第二篇的正文'))
    await h.insert('补一个字')
    undoTimes(5)
    expect(h.editor.getText()).toContain('第二篇的正文')
    expect(h.editor.getText()).not.toContain('第一篇的正文')
  })

  it('cannot undo past the very first load into an empty editor', async () => {
    h.api.setContent(docWith('首次打开的正文'))
    await h.insert('补一个字')
    undoTimes(5)
    expect(h.editor.getText()).toContain('首次打开的正文')
  })

  it('swaps the history plugin instead of stacking copies of it', () => {
    const historyPlugins = (): number =>
      h.editor.state.plugins.filter((p) => (p as unknown as { key: string }).key.startsWith('history$')).length
    expect(historyPlugins()).toBe(1)
    for (let i = 0; i < 5; i += 1) h.api.setContent(docWith(`第 ${i} 篇`))
    expect(historyPlugins()).toBe(1)
  })

  it('still undoes edits made after the load', async () => {
    h.api.setContent(docWith('正文'))
    await h.insert('多余的字')
    undoTimes(1)
    expect(h.editor.getText()).not.toContain('多余的字')
    expect(h.editor.getText()).toContain('正文')
  })
})

describe('content check on load', () => {
  it('drops legacy attributes silently and reports nothing', () => {
    h.api.setContent(
      JSON.stringify({
        type: 'doc',
        content: [
          { type: 'image', attrs: { src: 'image-1.png', width: null, height: null, widthPercent: 50 } },
          { type: 'paragraph', content: [{ type: 'diaryLink', attrs: { id: 'd1', label: 'x', mentionSuggestionChar: '@' } }] },
          { type: 'audio', attrs: { filename: 'audio-1.m4a' } },
        ],
      }),
    )
    expect(h.lastPost('contentError')).toBeUndefined()
    expect(h.nodes('image')[0].attrs).toEqual({ src: 'image-1.png', alt: null, title: null, widthPercent: 50 })
    expect(h.nodes('diaryLink')[0].attrs).toEqual({ id: 'd1', label: 'x' })
    expect(h.nodes('audio')[0].attrs).toEqual({ filename: 'audio-1.m4a' })
  })

  it('reports an unknown node type and flags the content as lost', () => {
    const warn = vi.spyOn(console, 'warn').mockImplementation(() => {})
    h.api.setContent(
      JSON.stringify({
        type: 'doc',
        content: [{ type: 'paragraph', content: [{ type: 'text', text: 'x' }] }, { type: 'mysteryBlock' }],
      }),
    )
    warn.mockRestore()
    expect(h.lastPost('contentError')?.payload).toMatchObject({ lost: true })
  })

  it('reports a structural mismatch but keeps the content, so editing stays allowed', () => {
    h.api.setContent(
      JSON.stringify({
        type: 'doc',
        content: [{ type: 'bulletList', content: [{ type: 'listItem', content: [{ type: 'text', text: 'loose' }] }] }],
      }),
    )
    expect(h.lastPost('contentError')?.payload).toMatchObject({ lost: false })
    expect(h.editor.getText()).toContain('loose')
  })

  it('an empty document loads without complaint', () => {
    h.api.setContent('{"type":"doc","content":[]}')
    expect(h.lastPost('contentError')).toBeUndefined()
    expect(h.editor.isEmpty).toBe(true)
  })
})
