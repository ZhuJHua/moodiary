import { mount } from '@vue/test-utils'
import { nextTick } from 'vue'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { setupEditor } from '../test/harness'
import type { EditorHarness } from '../test/harness'
import DiaryLinkSuggestion from './DiaryLinkSuggestion.vue'

let h: EditorHarness

beforeEach(() => {
  vi.useFakeTimers()
  h = setupEditor()
})

afterEach(() => {
  h.destroy()
  vi.useRealTimers()
})

describe('DiaryLinkSuggestion panel', () => {
  it('is hidden until [[ is typed', async () => {
    const w = mount(DiaryLinkSuggestion)
    expect(w.find('div').exists()).toBe(false)

    await h.type('[[')
    await nextTick()
    expect(w.text()).toContain('输入关键词搜索日记')
    w.unmount()
  })

  it('walks hint → loading → no-match states', async () => {
    const w = mount(DiaryLinkSuggestion)

    await h.type('[[猫')
    await nextTick()
    expect(w.text()).toContain('搜索中')

    await h.respond([])
    await nextTick()
    expect(w.text()).toContain('无匹配的日记')
    w.unmount()
  })

  it('renders candidates, highlights the active one, click inserts and closes', async () => {
    const w = mount(DiaryLinkSuggestion)

    await h.type('[[日')
    await h.respond([
      { id: 'd1', label: '日记一' },
      { id: 'd2', label: '日记二' },
    ])
    await nextTick()

    const buttons = w.findAll('button')
    expect(buttons.map((b) => b.text())).toEqual(['日记一', '日记二'])
    expect(buttons[0].classes()).toContain('bg-primary')

    await h.press('ArrowDown')
    await nextTick()
    expect(w.findAll('button')[1].classes()).toContain('bg-primary')

    await buttons[1].trigger('mousedown')
    await vi.advanceTimersByTimeAsync(0)
    expect(h.findNode('diaryLink')?.attrs).toMatchObject({ id: 'd2', label: '日记二' })

    await nextTick()
    expect(w.find('button').exists()).toBe(false)
    w.unmount()
  })
})
