import { createElement } from 'react'
import { fireEvent, render, screen } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { flush, renderEditor, type EditorFixture } from '@/test/editor'
import EditorToolbar from './EditorToolbar'

let h: EditorFixture

beforeEach(() => {
  h = renderEditor()
  render(createElement(EditorToolbar, { editor: h.editor, onPick: () => {} }))
})

afterEach(() => {
  h.destroy()
})

const disabled = (id: string): boolean => (screen.getByTestId(id) as HTMLButtonElement).disabled

describe('undo / redo buttons', () => {
  it('starts disabled on a fresh document', () => {
    expect(disabled('undo')).toBe(true)
    expect(disabled('redo')).toBe(true)
  })

  it('undoes and redoes an edit', async () => {
    await h.insert('今天天气不错')
    expect(disabled('undo')).toBe(false)

    fireEvent.click(screen.getByTestId('undo'))
    await flush()
    expect(h.editor.getText()).not.toContain('今天天气不错')
    expect(disabled('redo')).toBe(false)

    fireEvent.click(screen.getByTestId('redo'))
    await flush()
    expect(h.editor.getText()).toContain('今天天气不错')
  })

  it('goes back to disabled after loading new content', async () => {
    await h.insert('旧内容')
    expect(disabled('undo')).toBe(false)
    h.api.setContent(
      JSON.stringify({ type: 'doc', content: [{ type: 'paragraph', content: [{ type: 'text', text: '新的一篇' }] }] }),
    )
    await flush()
    expect(disabled('undo')).toBe(true)
  })
})
