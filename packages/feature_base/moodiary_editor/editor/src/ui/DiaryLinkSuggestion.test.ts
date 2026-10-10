import { createElement } from 'react'
import { cleanup, fireEvent, render } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { setupEditor } from '@/test/harness'
import type { EditorHarness } from '@/test/harness'
import DiaryLinkSuggestion from './DiaryLinkSuggestion'

let h: EditorHarness

beforeEach(() => {
  vi.useFakeTimers()
  h = setupEditor()
})

afterEach(() => {
  cleanup()
  h.destroy()
  vi.useRealTimers()
})

const mountPanel = () => render(createElement(DiaryLinkSuggestion)).container

describe('DiaryLinkSuggestion panel', () => {
  it('is hidden until [[ is typed', async () => {
    const w = mountPanel()
    expect(w.querySelector('div')).toBeNull()

    await h.type('[[')
    expect(w.textContent).toContain('输入关键词搜索日记')
  })

  it('walks hint → loading → no-match states', async () => {
    const w = mountPanel()

    await h.type('[[猫')
    expect(w.textContent).toContain('搜索中')

    await h.respond([])
    expect(w.textContent).toContain('无匹配的日记')
  })

  it('renders candidates, highlights the active one, click inserts and closes', async () => {
    const w = mountPanel()

    await h.type('[[日')
    await h.respond([
      { id: 'd1', label: '日记一' },
      { id: 'd2', label: '日记二' },
    ])

    const buttons = Array.from(w.querySelectorAll('button'))
    expect(buttons.map((b) => b.textContent)).toEqual(['日记一', '日记二'])
    expect(buttons[0].classList).toContain('bg-primary')

    await h.press('ArrowDown')
    expect(w.querySelectorAll('button')[1].classList).toContain('bg-primary')

    fireEvent.mouseDown(buttons[1])
    await h.flush()
    expect(h.findNode('diaryLink')?.attrs).toMatchObject({ id: 'd2', label: '日记二' })

    expect(w.querySelector('button')).toBeNull()
  })
})
