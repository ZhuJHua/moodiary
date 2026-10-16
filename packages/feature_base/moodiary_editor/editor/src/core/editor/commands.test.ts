import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { NodeSelection, TextSelection } from '@tiptap/pm/state'
import type { JSONContent } from '@tiptap/core'
import { doc, flush, p, renderEditor, type EditorFixture } from '@/test/editor'
import { EXEC_COMMANDS, normalizeHref } from './commands'

let h: EditorFixture

beforeEach(() => {
  h = renderEditor()
})

afterEach(() => {
  h.destroy()
})

const exec = (command: string, args?: Record<string, unknown>): void => h.api.exec(command, args)
const caretAt = (pos: number): void => {
  h.editor.view.dispatch(h.editor.state.tr.setSelection(TextSelection.create(h.editor.state.doc, pos)))
}
const selectNodeAt = (pos: number): void => {
  h.editor.view.dispatch(h.editor.state.tr.setSelection(NodeSelection.create(h.editor.state.doc, pos)))
}
const selectText = (from: number, to: number): void => {
  h.editor.view.dispatch(h.editor.state.tr.setSelection(TextSelection.create(h.editor.state.doc, from, to)))
}
const top = (): JSONContent[] => h.editor.getJSON().content ?? []
const parentType = (): string => h.editor.state.selection.$from.parent.type.name

describe('contract', () => {
  it('implements every command in the bridge table', () => {
    const table = [
      'toggleBold', 'toggleItalic', 'toggleUnderline', 'toggleStrike', 'toggleCode', 'toggleHighlight',
      'clearFormatting', 'setParagraph', 'setHeading', 'toggleBlockquote', 'toggleCodeBlock',
      'toggleBulletList', 'toggleOrderedList', 'toggleTaskList', 'indent', 'outdent', 'undo', 'redo',
      'insertImage', 'insertVideo', 'insertAudio', 'insertAttachment', 'insertTable', 'insertHorizontalRule',
      'insertBlockquote', 'insertCodeBlock', 'insertTaskList', 'insertDiaryLink', 'setLink', 'unsetLink',
      'openLink', 'copyLink', 'setMediaWidth', 'setMediaName', 'moveBlockUp', 'moveBlockDown', 'deleteBlock',
      'setHorizontalRule', 'previewImage', 'openAttachment', 'copyCode', 'exitCode', 'caretAfterNode', 'tableAddRowAfter',
      'tableDeleteRow', 'tableAddColumnAfter', 'tableDeleteColumn', 'tableToggleHeaderRow', 'tableDelete',
      'search', 'searchNext', 'searchPrev', 'replace', 'replaceAll', 'clearSearch',
    ]
    expect([...EXEC_COMMANDS].sort()).toEqual([...table].sort())
  })

  it('reports an unknown command as an error', () => {
    exec('explode')
    expect(h.lastPost('error')?.payload).toContain('explode')
  })

  it('never focuses the editor in panel mode, but does otherwise', async () => {
    h.load(doc([p('abc')]))
    const focus = vi.spyOn(h.editor.view, 'focus')
    h.panel.on = true
    exec('toggleBold')
    await flush()
    expect(focus).not.toHaveBeenCalled()
    h.panel.on = false
    exec('toggleBold')
    await flush()
    expect(focus).toHaveBeenCalled()
  })
})

describe('marks and blocks', () => {
  beforeEach(() => h.load(doc([p('hello world')])))

  it('toggles marks on the selection', () => {
    selectText(1, 6)
    for (const c of ['toggleBold', 'toggleItalic', 'toggleUnderline', 'toggleStrike', 'toggleHighlight']) exec(c)
    const marks = h.nodes('text')[0].marks!.map((m) => m.type)
    expect(marks.sort()).toEqual(['bold', 'highlight', 'italic', 'strike', 'underline'])
    expect(h.nodes('text')[0].marks!.find((m) => m.type === 'highlight')!.attrs).toEqual({ color: null })
    exec('clearFormatting')
    expect(h.nodes('text')[0].marks).toBeUndefined()
  })

  it('setHeading toggles back to a paragraph', () => {
    caretAt(2)
    exec('setHeading', { level: 2 })
    expect(top()[0]).toMatchObject({ type: 'heading', attrs: { level: 2 } })
    exec('setHeading', { level: 2 })
    expect(top()[0].type).toBe('paragraph')
  })

  it('list toggles switch type and remove the active one', () => {
    caretAt(2)
    exec('toggleBulletList')
    expect(top()[0].type).toBe('bulletList')
    exec('toggleTaskList')
    expect(top()[0].type).toBe('taskList')
    exec('toggleTaskList')
    expect(top()[0].type).toBe('paragraph')
  })

  it('indent / outdent are no-ops outside lists', () => {
    caretAt(2)
    exec('indent')
    exec('outdent')
    expect(top()).toEqual([p('hello world')])
    expect(h.lastPost('error')).toBeUndefined()
  })
})

