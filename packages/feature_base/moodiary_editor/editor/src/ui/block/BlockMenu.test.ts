import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { createElement } from 'react'
import { fireEvent, render } from '@testing-library/react'
import { WIDTH_PERCENT_STOPS } from '@/core/editor/media-size'
import { dismissOverlay } from '@/core/state/overlay'
import { runUndoToast, undoToast } from '@/core/state/undo-toast'
import { flush, renderEditor, type EditorFixture } from '@/test/editor'
import BlockMenu from './BlockMenu'
import { blockMenu, openBlockMenu } from './block-menu'

let h: EditorFixture

beforeEach(async () => {
  h = renderEditor()
  render(createElement(BlockMenu, { editor: h.editor }))
  h.api.insertMedia('image-1.jpg')
  await flush()
})

afterEach(() => {
  h.destroy()
  vi.useRealTimers()
})

const widths = (): unknown[] => h.nodes('image').map((n) => n.attrs?.widthPercent)
const posOf = (type: string, index = 0): number => {
  const found: number[] = []
  h.editor.state.doc.descendants((n, pos) => {
    if (n.type.name === type) found.push(pos)
    return true
  })
  return found[index]
}
const blockTypes = (): string[] => h.editor.getJSON().content!.map((n) => n.type!)
const handles = (): HTMLElement[] => Array.from(h.editor.view.dom.querySelectorAll('.moodiary-block__handle'))
const panel = (): HTMLElement | null => document.body.querySelector('.moodiary-popover')
const slider = (): HTMLInputElement | null => panel()?.querySelector('input[type="range"]') ?? null
const button = (label: string): HTMLButtonElement => {
  const hit = Array.from(panel()?.querySelectorAll('button') ?? []).find((el) => el.textContent?.trim() === label)
  if (!hit) throw new Error(`no button "${label}"`)
  return hit
}

const openMenu = async (index = 0): Promise<void> => {
  fireEvent.click(handles()[index])
  await flush()
}
const preview = async (percent: number): Promise<void> => {
  fireEvent.change(slider()!, { target: { value: String(percent) } })
  await flush()
}
const release = async (percent: number): Promise<void> => {
  await preview(percent)
  fireEvent.pointerUp(slider()!)
  await flush()
}

describe('block handle and menu', () => {
  it('shows the handle only while editable', async () => {
    expect(handles()).toHaveLength(1)
    h.setEditable(false)
    await flush()
    expect(handles()).toHaveLength(0)
    h.setEditable(true)
    await flush()
    expect(handles()).toHaveLength(1)
  })

  it('opens next to that block, outlines only it, and keeps the keyboard where it was', async () => {
    h.api.insertMedia('image-2.jpg')
    await flush()
    h.editor.view.focus()
    await openMenu(1)
    expect(panel()).not.toBeNull()
    const outlined = Array.from(h.editor.view.dom.querySelectorAll('.moodiary-image')).map((w) =>
      w.classList.contains('is-menu-open'),
    )
    expect(outlined).toEqual([false, true])
    expect(h.lastPost('overlay')?.payload).toBe(true)
    await release(50)
    expect(h.editor.view.hasFocus()).toBe(true)
  })

  it('previews while dragging and writes the snapped width on release', async () => {
    await openMenu()
    await preview(62)
    expect(h.editor.view.dom.querySelector<HTMLElement>('.moodiary-image')?.style.maxWidth).toBe('62%')
    expect(widths()).toEqual([null])
    await preview(70)
    await release(52)
    expect(widths()).toEqual([50])
  })

  it('offers the stops and a reset, and closes on an outside tap', async () => {
    await openMenu()
    const stops = Array.from(panel()!.querySelectorAll<HTMLButtonElement>('.moodiary-width__stop'))
    expect(stops.map((el) => Number(el.textContent))).toEqual([...WIDTH_PERCENT_STOPS])
    fireEvent.click(stops[2])
    expect(widths()).toEqual([75])
    fireEvent.click(button('恢复默认'))
    expect(widths()).toEqual([null])
    fireEvent.touchStart(panel()!.previousElementSibling!)
    await flush()
    expect(panel()).toBeNull()
    expect(blockMenu.get().target).toBeNull()
    expect(h.lastPost('overlay')?.payload).toBe(false)
  })

  it('changes its own block, not whichever one happens to be selected', async () => {
    h.api.insertMedia('image-2.jpg')
    await flush()
    h.editor.commands.setNodeSelection(posOf('image', 0))
    await openMenu(1)
    fireEvent.click(panel()!.querySelectorAll('.moodiary-width__stop')[1])
    expect(widths()).toEqual([null, 50])
  })

  it('inserts a paragraph above or below and puts the caret there', async () => {
    await openMenu()
    fireEvent.click(button('在下方插入文字'))
    await flush()
    expect(blockTypes()).toEqual(['image', 'paragraph', 'paragraph'])
    expect(h.editor.state.selection.from).toBe(posOf('image') + 2)
    expect(h.editor.view.hasFocus()).toBe(true)
    await openMenu()
    fireEvent.click(button('在上方插入文字'))
    await flush()
    expect(blockTypes()).toEqual(['paragraph', 'image', 'paragraph', 'paragraph'])
    expect(h.editor.state.selection.from).toBe(1)
  })

  it('deletes with an undo toast that goes away once the text changes again', async () => {
    // 插入与删除隔开一个 history 分组窗口，撤销才只还原删除
    vi.useFakeTimers()
    await vi.advanceTimersByTimeAsync(1000)
    await openMenu()
    fireEvent.click(button('删除'))
    expect(h.nodes('image')).toHaveLength(0)
    expect(undoToast.get().visible).toBe(true)
    runUndoToast()
    expect(h.nodes('image')).toHaveLength(1)
    expect(undoToast.get().visible).toBe(false)

    await vi.advanceTimersByTimeAsync(1000)
    await openMenu()
    fireEvent.click(button('删除'))
    expect(undoToast.get().visible).toBe(true)
    await h.insert('字')
    expect(undoToast.get().visible).toBe(false)
  })

  it('the back button closes the menu', async () => {
    await openMenu()
    dismissOverlay()
    await flush()
    expect(panel()).toBeNull()
    expect(h.lastPost('overlay')?.payload).toBe(false)
  })

  it('has no width control for audio', async () => {
    h.api.insertAudio('audio-1.m4a')
    await flush()
    const anchor = h.editor.view.dom.querySelector<HTMLElement>('.moodiary-media--audio')!
    openBlockMenu({ owner: 'audio', kind: 'audio', anchor, getPos: () => posOf('audio') })
    await flush()
    expect(panel()).not.toBeNull()
    expect(slider()).toBeNull()
    expect(button('删除')).toBeDefined()
  })
})
