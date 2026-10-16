import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { act, createElement, createRef } from 'react'
import { fireEvent, render } from '@testing-library/react'
import { NodeSelection, TextSelection } from '@tiptap/pm/state'
import { bindApi, installBridge, markReady, resetBridgeForTest } from '@/core/bridge'
import { CHANGE_DEBOUNCE_MS, installChangeFlushers } from '@/core/bridge/change'
import { post } from '@/core/bridge/post'
import type { EditorState } from '@/core/editor/state'
import { modeStore } from '@/core/state/editable'
import { doc, flush, p, renderEditor, type EditorFixture, type Posted } from '@/test/editor'
import { interceptLinkClick } from '@/ui/link-intercept'
import Popover, { type PopoverHandle } from '@/ui/overlay/Popover'

let h: EditorFixture

beforeEach(() => {
  vi.useFakeTimers()
  h = renderEditor()
  installBridge()
  bindApi(h.api)
  h.load(doc([p('hello')]))
  h.editor.commands.setTextSelection(6)
})

afterEach(() => {
  h.destroy()
  resetBridgeForTest()
  modeStore.setState({ panelMode: false })
  vi.useRealTimers()
})

const of = (type: string): Posted[] => h.posted.filter((m) => m.type === type)
const bridge = (): Window['MoodiaryBridge'] => window.MoodiaryBridge

describe('change', () => {
  it('is debounced and carries the whole document', async () => {
    h.editor.commands.insertContent(' a')
    h.editor.commands.insertContent('b')
    await vi.advanceTimersByTimeAsync(CHANGE_DEBOUNCE_MS - 50)
    expect(of('change')).toHaveLength(0)
    await vi.advanceTimersByTimeAsync(100)
    expect(of('change')).toHaveLength(1)
    const sent = JSON.parse(of('change')[0].payload as string)
    expect(sent).toEqual({ type: 'doc', attrs: { v: 2 }, content: [p('hello ab')] })
  })

  it('flush() sends the pending change at once, and nothing when idle', () => {
    bridge().flush()
    expect(of('change')).toHaveLength(0)
    h.editor.commands.insertContent('!')
    bridge().flush()
    expect(of('change')).toHaveLength(1)
    bridge().flush()
    expect(of('change')).toHaveLength(1)
  })

  it('flush(reqId) answers after the change', () => {
    h.editor.commands.insertContent('?')
    bridge().flush('f1')
    const types = h.posted.map((m) => m.type)
    expect(types.lastIndexOf('flushed')).toBeGreaterThan(types.lastIndexOf('change'))
    expect(of('flushed').at(-1)?.payload).toEqual({ reqId: 'f1' })
  })

  it('pagehide and a hidden page flush too', () => {
    installChangeFlushers()
    h.editor.commands.insertContent('1')
    window.dispatchEvent(new Event('pagehide'))
    expect(of('change')).toHaveLength(1)
    h.editor.commands.insertContent('2')
    Object.defineProperty(document, 'visibilityState', { value: 'hidden', configurable: true })
    document.dispatchEvent(new Event('visibilitychange'))
    expect(of('change')).toHaveLength(2)
    Object.defineProperty(document, 'visibilityState', { value: 'visible', configurable: true })
  })
})

describe('state', () => {
  it('is coalesced to one message per frame', async () => {
    h.posted.length = 0
    h.editor.commands.toggleBold()
    h.editor.commands.insertContent('x')
    h.editor.commands.insertContent('y')
    await vi.advanceTimersByTimeAsync(20)
    expect(of('state')).toHaveLength(1)
    expect(of('state')[0].payload).toMatchObject({ marks: { bold: true }, canUndo: true, selection: 'caret' })
  })

  it('is posted right after ready', () => {
    h.posted.length = 0
    markReady()
    expect(h.posted.map((m) => m.type)).toEqual(['ready', 'state'])
  })
})