describe('insert placement', () => {
  it('replaces an empty paragraph and leaves the caret in a paragraph after the block', () => {
    h.load(doc([p('a'), p(), p('b')]))
    caretAt(4)
    exec('insertImage', { name: 'image-1.png' })
    expect(h.topTypes()).toEqual(['paragraph', 'image', 'paragraph', 'paragraph'])
    expect(top()[2]).toEqual(p())
    expect(parentType()).toBe('paragraph')
    expect(h.editor.state.selection.$from.parent.content.size).toBe(0)
  })

  it('goes after the current block, not into the middle of it', () => {
    h.load(doc([p('hello'), p('next')]))
    caretAt(3)
    exec('insertVideo', { name: 'video-1.mp4' })
    exec('insertAudio', { name: 'audio-1.m4a' })
    expect(h.topTypes()).toEqual(['paragraph', 'video', 'audio', 'paragraph', 'paragraph'])
    expect(top()[0]).toEqual(p('hello'))
    expect(h.nodes('video')[0].attrs).toEqual({ src: 'video-1.mp4', name: null, widthPercent: null })
    expect(h.nodes('audio')[0].attrs).toEqual({ src: 'audio-1.m4a', name: null })
  })

  it('inserts after a selected block', () => {
    h.load(doc([{ type: 'image', attrs: { src: 'image-1.png' } }, p('x')]))
    selectNodeAt(0)
    exec('insertAttachment', { name: 'file-1.pdf', displayName: '报告.pdf', mime: 'application/pdf', size: 2048 })
    expect(h.topTypes()).toEqual(['image', 'attachment', 'paragraph', 'paragraph'])
    expect(h.nodes('attachment')[0].attrs).toEqual({
      src: 'file-1.pdf',
      name: '报告.pdf',
      mime: 'application/pdf',
      size: 2048,
    })
  })

  it('displayName becomes the trimmed media name, blank means none', () => {
    h.load(doc([p('a')]))
    caretAt(2)
    exec('insertImage', { name: 'image-1.png', displayName: ' 海边 ' })
    exec('insertVideo', { name: 'video-1.mp4', displayName: '旅行' })
    exec('insertAudio', { name: 'audio-1.m4a', displayName: '   ' })
    exec('insertAttachment', { name: 'file-1.pdf' })
    expect(['image', 'video', 'audio', 'attachment'].map((t) => h.nodes(t)[0].attrs!.name)).toEqual([
      '海边',
      '旅行',
      null,
      null,
    ])
  })

  it('horizontal rule takes a variant', () => {
    h.load(doc([p('a')]))
    caretAt(2)
    exec('insertHorizontalRule', { variant: 'wavy' })
    expect(h.nodes('horizontalRule')[0].attrs).toEqual({ variant: 'wavy', label: null })
  })

  it('container inserts turn an empty paragraph, or add a new block with the caret inside', () => {
    h.load(doc([p()]))
    caretAt(1)
    exec('insertBlockquote')
    expect(h.topTypes()[0]).toBe('blockquote')
    h.load(doc([p('text')]))
    caretAt(3)
    exec('insertCodeBlock')
    expect(h.topTypes().slice(0, 2)).toEqual(['paragraph', 'codeBlock'])
    expect(parentType()).toBe('codeBlock')
    exec('insertTaskList')
    expect(h.topTypes().slice(0, 3)).toEqual(['paragraph', 'codeBlock', 'taskList'])
    expect(h.editor.state.selection.$from.node(-1).type.name).toBe('taskItem')
  })

  it('table and diary link', () => {
    h.load(doc([p()]))
    caretAt(1)
    exec('insertTable')
    expect(h.nodes('tableRow')).toHaveLength(3)
    expect(h.nodes('tableHeader')).toHaveLength(3)
    exec('tableAddRowAfter')
    expect(h.nodes('tableRow')).toHaveLength(4)
    exec('tableDelete')
    expect(h.nodes('table')).toHaveLength(0)
    h.load(doc([p('看 ')]))
    caretAt(3)
    exec('insertDiaryLink')
    expect(h.editor.getText()).toBe('看 [[')
  })
})

