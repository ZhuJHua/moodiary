import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { nextTick } from 'vue'
import { mount, type VueWrapper } from '@vue/test-utils'
import { NodeSelection, TextSelection } from '@tiptap/pm/state'
import { setupEditor } from '../test/harness'
import type { EditorHarness } from '../test/harness'
import BlockMenu from '../components/block/BlockMenu.vue'
import { clampWidthPercent, snapWidthPercent, WIDTH_PERCENT_STOPS } from './media-size'
import { setMediaPrefix } from './media'
import { blockMenu } from './block-menu'
import { runUndoToast, undoToast } from './undo-toast'
import { dismissOverlay } from './overlay'

const PREFIX = 'http://127.0.0.1:5321/tok/media/'

let h: EditorHarness
let menu: VueWrapper | null = null

beforeEach(() => {
  vi.useFakeTimers()
  setMediaPrefix(PREFIX)
  h = setupEditor()
})

afterEach(() => {
  menu?.unmount()
  menu = null
  h.destroy()
  vi.useRealTimers()
})

const mountMenu = (): void => {
  menu = mount(BlockMenu, { props: { editor: h.editor }, attachTo: document.body })
}

const nodesOf = (type: string): Array<Record<string, unknown>> => {
  const out: Array<Record<string, unknown>> = []
  h.editor.state.doc.descendants((n) => {
    if (n.type.name === type) out.push(n.attrs)
    return true
  })
  return out
}
const posOf = (type: string, index = 0): number => {
  const found: number[] = []
  h.editor.state.doc.descendants((n, pos) => {
    if (n.type.name === type) found.push(pos)
    return true
  })
  return found[index]
}
const setWidth = (type: string, value: number | null, index = 0): void => {
  const pos = posOf(type, index)
  const node = h.editor.state.doc.nodeAt(pos)!
  h.editor.view.dispatch(h.editor.state.tr.setNodeMarkup(pos, undefined, { ...node.attrs, widthPercent: value }))
}
const wrapper = (): HTMLElement | null => h.editor.view.dom.querySelector('.moodiary-image')
const handles = (): HTMLElement[] =>
  Array.from(h.editor.view.dom.querySelectorAll<HTMLElement>('.moodiary-block__handle'))
const panel = (): HTMLElement | null => document.body.querySelector('.moodiary-popover')
const track = (): HTMLInputElement | null => panel()?.querySelector('input[type="range"]') ?? null
const button = (label: string): HTMLButtonElement | undefined =>
  Array.from(panel()?.querySelectorAll<HTMLButtonElement>('button') ?? []).find(
    (el) => el.textContent?.trim() === label,
  )

const openMenu = async (index = 0): Promise<void> => {
  handles()[index].click()
  await nextTick()
}
const drag = (type: 'input' | 'change', percent: number): void => {
  const el = track()!
  el.value = String(percent)
  el.dispatchEvent(new Event(type, { bubbles: true }))
}
const blockTypes = (): string[] =>
  h.editor.getJSON().content!.map((n) => n.type + (n.content?.[0] ? ':' + (n.content[0] as { text?: string }).text : ''))

describe('image node view', () => {
  it('keeps a real <img> with the proxied src for the gallery', () => {
    h.api.insertMedia('image-1.jpg')
    expect(wrapper()).not.toBeNull()
    expect(h.editor.view.dom.querySelector('img')?.getAttribute('src')).toBe(`${PREFIX}image-1.jpg`)
  })

  it('leaves external http(s) sources untouched', async () => {
    h.editor.commands.setContent(
      { type: 'doc', content: [{ type: 'image', attrs: { src: 'https://example.com/a.png' } }] },
      { emitUpdate: false },
    )
    await nextTick()
    expect(h.editor.view.dom.querySelector('img')?.getAttribute('src')).toBe('https://example.com/a.png')
  })
})