describe('EditorState', () => {
  const state = (): EditorState => h.api.currentState()!
  const select = (from: number, to = from): void => {
    h.editor.view.dispatch(h.editor.state.tr.setSelection(TextSelection.create(h.editor.state.doc, from, to)))
  }

  it('has the contract shape for a plain caret', () => {
    h.load(doc([p('hello')]))
    select(2)
    expect(state()).toEqual({
      marks: { bold: false, italic: false, underline: false, strike: false, code: false, highlight: false, link: false },
      block: 'paragraph',
      list: null,
      canIndent: false,
      canOutdent: false,
      canUndo: false,
      canRedo: false,
      selection: 'caret',
      node: null,
      inTable: false,
      link: null,
      selectedText: '',
    })
  })

  it('reports active marks, a link and the selection kind', () => {
    h.load(
      doc([
        {
          type: 'paragraph',
          content: [
            { type: 'text', text: 'ab', marks: [{ type: 'bold' }, { type: 'highlight' }] },
            { type: 'text', text: 'link', marks: [{ type: 'link', attrs: { href: 'https://x.y' } }] },
          ],
        },
      ]),
    )
    select(1, 3)
    expect(state().marks).toMatchObject({ bold: true, highlight: true, italic: false })
    expect(state().selection).toBe('text')
    select(5)
    expect(state().link).toEqual({ href: 'https://x.y', text: 'link' })
  })

  it('maps headings, quotes, code and lists', () => {
    h.load(
      doc([
        { type: 'heading', attrs: { level: 3 }, content: [{ type: 'text', text: 'h' }] },
        { type: 'blockquote', content: [p('q')] },
        { type: 'codeBlock', attrs: { language: null }, content: [{ type: 'text', text: 'c' }] },
        {
          type: 'taskList',
          content: [
            { type: 'taskItem', attrs: { checked: false }, content: [p('t1')] },
            { type: 'taskItem', attrs: { checked: false }, content: [p('t2')] },
          ],
        },
      ]),
    )
    select(2)
    expect(state().block).toBe('heading3')
    select(5)
    expect(state().block).toBe('blockquote')
    select(9)
    expect(state().block).toBe('codeBlock')
    let second = 0
    h.editor.state.doc.descendants((node, pos) => {
      if (node.isText && node.text === 't2') second = pos + 1
    })
    select(second)
    expect(state()).toMatchObject({ list: 'task', canIndent: true, canOutdent: true })
  })

  it('describes a selected block node and the table context', () => {
    h.load(doc([{ type: 'image', attrs: { src: 'image-1.png', widthPercent: 50 } }, p('x')]))
    h.editor.view.dispatch(h.editor.state.tr.setSelection(NodeSelection.create(h.editor.state.doc, 0)))
    expect(state().selection).toBe('node')
    expect(state().node).toEqual({
      type: 'image',
      attrs: { src: 'image-1.png', name: null, widthPercent: 50 },
    })
    h.load(doc([p()]))
    h.api.exec('insertTable')
    expect(state().inTable).toBe(true)
  })

  it('tracks undo depth and read-only', () => {
    h.load(doc([p('a')]))
    select(2)
    h.editor.commands.insertContent('b')
    expect(state()).toMatchObject({ canUndo: true, canRedo: false })
    h.editor.commands.undo()
    expect(state()).toMatchObject({ canUndo: false, canRedo: true })
    h.api.setEditable(false)
    expect(h.editor.isEditable).toBe(false)
  })
})

describe('Flutter → JS', () => {
  it('exposes every bridge method', () => {
    expect(Object.keys(bridge()).sort()).toEqual(
      [
        'respond', 'setContent', 'setTitle', 'setEditable', 'setMeta', 'setLinks', 'setTheme',
        'focus', 'blur', 'focusTitle', 'holdSelection', 'resolveImage', 'resolveLinkCandidates', 'scrollToHeading',
        'getScrollY', 'setScrollY', 'resumeVideo', 'setPanelMode', 'flush', 'exec',
      ].sort(),
    )
  })

  it('exec routes to the command table', () => {
    bridge().exec('setHeading', { level: 1 })
    expect(h.topTypes()[0]).toBe('heading')
    bridge().exec('nope')
    expect(h.lastPost('error')?.payload).toContain('nope')
  })

  it('setEditable toggles the editor', () => {
    bridge().setEditable(false)
    expect(h.editor.isEditable).toBe(false)
    bridge().setEditable(true)
    expect(h.editor.isEditable).toBe(true)
  })
})

