import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { renderEditor, type EditorFixture } from '@/test/editor'
import { linkSuggestion, selectCandidate } from './diary-link'

let h: EditorFixture

beforeEach(() => {
  vi.useFakeTimers()
  h = renderEditor()
})

afterEach(() => {
  h.destroy()
  vi.useRealTimers()
})

const state = () => linkSuggestion.get()
const request = (): { reqId: string; query: string } | undefined =>
  h.lastPost('requestLinkCandidates')?.payload as { reqId: string; query: string } | undefined

// 等过 debounce，再以 Flutter 的身份回候选
const respond = async (items: Array<{ id: string; label: string }>): Promise<void> => {
  await vi.advanceTimersByTimeAsync(250)
  h.api.resolveLinkCandidates(request()!.reqId, JSON.stringify(items))
  await vi.advanceTimersByTimeAsync(0)
}

describe('diary link suggestion', () => {
  it('typing [[ opens the panel with an empty query, mid-text too', async () => {
    await h.insert('今天写了[[')
    expect(state()).toMatchObject({ open: true, query: '', loading: false, items: [] })
  })

  it('debounces the query and shows candidates from Flutter', async () => {
    await h.insert('[[天气')
    expect(state().loading).toBe(true)
    expect(request()).toBeUndefined()

    await vi.advanceTimersByTimeAsync(250)
    expect(request()?.query).toBe('天气')

    h.api.resolveLinkCandidates(request()!.reqId, JSON.stringify([{ id: 'd1', label: '晴天' }]))
    await vi.advanceTimersByTimeAsync(0)
    expect(state().loading).toBe(false)
    expect(state().items).toEqual([{ id: 'd1', label: '晴天' }])
  })

  it('discards stale responses, only the latest query wins', async () => {
    await h.insert('[[a')
    await vi.advanceTimersByTimeAsync(250)
    const first = request()!
    await h.insert('b')
    await vi.advanceTimersByTimeAsync(250)
    const second = request()!
    expect(second.reqId).not.toBe(first.reqId)

    h.api.resolveLinkCandidates(first.reqId, JSON.stringify([{ id: 'stale', label: 'stale' }]))
    await vi.advanceTimersByTimeAsync(0)
    expect(state()).toMatchObject({ items: [], loading: true })

    h.api.resolveLinkCandidates(second.reqId, JSON.stringify([{ id: 'fresh', label: 'fresh' }]))
    await vi.advanceTimersByTimeAsync(0)
    expect(state().items.map((i) => i.id)).toEqual(['fresh'])
  })

  it('resolves to an empty list when Flutter never responds', async () => {
    await h.insert('[[xx')
    await vi.advanceTimersByTimeAsync(250)
    expect(state().loading).toBe(true)
    await vi.advanceTimersByTimeAsync(4000)
    expect(state()).toMatchObject({ loading: false, items: [] })
  })

  it('arrow keys cycle candidates and Enter inserts the selected chip', async () => {
    await h.insert('[[日')
    await respond([
      { id: 'd1', label: '日记一' },
      { id: 'd2', label: '日记二' },
    ])
    await h.press('ArrowDown')
    expect(state().index).toBe(1)
    await h.press('ArrowUp')
    expect(state().index).toBe(0)
    await h.press('ArrowUp')
    expect(state().index).toBe(1)

    await h.press('Enter')
    expect(h.nodes('diaryLink')[0].attrs).toMatchObject({ id: 'd2', label: '日记二' })
    expect(h.editor.getText()).toContain('[[日记二]]')
    expect(state().open).toBe(false)
  })

  it('a panel tap inserts the chip without doubling a following space', async () => {
    await h.insert('前 后')
    h.editor.commands.setTextSelection(2)
    await h.insert('[[天')
    await respond([{ id: 'd9', label: '天空' }])
    selectCandidate(state().items[0])
    await vi.advanceTimersByTimeAsync(0)
    expect(h.nodes('diaryLink')[0].attrs).toEqual({ id: 'd9', label: '天空' })
    expect(h.editor.getText()).toBe('前[[天空]] 后')
    expect(state().open).toBe(false)
  })

  it('Backspace after the chip removes it without leaving a trigger character behind', async () => {
    await h.insert('前[[天')
    await respond([{ id: 'd9', label: '天空' }])
    selectCandidate(state().items[0])
    await vi.advanceTimersByTimeAsync(0)
    h.editor.commands.setTextSelection(3)
    await h.press('Backspace')
    expect(h.nodes('diaryLink')).toHaveLength(0)
    expect(h.editor.getText()).toBe('前 ')
  })

  it('Escape closes the panel without inserting', async () => {
    await h.insert('[[abc')
    expect(state().open).toBe(true)
    await h.press('Escape')
    expect(state().open).toBe(false)
    expect(h.editor.getText()).toContain('[[abc')
  })
})