describe('widthPercent attribute', () => {
  it('defaults to null, round-trips and reads old documents as auto', () => {
    h.api.insertMedia('image-1.jpg')
    expect(nodesOf('image')[0]).toMatchObject({ src: 'image-1.jpg', widthPercent: null })
    setWidth('image', 50)
    const saved = h.api.getContent()
    expect(saved).toContain('"widthPercent":50')
    h.api.setContent(saved)
    expect(nodesOf('image')[0]).toMatchObject({ widthPercent: 50 })
    h.api.setContent(JSON.stringify({ type: 'doc', content: [{ type: 'image', attrs: { src: 'image-old.jpg' } }] }))
    expect(nodesOf('image')[0]).toMatchObject({ src: 'image-old.jpg', widthPercent: null })
  })

  it('drives the wrapper max-width, and auto leaves it unset', async () => {
    h.api.insertMedia('image-1.jpg')
    await nextTick()
    expect(wrapper()?.style.maxWidth).toBe('')
    setWidth('image', 33)
    await nextTick()
    expect(wrapper()?.style.maxWidth).toBe('33%')
    setWidth('image', null)
    await nextTick()
    expect(wrapper()?.style.maxWidth).toBe('')
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
    await nextTick()
    expect(h.editor.view.dom.querySelector<HTMLElement>('.moodiary-media--video')?.style.maxWidth).toBe('50%')
    expect(nodesOf('video')[0]).toEqual({ filename: 'video-1.mp4', widthPercent: 50 })
    expect(nodesOf('audio')[0]).toEqual({ filename: 'audio-1.m4a' })
  })
})

describe('block handle and menu', () => {
  beforeEach(async () => {
    mountMenu()
    h.api.insertMedia('image-1.jpg')
    await nextTick()
  })

  it('shows the handle only while editable', async () => {
    expect(handles()).toHaveLength(1)
    h.api.setEditable(false)
    await nextTick()
    expect(handles()).toHaveLength(0)
    h.api.setEditable(true)
    await nextTick()
    expect(handles()).toHaveLength(1)
  })

  it('opens next to that block, outlines only it, and keeps the keyboard where it was', async () => {
    h.api.insertMedia('image-2.jpg')
    await nextTick()
    h.editor.view.focus()
    await openMenu(1)
    expect(panel()).not.toBeNull()
    const wrappers = h.editor.view.dom.querySelectorAll('.moodiary-image')
    expect(Array.from(wrappers).map((w) => w.classList.contains('is-menu-open'))).toEqual([false, true])
    expect(h.lastPost('overlay')?.payload).toBe(true)
    drag('input', 50)
    drag('change', 50)
    expect(h.editor.view.hasFocus()).toBe(true)
  })

  it('previews while dragging and writes the snapped width on release', async () => {
    await openMenu()
    drag('input', 62)
    await nextTick()
    expect(wrapper()?.style.maxWidth).toBe('62%')
    expect(nodesOf('image')[0].widthPercent).toBeNull()
    drag('input', 70)
    drag('change', 52)
    await nextTick()
    expect(nodesOf('image')[0].widthPercent).toBe(50)
  })

  it('offers the stops and a reset, and closes on an outside tap', async () => {
    await openMenu()
    const stops = Array.from(panel()!.querySelectorAll<HTMLButtonElement>('.moodiary-width__stop'))
    expect(stops.map((el) => Number(el.textContent?.trim()))).toEqual([...WIDTH_PERCENT_STOPS])
    stops[2].click()
    await nextTick()
    expect(nodesOf('image')[0].widthPercent).toBe(75)
    button('恢复默认')!.click()
    await nextTick()
    expect(nodesOf('image')[0].widthPercent).toBeNull()
    ;(panel()!.previousElementSibling as HTMLElement).dispatchEvent(new Event('touchstart', { bubbles: true, cancelable: true }))
    await nextTick()
    expect(panel()).toBeNull()
    expect(blockMenu.owner).toBeNull()
    expect(h.lastPost('overlay')?.payload).toBe(false)
  })

  it('changes its own block, not whichever one happens to be selected', async () => {
    h.api.insertMedia('image-2.jpg')
    await nextTick()
    h.editor.commands.setNodeSelection(posOf('image', 0))
    await openMenu(1)
    panel()!.querySelectorAll<HTMLButtonElement>('.moodiary-width__stop')[1].click()
    await nextTick()
    expect(nodesOf('image').map((a) => a.widthPercent)).toEqual([null, 50])
  })

  it('inserts a paragraph above or below and puts the caret there', async () => {
    await openMenu()
    button('在下方插入文字')!.click()
    await nextTick()
    expect(blockTypes()).toEqual(['image', 'paragraph', 'paragraph'])
    expect(h.editor.state.selection.from).toBe(posOf('image') + 2)
    expect(h.editor.view.hasFocus()).toBe(true)
    await openMenu()
    button('在上方插入文字')!.click()
    await nextTick()
    expect(blockTypes()).toEqual(['paragraph', 'image', 'paragraph', 'paragraph'])
    expect(h.editor.state.selection.from).toBe(1)
  })

  it('deletes with an undo toast that goes away once the text changes again', async () => {
    await vi.advanceTimersByTimeAsync(1000)
    await openMenu()
    button('删除')!.click()
    await nextTick()
    expect(nodesOf('image')).toHaveLength(0)
    expect(undoToast.visible).toBe(true)
    runUndoToast()
    expect(nodesOf('image')).toHaveLength(1)
    expect(undoToast.visible).toBe(false)

    await vi.advanceTimersByTimeAsync(1000)
    await openMenu()
    button('删除')!.click()
    await nextTick()
    expect(undoToast.visible).toBe(true)
    await h.type('字')
    expect(undoToast.visible).toBe(false)
  })

  it('the back button closes the menu', async () => {
    await openMenu()
    dismissOverlay()
    await nextTick()
    expect(panel()).toBeNull()
    expect(h.lastPost('overlay')?.payload).toBe(false)
  })

  it('has no width control for audio', async () => {
    h.api.insertAudio('audio-1.m4a')
    await nextTick()
    await openMenu(1)
    expect(track()).toBeNull()
    expect(button('删除')).toBeDefined()
  })
})

