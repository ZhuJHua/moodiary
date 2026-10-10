import { describe, expect, it } from 'vitest'
import { Editor } from '@tiptap/core'
import { createEditorKit } from './tiptap'
import { countGraphemes, plainTextOf, wordCountOf } from './word-count'

function docOf(content: object[]): Editor {
  const kit = createEditorKit({ editable: true, placeholder: '', onChange: () => {} })
  const editor = new Editor({ ...kit.options, element: document.createElement('div') })
  editor.commands.setContent({ type: 'doc', content }, { emitUpdate: false })
  return editor
}

const p = (text: string) => ({ type: 'paragraph', content: [{ type: 'text', text }] })

describe('word count', () => {
  it('counts graphemes, not code units or code points', () => {
    expect(countGraphemes('你好')).toBe(2)
    expect(countGraphemes('😀')).toBe(1)
    expect(countGraphemes('👨‍👩‍👧')).toBe(1)
    expect(countGraphemes('🇨🇳')).toBe(1)
  })

  it('joins blocks the way the Dart side does', () => {
    const editor = docOf([p('ab'), p('cd')])
    expect(plainTextOf(editor.state.doc)).toBe('ab\ncd')
    expect(wordCountOf(editor.state.doc)).toBe(5)
    editor.destroy()
  })

  it('collapses blank runs and trims, counting diary link labels', () => {
    const editor = docOf([
      p('a'),
      { type: 'paragraph' },
      { type: 'paragraph' },
      { type: 'paragraph', content: [{ type: 'diaryLink', attrs: { id: 'x', label: '链接' } }] },
    ])
    expect(plainTextOf(editor.state.doc)).toBe('a\n\n链接')
    editor.destroy()
  })
})
