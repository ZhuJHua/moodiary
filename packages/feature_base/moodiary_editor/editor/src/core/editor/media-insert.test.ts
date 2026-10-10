import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { TextSelection } from '@tiptap/pm/state'
import { setupEditor } from '@/test/harness'
import type { EditorHarness } from '@/test/harness'

let h: EditorHarness

beforeEach(() => {
  vi.useFakeTimers()
  h = setupEditor()
})

afterEach(() => {
  h.destroy()
  vi.useRealTimers()
})

const mediaNames = (h: EditorHarness): string[] => {
  const names: string[] = []
  const walk = (n: { type?: string; attrs?: Record<string, unknown>; content?: unknown[] }): void => {
    if (n.type === 'image') names.push(String(n.attrs?.src))
    if (n.type === 'audio' || n.type === 'video') names.push(String(n.attrs?.filename))
    for (const c of (n.content ?? []) as never[]) walk(c)
  }
  walk(h.editor.getJSON())
  return names
}

describe('insert media blocks', () => {
  it('inserting three images keeps all in order', () => {
    h.api.insertMedia('a.jpg')
    h.api.insertMedia('b.jpg')
    h.api.insertMedia('c.jpg')
    expect(mediaNames(h)).toEqual(['a.jpg', 'b.jpg', 'c.jpg'])
  })

  it('mixed image / audio / video inserts do not replace each other', () => {
    h.api.insertMedia('a.jpg')
    h.api.insertAudio('audio-1.m4a')
    h.api.insertVideo('video-1.mp4')
    expect(mediaNames(h)).toEqual(['a.jpg', 'audio-1.m4a', 'video-1.mp4'])
  })

  it('inserts after existing text instead of wiping it', async () => {
    await h.type('今天')
    h.api.insertMedia('a.jpg')
    expect(h.editor.getText()).toContain('今天')
    expect(mediaNames(h)).toEqual(['a.jpg'])
  })

  it('does not raise the keyboard and leaves the caret after the block', async () => {
    await h.type('开头')
    h.editor.view.dom.blur()
    h.api.insertMedia('a.jpg')
    h.api.insertMedia('b.jpg')
    expect(h.editor.view.hasFocus()).toBe(false)
    expect(h.editor.state.selection).toBeInstanceOf(TextSelection)
    await h.type('然后')
    const blocks = h.editor
      .getJSON()
      .content!.map((n) => n.type + (n.attrs?.src ?? '') + ((n.content?.[0] as { text?: string } | undefined)?.text ?? ''))
    expect(blocks).toEqual(['paragraph开头', 'imagea.jpg', 'imageb.jpg', 'paragraph然后'])
  })
})
