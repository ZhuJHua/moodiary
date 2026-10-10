import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { flush, renderEditor, type EditorFixture } from '@/test/editor'
import { clampWidthPercent, snapWidthPercent } from './media-size'
import { setMediaPrefix } from './media'

const PREFIX = 'http://127.0.0.1:5321/tok/media/'

let h: EditorFixture

beforeEach(() => {
  setMediaPrefix(PREFIX)
  h = renderEditor()
})

afterEach(() => {
  h.destroy()
})

const attrsOf = (type: string): Record<string, unknown>[] => h.nodes(type).map((n) => n.attrs ?? {})
const setWidth = (type: string, value: number | null): void => {
  let pos = -1
  h.editor.state.doc.descendants((n, p) => {
    if (pos < 0 && n.type.name === type) pos = p
    return pos < 0
  })
  const node = h.editor.state.doc.nodeAt(pos)!
  h.editor.view.dispatch(h.editor.state.tr.setNodeMarkup(pos, undefined, { ...node.attrs, widthPercent: value }))
}
const query = <T extends HTMLElement>(selector: string): T | null => h.editor.view.dom.querySelector<T>(selector)

describe('image source', () => {
  it('serves local media through the proxy and leaves external urls alone', async () => {
    h.api.insertMedia('image-1.jpg')
    await flush()
    expect(query('img')?.getAttribute('src')).toBe(`${PREFIX}image-1.jpg`)
    expect(attrsOf('image')[0].src).toBe('image-1.jpg')

    h.editor.commands.setContent({ type: 'doc', content: [{ type: 'image', attrs: { src: 'https://example.com/a.png' } }] })
    await flush()
    expect(query('img')?.getAttribute('src')).toBe('https://example.com/a.png')
  })
})

describe('widthPercent attribute', () => {
  it('defaults to null, round-trips and reads old documents as auto', () => {
    h.api.insertMedia('image-1.jpg')
    expect(attrsOf('image')[0]).toMatchObject({ src: 'image-1.jpg', widthPercent: null })
    setWidth('image', 50)
    const saved = h.api.getContent()
    expect(saved).toContain('"widthPercent":50')
    h.api.setContent(saved)
    expect(attrsOf('image')[0]).toMatchObject({ widthPercent: 50 })
    h.api.setContent(JSON.stringify({ type: 'doc', content: [{ type: 'image', attrs: { src: 'image-old.jpg' } }] }))
    expect(attrsOf('image')[0]).toMatchObject({ src: 'image-old.jpg', widthPercent: null })
  })

  it('drives the wrapper max-width, and auto leaves it unset', async () => {
    h.api.insertMedia('image-1.jpg')
    await flush()
    expect(query('.moodiary-image')?.style.maxWidth).toBe('')
    setWidth('image', 33)
    await flush()
    expect(query('.moodiary-image')?.style.maxWidth).toBe('33%')
    setWidth('image', null)
    await flush()
    expect(query('.moodiary-image')?.style.maxWidth).toBe('')
  })

  it('clamps and snaps', () => {
    expect(clampWidthPercent(0)).toBe(25)
    expect(clampWidthPercent(999)).toBe(100)
    expect(clampWidthPercent(33.4)).toBe(33)
    expect(snapWidthPercent(52)).toBe(50)
    expect(snapWidthPercent(62)).toBe(62)
    expect(snapWidthPercent(98)).toBe(100)
  })

  it('video narrows its wrapper, audio carries no width at all', async () => {
    h.api.insertVideo('video-1.mp4')
    h.api.insertAudio('audio-1.m4a')
    setWidth('video', 50)
    await flush()
    expect(query('.moodiary-media--video')?.style.maxWidth).toBe('50%')
    expect(attrsOf('video')[0]).toEqual({ filename: 'video-1.mp4', widthPercent: 50 })
    expect(attrsOf('audio')[0]).toEqual({ filename: 'audio-1.m4a' })
  })
})

describe('HTML parsing (clipboard)', () => {
  const paste = (html: string): void => {
    h.editor.view.pasteHTML(html, new Event('paste') as unknown as ClipboardEvent)
  }

  it('strips the media prefix and clamps or drops hostile size attributes', () => {
    h.api.insertMedia('image-1.jpg')
    paste(h.editor.getHTML())
    expect(attrsOf('image').every((a) => String(a.src).startsWith('image-'))).toBe(true)
    paste('<img src="image-2.jpg" data-width-percent="999"><img src="image-3.jpg" data-width-percent="abc">')
    expect(attrsOf('image').find((a) => a.src === 'image-2.jpg')?.widthPercent).toBe(100)
    expect(attrsOf('image').find((a) => a.src === 'image-3.jpg')?.widthPercent).toBeNull()
    paste('<img src="image-4.jpg" width="300" height="200">')
    expect(attrsOf('image').find((a) => a.src === 'image-4.jpg')).not.toHaveProperty('width')
    expect(h.editor.getHTML()).not.toContain('width="300"')
  })
})