describe('touch on blocks', () => {
  const stopEvent = (selector: string, type: string): boolean | undefined => {
    const el = h.editor.view.dom.querySelector(selector) as
      | (HTMLElement & { pmViewDesc?: { stopEvent(e: Event): boolean } })
      | null
    return el?.pmViewDesc?.stopEvent(new Event(type, { bubbles: true }))
  }

  const tap = (el: Element, y: number): TouchEvent => {
    const down = new Event('pointerdown', { bubbles: true }) as PointerEvent
    Object.assign(down, { pointerType: 'touch', clientX: 50, clientY: y })
    el.dispatchEvent(down)
    const end = new Event('touchend', { bubbles: true, cancelable: true }) as TouchEvent
    Object.defineProperty(end, 'touches', { value: [] })
    Object.defineProperty(end, 'changedTouches', { value: [{ clientX: 50, clientY: y }] })
    el.dispatchEvent(end)
    return end
  }

  const bodyRect = (el: Element, top: number, bottom: number): void => {
    vi.spyOn(el, 'getBoundingClientRect').mockReturnValue({ top, bottom, left: 0, right: 100 } as DOMRect)
  }

  it('swallow pointer events so nothing creates a node selection, but let the clipboard through', () => {
    h.api.insertMedia('a.jpg')
    h.api.insertAudio('audio-1.m4a')
    for (const sel of ['.moodiary-image', '.moodiary-media--audio']) {
      expect(stopEvent(sel, 'mousedown')).toBe(true)
      expect(stopEvent(sel, 'paste')).toBe(false)
      expect(stopEvent(sel, 'drop')).toBe(false)
    }
  })

  it('keeps the keyboard path: backspace after a block selects it, a second one deletes it', async () => {
    h.api.insertMedia('a.jpg')
    expect(h.editor.state.selection).toBeInstanceOf(TextSelection)
    await h.press('Backspace')
    expect(h.editor.state.selection).toBeInstanceOf(NodeSelection)
    await h.press('Backspace')
    expect(nodesOf('image')).toHaveLength(0)
  })

  it('tapping the image previews it without touching the selection', async () => {
    await h.type('头')
    h.api.insertMedia('image-1.jpg')
    await nextTick()
    const before = h.editor.state.selection.toJSON()
    const img = h.editor.view.dom.querySelector('.moodiary-image__img')!
    bodyRect(img, 100, 300)
    const end = tap(img, 200)
    expect(end.defaultPrevented).toBe(true)
    expect(h.lastPost('imageTap')?.payload).toMatchObject({ src: 'image-1.jpg' })
    expect(h.editor.state.selection.toJSON()).toEqual(before)
  })

  it('tapping the gap above or below a block drops the caret there', async () => {
    h.api.insertMedia('image-1.jpg')
    h.api.insertMedia('image-2.jpg')
    await nextTick()
    const blocks = h.editor.view.dom.querySelectorAll('.moodiary-image')
    const second = blocks[1]
    bodyRect(second.querySelector('.moodiary-block__body')!, 100, 300)
    tap(second, 90)
    expect(blockTypes()).toEqual(['image', 'paragraph', 'image', 'paragraph'])
    expect(h.editor.state.selection.from).toBe(posOf('image', 1) - 1)
    expect(h.lastPost('imageTap')).toBeUndefined()
  })

  it('tapping an audio card body does nothing', async () => {
    h.api.insertAudio('audio-1.m4a')
    await nextTick()
    const before = h.editor.getJSON()
    const card = h.editor.view.dom.querySelector('.moodiary-media--audio .moodiary-block__body')!
    bodyRect(card, 100, 160)
    const end = tap(card, 130)
    expect(end.defaultPrevented).toBe(true)
    expect(h.editor.getJSON()).toEqual(before)
  })

  it('a long press or the touch that stops a fling is not a tap', async () => {
    h.api.insertMedia('image-1.jpg')
    await nextTick()
    const img = h.editor.view.dom.querySelector('.moodiary-image__img')!
    bodyRect(img, 100, 300)
    const down = new Event('pointerdown', { bubbles: true }) as PointerEvent
    Object.assign(down, { pointerType: 'touch', clientX: 50, clientY: 200 })
    img.dispatchEvent(down)
    vi.advanceTimersByTime(600)
    const end = new Event('touchend', { bubbles: true, cancelable: true }) as TouchEvent
    Object.defineProperty(end, 'touches', { value: [] })
    Object.defineProperty(end, 'changedTouches', { value: [{ clientX: 50, clientY: 200 }] })
    img.dispatchEvent(end)
    expect(end.defaultPrevented).toBe(false)

    document.dispatchEvent(new Event('scroll'))
    expect(tap(img, 200).defaultPrevented).toBe(false)
    expect(h.lastPost('imageTap')).toBeUndefined()
  })
})

