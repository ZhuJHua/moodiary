import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { TextSelection } from '@tiptap/pm/state'
import { renderEditor, type EditorFixture } from '@/test/editor'

let h: EditorFixture

beforeEach(() => {
  h = renderEditor()
})

afterEach(() => {
  h.destroy()
})

const mediaNames = (): string[] =>
  h.editor.getJSON().content!.flatMap((n) => {
    if (n.type === 'image') return [String(n.attrs?.src)]
    if (n.type === 'audio' || n.type === 'video') return [String(n.attrs?.filename)]
    return []
  })

describe('insert media blocks', () => {
  it('inserting three images keeps all in order', () => {
    h.api.insertMedia('a.jpg')
    h.api.insertMedia('b.jpg')
    h.api.insertMedia('c.jpg')
    expect(mediaNames()).toEqual(['a.jpg', 'b.jpg', 'c.jpg'])
  })

  it('mixed image / audio / video inserts do not replace each other', () => {
    h.api.insertMedia('a.jpg')
    h.api.insertAudio('audio-1.m4a')
    h.api.insertVideo('video-1.mp4')
    expect(mediaNames()).toEqual(['a.jpg', 'audio-1.m4a', 'video-1.mp4'])
  })

  it('inserts after existing text instead of wiping it', async () => {
    await h.insert('今天')
    h.api.insertMedia('a.jpg')
    expect(h.editor.getText()).toContain('今天')
    expect(mediaNames()).toEqual(['a.jpg'])
  })

  it('does not raise the keyboard and leaves the caret after the block', async () => {
    await h.insert('开头')
    h.editor.view.dom.blur()
    h.api.insertMedia('a.jpg')
    h.api.insertMedia('b.jpg')
    expect(h.editor.view.hasFocus()).toBe(false)
    expect(h.editor.state.selection).toBeInstanceOf(TextSelection)
    await h.insert('然后')
    const blocks = h.editor
      .getJSON()
      .content!.map((n) => n.type + (n.attrs?.src ?? '') + ((n.content?.[0] as { text?: string } | undefined)?.text ?? ''))
    expect(blocks).toEqual(['paragraph开头', 'imagea.jpg', 'imageb.jpg', 'paragraph然后'])
  })
})
