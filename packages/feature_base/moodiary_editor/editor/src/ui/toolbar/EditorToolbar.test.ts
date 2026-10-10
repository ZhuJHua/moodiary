import { act, createElement } from 'react'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { setupEditor } from '@/test/harness'
import type { EditorHarness } from '@/test/harness'
import EditorToolbar from './EditorToolbar'

let h: EditorHarness

beforeEach(() => {
  vi.useFakeTimers()
  h = setupEditor()
  render(createElement(EditorToolbar, { editor: h.editor, dense: true, onPick: () => {} }))
})

afterEach(() => {
  cleanup()
  h.destroy()
  vi.useRealTimers()
})

const btn = (id: string): HTMLButtonElement => screen.getByTestId(id) as HTMLButtonElement
const disabled = (id: string): boolean => btn(id).disabled

describe('undo / redo buttons', () => {
  it('starts disabled on a fresh document', () => {
    expect(disabled('undo')).toBe(true)
    expect(disabled('redo')).toBe(true)
  })

  it('undoes and redoes an edit', async () => {
    await h.type('今天天气不错')
    expect(disabled('undo')).toBe(false)

    fireEvent.click(btn('undo'))
    await h.flush()
    expect(h.editor.getText()).not.toContain('今天天气不错')
    expect(disabled('redo')).toBe(false)

    fireEvent.click(btn('redo'))
    await h.flush()
    expect(h.editor.getText()).toContain('今天天气不错')
  })

  it('goes back to disabled after loading new content', async () => {
    await h.type('旧内容')
    expect(disabled('undo')).toBe(false)

    act(() => {
      h.api.setContent(
        JSON.stringify({
          type: 'doc',
          content: [{ type: 'paragraph', content: [{ type: 'text', text: '新的一篇' }] }],
        }),
      )
    })
    await h.flush()
    expect(disabled('undo')).toBe(true)
  })
})