describe('links', () => {
  it('normalizes hrefs without a scheme', () => {
    expect(normalizeHref('example.com')).toBe('https://example.com')
    expect(normalizeHref('mailto:a@b.c')).toBe('mailto:a@b.c')
    expect(normalizeHref('tel:123')).toBe('tel:123')
    expect(normalizeHref('example.com:8080/x')).toBe('https://example.com:8080/x')
    expect(normalizeHref('javascript:alert(1)')).toBe('')
    expect(normalizeHref('file:///etc/hosts')).toBe('')
    expect(normalizeHref('  ')).toBe('')
  })

  it('inserts linked text at the caret and replaces it when editing', () => {
    h.load(doc([p('go ')]))
    caretAt(4)
    exec('setLink', { text: '官网', href: 'moodiary.net' })
    const linked = h.nodes('text').find((t) => t.marks?.length)!
    expect(linked).toEqual({ type: 'text', text: '官网', marks: [{ type: 'link', attrs: { href: 'https://moodiary.net' } }] })
    caretAt(5)
    exec('setLink', { text: '新站', href: 'https://x.y' })
    expect(h.editor.getText()).toBe('go 新站')
    caretAt(5)
    exec('openLink')
    expect(h.lastPost('urlTap')?.payload).toEqual({ href: 'https://x.y' })
    exec('copyLink')
    expect(h.lastPost('copy')?.payload).toEqual({ text: 'https://x.y' })
    exec('unsetLink')
    expect(h.nodes('text').every((t) => !t.marks)).toBe(true)
  })

  it('wraps a selection', () => {
    h.load(doc([p('hello world')]))
    selectText(7, 12)
    exec('setLink', { text: '', href: 'https://w.org' })
    expect(h.nodes('text')[1]).toEqual({ type: 'text', text: 'world', marks: [{ type: 'link', attrs: { href: 'https://w.org' } }] })
  })

  it('treats a caret at either end of a link as inside it', () => {
    h.load(doc([{ type: 'paragraph', content: [{ type: 'text', text: 'go ' }, { type: 'text', text: 'site', marks: [{ type: 'link', attrs: { href: 'https://s.io' } }] }] }]))
    caretAt(8)
    expect(h.api.currentState()?.link).toEqual({ href: 'https://s.io', text: 'site' })
    exec('openLink')
    expect(h.lastPost('urlTap')?.payload).toEqual({ href: 'https://s.io' })
    exec('unsetLink')
    expect(h.nodes('text').every((t) => !t.marks)).toBe(true)
  })

  it('keeps the marks inside a selection whose text is unchanged', () => {
    h.load(doc([{ type: 'paragraph', content: [{ type: 'text', text: 'ab' }, { type: 'text', text: 'cd', marks: [{ type: 'bold' }] }] }]))
    selectText(1, 5)
    exec('setLink', { text: 'abcd', href: 'w.org' })
    expect(h.nodes('text').map((t) => t.marks?.map((m) => m.type).sort())).toEqual([['link'], ['bold', 'link']])
  })
})

