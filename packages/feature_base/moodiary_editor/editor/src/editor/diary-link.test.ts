import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { setupEditor } from '../test/harness'
import type { EditorHarness } from '../test/harness'
import { linkSuggestion, selectCandidate } from './diary-link'

let h: EditorHarness

beforeEach(() => {
  vi.useFakeTimers()
  h = setupEditor()
})

afterEach(() => {
  h.destroy()
  vi.useRealTimers()
})

describe('diary link suggestion', () => {
  it('typing [[ opens the panel with an empty query', async () => {
    await h.type('[[')
    expect(linkSuggestion.open).toBe(true)
    expect(linkSuggestion.query).toBe('')
    expect(linkSuggestion.loading).toBe(false)
    expect(linkSuggestion.items).toEqual([])
  })

  it('triggers mid-text, not only at line start', async () => {
    await h.type('今天写了[[')
    expect(linkSuggestion.open).toBe(true)
  })

  it('debounces the query and shows candidates from Flutter', async () => {
    await h.type('[[天气')
    expect(linkSuggestion.open).toBe(true)
    expect(linkSuggestion.loading).toBe(true)
    expect(h.lastPost('requestLinkCandidates')).toBeUndefined()

    await vi.advanceTimersByTimeAsync(250)
    const req = h.lastPost('requestLinkCandidates')
    expect(req?.payload?.query).toBe('天气')

    h.api.resolveLinkCandidates(req!.payload!.reqId, JSON.stringify([{ id: 'd1', label: '晴天' }]))
    await vi.advanceTimersByTimeAsync(0)
    expect(linkSuggestion.loading).toBe(false)
    expect(linkSuggestion.items).toEqual([{ id: 'd1', label: '晴天' }])
  })

  it('discards stale responses, only the latest query wins', async () => {
    await h.type('[[a')
    await vi.advanceTimersByTimeAsync(250)
    const first = h.lastPost('requestLinkCandidates')

    await h.type('b')
    expect(linkSuggestion.query).toBe('ab')
    await vi.advanceTimersByTimeAsync(250)
    const second = h.lastPost('requestLinkCandidates')
    expect(second!.payload!.reqId).not.toBe(first!.payload!.reqId)

    h.api.resolveLinkCandidates(
      first!.payload!.reqId,
      JSON.stringify([{ id: 'stale', label: 'stale' }]),
    )
    await vi.advanceTimersByTimeAsync(0)
    expect(linkSuggestion.items).toEqual([])
    expect(linkSuggestion.loading).toBe(true)

    h.api.resolveLinkCandidates(
      second!.payload!.reqId,
      JSON.stringify([{ id: 'fresh', label: 'fresh' }]),
    )
    await vi.advanceTimersByTimeAsync(0)
    expect(linkSuggestion.items.map((i) => i.id)).toEqual(['fresh'])
  })

  it('resolves to an empty list when Flutter never responds', async () => {
    await h.type('[[xx')
    await vi.advanceTimersByTimeAsync(250)
    expect(linkSuggestion.loading).toBe(true)
    await vi.advanceTimersByTimeAsync(4000)
    expect(linkSuggestion.loading).toBe(false)
    expect(linkSuggestion.items).toEqual([])
  })

  it('arrow keys cycle candidates and Enter inserts the selected chip', async () => {
    await h.type('[[日')
    await h.respond([
      { id: 'd1', label: '日记一' },
      { id: 'd2', label: '日记二' },
    ])

    await h.press('ArrowDown')
    expect(linkSuggestion.index).toBe(1)
    await h.press('ArrowUp')
    expect(linkSuggestion.index).toBe(0)
    await h.press('ArrowUp')
    expect(linkSuggestion.index).toBe(1)

    await h.press('Enter')
    expect(h.findNode('diaryLink')?.attrs).toMatchObject({ id: 'd2', label: '日记二' })
    expect(h.editor.getText()).toContain('[[日记二]]')
    expect(linkSuggestion.open).toBe(false)
  })

  it('selectCandidate (panel tap) inserts the chip and closes the panel', async () => {
    await h.type('[[天')
    await h.respond([{ id: 'd9', label: '天空' }])

    selectCandidate(linkSuggestion.items[0])
    await vi.advanceTimersByTimeAsync(0)
    expect(h.findNode('diaryLink')?.attrs).toMatchObject({ id: 'd9', label: '天空' })
    expect(linkSuggestion.open).toBe(false)
  })

  it('Escape closes the panel without inserting', async () => {
    await h.type('[[abc')
    expect(linkSuggestion.open).toBe(true)
    await h.press('Escape')
    expect(linkSuggestion.open).toBe(false)
    expect(h.editor.getText()).toContain('[[abc')
  })
})
