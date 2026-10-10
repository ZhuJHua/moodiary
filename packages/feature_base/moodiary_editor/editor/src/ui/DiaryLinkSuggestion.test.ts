import { createElement } from 'react'
import { fireEvent, render } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { flush, renderEditor, type EditorFixture } from '@/test/editor'
import DiaryLinkSuggestion from './DiaryLinkSuggestion'

let h: EditorFixture
let panel: HTMLElement

beforeEach(() => {
  vi.useFakeTimers()
  h = renderEditor()
  panel = render(createElement(DiaryLinkSuggestion)).container
})

afterEach(() => {
  h.destroy()
  vi.useRealTimers()
})

const respond = async (items: Array<{ id: string; label: string }>): Promise<void> => {
  await vi.advanceTimersByTimeAsync(250)
  const { reqId } = h.lastPost('requestLinkCandidates')!.payload as { reqId: string }
  h.api.resolveLinkCandidates(reqId, JSON.stringify(items))
  await flush()
}

describe('DiaryLinkSuggestion panel', () => {
  it('is hidden until [[ is typed', async () => {
    expect(panel.querySelector('div')).toBeNull()
    await h.insert('[[')
    expect(panel.textContent).toContain('输入关键词搜索日记')
  })

  it('walks hint → loading → no-match states', async () => {
    await h.insert('[[猫')
    expect(panel.textContent).toContain('搜索中')
    await respond([])
    expect(panel.textContent).toContain('无匹配的日记')
  })

  it('renders candidates, highlights the active one, click inserts and closes', async () => {
    await h.insert('[[日')
    await respond([
      { id: 'd1', label: '日记一' },
      { id: 'd2', label: '日记二' },
    ])
    const buttons = Array.from(panel.querySelectorAll('button'))
    expect(buttons.map((b) => b.textContent)).toEqual(['日记一', '日记二'])
    expect(buttons[0].classList).toContain('bg-primary')

    await h.press('ArrowDown')
    expect(panel.querySelectorAll('button')[1].classList).toContain('bg-primary')

    fireEvent.mouseDown(buttons[1])
    await flush()
    expect(h.nodes('diaryLink')[0].attrs).toMatchObject({ id: 'd2', label: '日记二' })
    expect(panel.querySelector('button')).toBeNull()
  })
})