describe('block actions', () => {
  beforeEach(() =>
    h.load(
      doc([
        p('one'),
        { type: 'image', attrs: { src: 'image-1.png' } },
        { type: 'horizontalRule' },
        { type: 'attachment', attrs: { src: 'file-1.pdf', name: 'a.pdf', mime: 'application/pdf', size: 1 } },
        p('two'),
      ]),
    ),
  )

  it('media width snaps and only applies to a selected image or video', () => {
    selectNodeAt(5)
    exec('setMediaWidth', { percent: 50 })
    expect(h.nodes('image')[0].attrs!.widthPercent).toBe(50)
    exec('setMediaWidth', { percent: 70 })
    expect(h.nodes('image')[0].attrs!.widthPercent).toBe(75)
  })

  it('media name applies only to a selected media node and undoes', () => {
    selectNodeAt(5)
    exec('setMediaName', { name: '  海边  ' })
    expect(h.nodes('image')[0].attrs!.name).toBe('海边')
    exec('undo')
    expect(h.nodes('image')[0].attrs!.name).toBeNull()
    selectNodeAt(7)
    exec('setMediaName', { name: ' ' })
    expect(h.nodes('attachment')[0].attrs!.name).toBeNull()
    const before = JSON.stringify(h.editor.getJSON())
    selectNodeAt(6)
    exec('setMediaName', { name: 'x' })
    caretAt(2)
    exec('setMediaName', { name: 'x' })
    expect(JSON.stringify(h.editor.getJSON())).toBe(before)
  })

  it('cards show the media name, or the default label with the extension from src', async () => {
    h.load(
      doc([
        { type: 'audio', attrs: { src: 'audio-1.m4a' } },
        { type: 'attachment', attrs: { src: 'file-1.pdf', name: null } },
      ]),
    )
    await flush()
    const text = (sel: string): string | null | undefined => h.editor.view.dom.querySelector(sel)?.textContent
    expect(text('.md-audio__name')).toBe('音频')
    expect(text('.md-attachment__name')).toBe('附件')
    expect(text('.md-attachment__tile')).toBe('PDF')
    expect(h.posted.map((m) => m.type)).not.toContain('mediaName')
    selectNodeAt(0)
    exec('setMediaName', { name: '晨间' })
    await flush()
    expect(text('.md-audio__name')).toBe('晨间')
  })

  it('moves the selected block or the caret block', () => {
    selectNodeAt(5)
    exec('moveBlockUp')
    expect(h.topTypes()).toEqual(['image', 'paragraph', 'horizontalRule', 'attachment', 'paragraph'])
    expect(h.editor.state.selection).toBeInstanceOf(NodeSelection)
    caretAt(h.editor.state.doc.content.size - 2)
    exec('moveBlockUp')
    expect(h.topTypes().slice(0, 5)).toEqual(['image', 'paragraph', 'horizontalRule', 'paragraph', 'attachment'])
    expect(parentType()).toBe('paragraph')
    expect(h.editor.state.selection.$from.parent.textContent).toBe('two')
    exec('moveBlockDown')
    expect(h.topTypes().slice(0, 5)).toEqual(['image', 'paragraph', 'horizontalRule', 'attachment', 'paragraph'])
  })

  it('keeps a moved block valid inside a list item', () => {
    h.load(
      doc([
        {
          type: 'bulletList',
          content: [{ type: 'listItem', content: [p('first'), { type: 'image', attrs: { src: 'image-2.png' } }] }],
        },
      ]),
    )
    const before = JSON.stringify(h.editor.getJSON())
    selectNodeAt(9)
    exec('moveBlockUp')
    expect(JSON.stringify(h.editor.getJSON())).toBe(before)
  })

  it('hr variant, preview, open attachment, delete and caret after', () => {
    const hrPos = 6
    selectNodeAt(hrPos)
    exec('setHorizontalRule', { variant: 'text', label: '第二天' })
    expect(h.nodes('horizontalRule')[0].attrs).toEqual({ variant: 'text', label: '第二天' })
    selectNodeAt(5)
    exec('previewImage')
    expect(h.lastPost('imageTap')?.payload).toEqual({ src: 'image-1.png', srcs: ['image-1.png'], index: 0 })
    selectNodeAt(7)
    exec('openAttachment')
    expect(h.lastPost('attachmentTap')?.payload).toEqual({ src: 'file-1.pdf', name: 'a.pdf', mime: 'application/pdf' })
    exec('caretAfterNode')
    expect(h.editor.state.selection.$from.parent.textContent).toBe('two')
    selectNodeAt(hrPos)
    exec('deleteBlock')
    expect(h.nodes('horizontalRule')).toHaveLength(0)
  })
})

