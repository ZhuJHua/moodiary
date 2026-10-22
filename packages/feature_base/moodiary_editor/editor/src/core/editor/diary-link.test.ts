import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { doc, p, renderEditor, type EditorFixture } from '@/test/editor'
import { linkSuggestionStore, resolveLinkCandidates, selectCandidate } from './nodes/diary-link'

let h: EditorFixture

beforeEach(() => {
  vi.useFakeTimers()
  h = renderEditor()
  h.load(doc([p('看')]))
  h.editor.commands.setTextSelection(2)
})

afterEach(() => {
  h.destroy()
  vi.useRealTimers()
})

const typeChars = (text: string): void => {
  for (const ch of Array.from(text)) h.type(ch)
}
const lastRequest = (): { reqId: string; query: string } | undefined =>
  h.lastPost('requestLinkCandidates')?.payload as { reqId: string; query: string } | undefined

describe('diary link suggestion', () => {
  for (const trigger of ['[[', '【【', '「「']) {
    it(`${trigger} asks Flutter for candidates and inserts the picked diary`, async () => {
      typeChars(`${trigger}杭州`)
      await vi.advanceTimersByTimeAsync(300)
      expect(linkSuggestionStore.getState().open).toBe(true)
      const req = lastRequest()!
      expect(req.query).toBe('杭州')
      resolveLinkCandidates(req.reqId, JSON.stringify([{ id: 'd9', label: '杭州游记' }]))
      await vi.advanceTimersByTimeAsync(0)
      expect(linkSuggestionStore.getState().items).toEqual([{ id: 'd9', label: '杭州游记' }])
      selectCandidate(linkSuggestionStore.getState().items[0])
      await vi.advanceTimersByTimeAsync(0)
      const para = h.editor.getJSON().content![0]
      expect(para.content![0]).toEqual({ type: 'text', text: '看' })
      expect(para.content![1]).toEqual({ type: 'diaryLink', attrs: { id: 'd9', label: '杭州游记' } })
      expect(linkSuggestionStore.getState().open).toBe(false)
    })
  }

  it('closes once the brackets are closed', async () => {
    typeChars('[[abc]')
    await vi.advanceTimersByTimeAsync(300)
    expect(linkSuggestionStore.getState().open).toBe(false)
  })

  it('opens right away for an empty query (insertDiaryLink)', async () => {
    h.api.exec('insertDiaryLink')
    await vi.advanceTimersByTimeAsync(300)
    expect(linkSuggestionStore.getState()).toMatchObject({ open: true, query: '' })
  })
})