describe('scrolling to a selected block', () => {
  it('does not bounce a block taller than the viewport', async () => {
    h.api.insertMedia('image-1.jpg')
    await nextTick()
    const viewport = document.createElement('div')
    viewport.className = 'moodiary-editor-viewport'
    const host = h.editor.view.dom.parentElement!
    host.parentElement!.insertBefore(viewport, host)
    viewport.appendChild(host)
    let scrollTop = 0
    Object.defineProperty(viewport, 'scrollTop', { get: () => scrollTop, set: (v: number) => (scrollTop = v) })
    vi.spyOn(viewport, 'getBoundingClientRect').mockReturnValue({ top: 0, bottom: 380 } as DOMRect)
    const block = h.editor.view.nodeDOM(posOf('image')) as HTMLElement
    vi.spyOn(block, 'getBoundingClientRect').mockImplementation(
      () => ({ top: 300 - scrollTop, bottom: 800 - scrollTop }) as DOMRect,
    )
    h.editor.commands.setNodeSelection(posOf('image'))
    const view = h.editor.view
    for (let i = 0; i < 6; i++) view.someProp('handleScrollToSelection', (f) => f(view))
    expect(scrollTop).toBe(0)

    vi.spyOn(block, 'getBoundingClientRect').mockImplementation(
      () => ({ top: 600 - scrollTop, bottom: 1100 - scrollTop }) as DOMRect,
    )
    for (let i = 0; i < 6; i++) view.someProp('handleScrollToSelection', (f) => f(view))
    expect(scrollTop).toBe(592)
  })
})

describe('HTML parsing (clipboard)', () => {
  const paste = (html: string): void => {
    h.editor.view.pasteHTML(html, new Event('paste') as unknown as ClipboardEvent)
  }

  it('strips the media prefix and clamps or drops hostile size attributes', () => {
    h.api.insertMedia('image-1.jpg')
    paste(h.editor.getHTML())
    expect(nodesOf('image').every((a) => String(a.src).startsWith('image-'))).toBe(true)
    paste('<img src="image-2.jpg" data-width-percent="999"><img src="image-3.jpg" data-width-percent="abc">')
    expect(nodesOf('image').find((a) => a.src === 'image-2.jpg')?.widthPercent).toBe(100)
    expect(nodesOf('image').find((a) => a.src === 'image-3.jpg')?.widthPercent).toBeNull()
    paste('<img src="image-4.jpg" width="300" height="200">')
    expect(nodesOf('image').find((a) => a.src === 'image-4.jpg')).not.toHaveProperty('width')
    expect(h.editor.getHTML()).not.toContain('width="300"')
  })
})