describe('selection across a Flutter form', () => {
  beforeEach(() => h.load(doc([p('one'), { type: 'horizontalRule' }, p('two')])))

  it('runs on the held selection after the form took focus', () => {
    h.editor.view.focus()
    selectNodeAt(5)
    h.api.holdSelection()
    h.editor.view.dom.blur()
    caretAt(h.editor.state.doc.content.size - 1)
    exec('setHorizontalRule', { variant: 'text', label: 'noon' })
    expect(h.nodes('horizontalRule')[0].attrs).toEqual({ variant: 'text', label: 'noon' })
  })

  it('keeps a held text selection that collapsed before the blur', () => {
    h.editor.view.focus()
    selectText(1, 4)
    h.api.holdSelection()
    caretAt(4)
    h.editor.view.dom.blur()
    h.editor.view.focus()
    expect(h.editor.state.selection.from).toBe(1)
    expect(h.editor.state.selection.to).toBe(4)
  })

  it('gets the held selection back when focus returns without a tap', () => {
    h.editor.view.focus()
    selectNodeAt(5)
    h.api.holdSelection()
    h.editor.view.dom.blur()
    caretAt(h.editor.state.doc.content.size - 1)
    h.editor.view.focus()
    expect(h.editor.state.selection).toBeInstanceOf(NodeSelection)
  })

  it('leaves later caret moves alone when nothing was held', () => {
    h.editor.view.focus()
    selectNodeAt(5)
    h.editor.view.dom.blur()
    caretAt(1)
    h.editor.view.focus()
    expect(h.editor.state.selection.from).toBe(1)
  })

  it('inserts after a selected block instead of replacing it', () => {
    selectNodeAt(5)
    exec('insertTable')
    expect(h.topTypes().slice(0, 3)).toEqual(['paragraph', 'horizontalRule', 'table'])
  })
})

describe('code block', () => {
  beforeEach(() => h.load(doc([{ type: 'codeBlock', content: [{ type: 'text', text: 'let a = 1' }] }])))

  it('copies the code and exits to a paragraph after it', () => {
    caretAt(3)
    exec('copyCode')
    expect(h.lastPost('copy')?.payload).toEqual({ text: 'let a = 1' })
    exec('exitCode')
    expect(h.topTypes()).toEqual(['codeBlock', 'paragraph'])
    expect(parentType()).toBe('paragraph')
  })
})

describe('search', () => {
  beforeEach(() => h.load(doc([p('猫和猫'), p('狗和猫')])))

  it('reports totals and walks the matches', () => {
    exec('search', { query: '猫' })
    expect(h.lastPost('searchState')?.payload).toEqual({ query: '猫', total: 3, current: 1 })
    exec('searchNext')
    expect(h.lastPost('searchState')?.payload).toMatchObject({ current: 2 })
    exec('searchPrev')
    expect(h.lastPost('searchState')?.payload).toMatchObject({ current: 1 })
    exec('replace', { text: '鱼' })
    expect(h.editor.getText()).toBe('鱼和猫\n\n狗和猫')
    expect(h.lastPost('searchState')?.payload).toMatchObject({ total: 2 })
    exec('replaceAll', { text: '鸟' })
    expect(h.editor.getText()).toBe('鱼和鸟\n\n狗和鸟')
    exec('clearSearch')
    expect(h.lastPost('searchState')?.payload).toEqual({ query: '', total: 0, current: 0 })
  })

  it('works read-only but does not replace', () => {
    h.api.setEditable(false)
    exec('search', { query: '狗' })
    expect(h.lastPost('searchState')?.payload).toEqual({ query: '狗', total: 1, current: 1 })
    exec('replaceAll', { text: '猪' })
    expect(h.editor.getText()).toContain('狗')
    exec('toggleBold')
    expect(h.nodes('text').every((t) => !t.marks)).toBe(true)
  })
})

const blocks = [
  ['image', { type: 'image', attrs: { src: 'image-1.png' } }],
  ['video', { type: 'video', attrs: { src: 'video-1.mp4' } }],
  ['audio', { type: 'audio', attrs: { src: 'audio-1.m4a' } }],
  ['attachment', { type: 'attachment', attrs: { src: 'file-1.pdf', name: 'a.pdf' } }],
  ['horizontalRule', { type: 'horizontalRule' }],
] as const