describe('taps', () => {
  const tap = (el: Element): void => {
    fireEvent.pointerDown(el, { clientX: 10, clientY: 10, isPrimary: true })
    fireEvent.pointerUp(el, { clientX: 12, clientY: 11, isPrimary: true })
  }

  it('editorTap only for text taps in panel mode', async () => {
    h.load(doc([p('text'), { type: 'image', attrs: { src: 'image-1.png' } }]))
    await flush()
    const para = h.editor.view.dom.querySelector('p')!
    tap(para)
    expect(of('editorTap')).toHaveLength(0)
    h.panel.on = true
    tap(para)
    expect(of('editorTap')).toHaveLength(1)
    tap(h.editor.view.dom.querySelector('img')!)
    expect(of('editorTap')).toHaveLength(1)
  })

  it('read-only taps on images and attachments go to Flutter', async () => {
    h.load(
      doc([
        { type: 'image', attrs: { src: 'image-1.png' } },
        { type: 'image', attrs: { src: 'image-2.png' } },
        { type: 'attachment', attrs: { src: 'file-1.pdf', name: 'a.pdf', mime: 'application/pdf' } },
        { type: 'attachment', attrs: { src: 'file-2.pdf', mime: 'application/pdf' } },
      ]),
    )
    await flush()
    fireEvent.click(h.editor.view.dom.querySelectorAll('img')[1])
    expect(of('imageTap')).toHaveLength(0)
    h.api.setEditable(false)
    fireEvent.click(h.editor.view.dom.querySelectorAll('img')[1])
    expect(h.lastPost('imageTap')?.payload).toEqual({
      src: 'image-2.png',
      srcs: ['image-1.png', 'image-2.png'],
      index: 1,
    })
    const cards = h.editor.view.dom.querySelectorAll('.md-attachment__card')
    fireEvent.click(cards[0])
    expect(h.lastPost('attachmentTap')?.payload).toEqual({ src: 'file-1.pdf', name: 'a.pdf', mime: 'application/pdf' })
    fireEvent.click(cards[1])
    expect(h.lastPost('attachmentTap')?.payload).toEqual({ src: 'file-2.pdf', name: null, mime: 'application/pdf' })
  })

  it('links never navigate; read-only links and diary links go to Flutter', () => {
    h.load(
      doc([
        {
          type: 'paragraph',
          content: [
            { type: 'text', text: 'site', marks: [{ type: 'link', attrs: { href: 'https://x.y' } }] },
            { type: 'diaryLink', attrs: { id: 'd1', label: '那天' } },
          ],
        },
      ]),
    )
    const click = (el: Element): MouseEvent => {
      const e = new MouseEvent('click', { bubbles: true, cancelable: true })
      el.addEventListener('click', (ev) => interceptLinkClick(h.editor, ev as MouseEvent), { once: true })
      el.dispatchEvent(e)
      return e
    }
    const anchor = h.editor.view.dom.querySelector('a')!
    expect(click(anchor).defaultPrevented).toBe(true)
    expect(of('urlTap')).toHaveLength(0)
    h.api.setEditable(false)
    expect(click(anchor).defaultPrevented).toBe(true)
    expect(h.lastPost('urlTap')?.payload).toEqual({ href: 'https://x.y' })
    click(h.editor.view.dom.querySelector('[data-type="diaryLink"]')!)
    expect(h.lastPost('linkTap')?.payload).toEqual({ id: 'd1' })
  })

  it('pasted image files go through saveImage and land as image blocks', async () => {
    vi.useRealTimers()
    h.load(doc([p('x')]))
    h.editor.commands.setTextSelection(2)
    const file = new File([new Uint8Array([1, 2, 3])], 'shot.png', { type: 'image/png' })
    const event = new Event('paste', { bubbles: true, cancelable: true })
    Object.defineProperty(event, 'clipboardData', {
      value: { files: [file], types: ['Files'], getData: () => '' },
    })
    h.editor.view.dom.dispatchEvent(event)
    await flush()
    const save = h.lastPost('saveImage')?.payload as { id: string; dataUri: string; name: string }
    expect(save).toMatchObject({ name: 'shot.png', dataUri: expect.stringMatching(/^data:image\/png;base64,/) })
    h.api.resolveUpload(save.id, 'image-saved.png')
    expect(h.nodes('image')[0].attrs!.src).toBe('image-saved.png')
  })
})

describe('overlay', () => {
  it('brackets an open popover, and a choice made in it arrives before the close', () => {
    const pop = createRef<PopoverHandle>()
    const view = render(createElement(Popover, { ref: pop }, 'body'))
    act(() => pop.current!.open(document.body))
    expect(h.lastPost('overlay')?.payload).toEqual({ open: true })
    act(() => {
      pop.current!.close()
      post('newPlace')
    })
    const order = h.posted.map((m) => m.type).filter((type) => type === 'overlay' || type === 'newPlace')
    expect(order).toEqual(['overlay', 'newPlace', 'overlay'])
    expect(h.lastPost('overlay')?.payload).toEqual({ open: false })
    view.unmount()
  })
})
