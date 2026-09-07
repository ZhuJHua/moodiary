import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { setupEditor } from '../test/harness'
import type { EditorHarness } from '../test/harness'

let h: EditorHarness

beforeEach(() => {
  vi.useFakeTimers()
  h = setupEditor()
})

afterEach(() => {
  h.destroy()
  vi.useRealTimers()
})

const docWith = (text: string): string =>
  JSON.stringify({
    type: 'doc',
    content: [{ type: 'paragraph', content: [{ type: 'text', text }] }],
  })

const undoTimes = (n: number): void => {
  for (let i = 0; i < n; i += 1) h.editor.commands.undo()
}

describe('loadContent resets the undo stack', () => {
  it('cannot undo past a freshly loaded document', async () => {
    h.api.setContent(docWith('第一篇的正文'))
    h.api.setContent(docWith('第二篇的正文'))
    await h.type('补一个字')

    undoTimes(5)

    expect(h.editor.getText()).toContain('第二篇的正文')
    expect(h.editor.getText()).not.toContain('第一篇的正文')
  })

  it('cannot undo past the very first load into an empty editor', async () => {
    h.api.setContent(docWith('首次打开的正文'))
    await h.type('补一个字')

    undoTimes(5)

    expect(h.editor.getText()).toContain('首次打开的正文')
  })

  it('swaps the history plugin instead of stacking copies of it', () => {
    const historyPlugins = (): number =>
      h.editor.state.plugins.filter((p) =>
        (p as unknown as { key: string }).key.startsWith('history$'),
      ).length

    expect(historyPlugins()).toBe(1)
    for (let i = 0; i < 5; i += 1) h.api.setContent(docWith(`第 ${i} 篇`))
    expect(historyPlugins()).toBe(1)
  })

  it('still undoes edits made after the load', async () => {
    h.api.setContent(docWith('正文'))
    await h.type('多余的字')
    expect(h.editor.getText()).toContain('多余的字')

    undoTimes(1)
    expect(h.editor.getText()).not.toContain('多余的字')
    expect(h.editor.getText()).toContain('正文')
  })
})