describe('typing while a block is selected', () => {
  for (const [name, block] of blocks) {
    it(`keeps the ${name} and types into a new paragraph after it`, () => {
      h.load(doc([p('before'), block, p('after')]))
      selectNodeAt(8)
      h.type('字')
      expect(h.topTypes()).toEqual(['paragraph', name, 'paragraph', 'paragraph'])
      expect(h.editor.getJSON().content![2]).toEqual(p('字'))
    })
  }

  it('reuses an empty paragraph that already follows the block', () => {
    h.load(doc([{ type: 'image', attrs: { src: 'image-1.png' } }, p()]))
    selectNodeAt(0)
    h.type('a')
    expect(h.editor.getJSON().content).toEqual([
      { type: 'image', attrs: { src: 'image-1.png', name: null, widthPercent: null } },
      p('a'),
    ])
  })

  it('Enter opens a new paragraph after the block', async () => {
    h.load(doc([{ type: 'image', attrs: { src: 'image-1.png' } }, p('x')]))
    selectNodeAt(0)
    await h.press('Enter')
    expect(h.topTypes()).toEqual(['image', 'paragraph', 'paragraph'])
    expect(h.editor.state.selection.$from.parent.content.size).toBe(0)
    expect(h.editor.state.selection.$from.index(0)).toBe(1)
  })

  it('composition and beforeinput leave the block before the browser inserts', () => {
    h.load(doc([{ type: 'image', attrs: { src: 'image-1.png' } }, p('x')]))
    selectNodeAt(0)
    h.editor.view.dom.dispatchEvent(new CompositionEvent('compositionstart', { bubbles: true }))
    expect(h.editor.state.selection).not.toBeInstanceOf(NodeSelection)
    expect(h.topTypes()).toEqual(['image', 'paragraph', 'paragraph'])

    h.load(doc([{ type: 'image', attrs: { src: 'image-1.png' } }, p('x')]))
    selectNodeAt(0)
    const enter = new InputEvent('beforeinput', { inputType: 'insertParagraph', bubbles: true, cancelable: true })
    h.editor.view.dom.dispatchEvent(enter)
    expect(enter.defaultPrevented).toBe(true)
    expect(h.topTypes()).toEqual(['image', 'paragraph', 'paragraph'])
    expect(h.editor.state.selection.$from.index(0)).toBe(1)

    h.load(doc([{ type: 'image', attrs: { src: 'image-1.png' } }, p('x')]))
    selectNodeAt(0)
    const char = new InputEvent('beforeinput', { inputType: 'insertText', data: '安', bubbles: true, cancelable: true })
    h.editor.view.dom.dispatchEvent(char)
    expect(char.defaultPrevented).toBe(true)
    expect(h.topTypes()).toEqual(['image', 'paragraph', 'paragraph'])
    expect(h.editor.getJSON().content![1]).toEqual(p('安'))
  })
})

describe('pressing a block', () => {
  it('selects it without focusing the editor', async () => {
    h.load(doc([p('x'), { type: 'attachment', attrs: { src: 'file-1.pdf', name: 'a.pdf' } }]))
    await flush()
    expect(h.editor.state.selection).not.toBeInstanceOf(NodeSelection)
    const card = h.editor.view.dom.querySelector('.md-attachment__card')!
    const down = new MouseEvent('mousedown', { bubbles: true, cancelable: true, button: 0 })
    card.dispatchEvent(down)
    expect(down.defaultPrevented).toBe(true)
    expect(h.editor.state.selection).toBeInstanceOf(NodeSelection)
    expect((h.editor.state.selection as NodeSelection).node.type.name).toBe('attachment')
    expect(h.editor.isFocused).toBe(false)
  })

  it('leaves player controls alone', async () => {
    h.load(doc([p('x'), { type: 'audio', attrs: { src: 'audio-1.m4a' } }]))
    await flush()
    const play = h.editor.view.dom.querySelector('.md-audio__play')!
    const down = new MouseEvent('mousedown', { bubbles: true, cancelable: true, button: 0 })
    play.dispatchEvent(down)
    expect(h.editor.state.selection).not.toBeInstanceOf(NodeSelection)
  })

  it('a horizontal rule is pressable like any other block', async () => {
    h.load(doc([p('x'), { type: 'horizontalRule', attrs: { variant: 'dashed' } }, p('y')]))
    await flush()
    const hr = h.editor.view.dom.querySelector('[data-type="horizontalRule"] hr')!
    hr.dispatchEvent(new MouseEvent('mousedown', { bubbles: true, cancelable: true, button: 0 }))
    expect((h.editor.state.selection as NodeSelection).node?.type.name).toBe('horizontalRule')
  })
})
