import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import type { JSONContent } from '@tiptap/core'
import { doc, flush, p, renderEditor, type EditorFixture } from '@/test/editor'
import { relaxedDelimiter } from './input-rules'
import { looksLikeMarkdown } from './markdown'

let h: EditorFixture

beforeEach(() => {
  h = renderEditor()
})

afterEach(() => {
  h.destroy()
})

const parse = (md: string): JSONContent[] =>
  h.editor.schema.nodeFromJSON(h.editor.markdown!.parse(md)).toJSON().content ?? []
const serialize = (content: JSONContent[]): string => h.editor.markdown!.serialize(doc(content))
const roundTrip = (content: JSONContent[]): JSONContent[] => parse(serialize(content))

describe('custom nodes round-trip through the markdown dialect', () => {
  it('image name is the label', () => {
    const image = { type: 'image', attrs: { src: 'image-1.png', name: '海 [边] a\\b', widthPercent: null } }
    expect(serialize([image])).toBe('![海 \\[边\\] a\\\\b](image-1.png)')
    expect(roundTrip([image])[0]).toEqual(image)
    expect(parse('![海](image-1.png "日落")\n\n![](image-2.png "日落")\n\n![](image-3.png)').map((n) => n.attrs!.name)).toEqual([
      '海',
      '日落',
      null,
    ])
  })

  it('video and audio are images routed by the media name prefix', () => {
    const md = serialize([
      { type: 'video', attrs: { src: 'video-1.mp4', name: '旅行', widthPercent: 50 } },
      { type: 'audio', attrs: { src: 'audio-1.m4a', name: null } },
    ])
    expect(md).toBe('![旅行](video-1.mp4)\n\n![](audio-1.m4a)')
    expect(parse(md)).toEqual([
      { type: 'video', attrs: { src: 'video-1.mp4', name: '旅行', widthPercent: null } },
      { type: 'audio', attrs: { src: 'audio-1.m4a', name: null } },
    ])
  })

  it('attachment is a link to a file- name on its own line', () => {
    const attachment = { type: 'attachment', attrs: { src: 'file-1.pdf', name: '报告 [终版].pdf', mime: null, size: null } }
    const md = serialize([p('前'), attachment, p('后')])
    expect(md).toBe('前\n\n[报告 \\[终版\\].pdf](file-1.pdf)\n\n后')
    expect(parse(md)).toEqual([p('前'), attachment, p('后')])
    expect(parse(serialize([{ ...attachment, attrs: { ...attachment.attrs, name: null } }]))[0].attrs!.name).toBeNull()
    expect(parse('看 [文件](file-2.pdf) 这里')[0].content![1].marks![0]).toEqual({
      type: 'link',
      attrs: { href: 'file-2.pdf' },
    })
  })

  it('diary link uses [[label]](moodiary://diary/<id>)', () => {
    const link = { type: 'diaryLink', attrs: { id: 'd1', label: '[游记] 杭州\\西湖' } }
    const md = serialize([{ type: 'paragraph', content: [{ type: 'text', text: '看 ' }, link] }])
    expect(md).toBe('看 [[\\[游记\\] 杭州\\\\西湖]](moodiary://diary/d1)')
    expect(parse(md)[0].content![1]).toEqual(link)
    expect(parse('[[没id]]')[0].content).toEqual([{ type: 'text', text: '[[没id]]' }])
  })

  it('highlight ==x==, underline <u>x</u>, rule ---', () => {
    const md = serialize([
      {
        type: 'paragraph',
        content: [
          { type: 'text', text: '亮', marks: [{ type: 'highlight', attrs: { color: null } }] },
          { type: 'text', text: '线', marks: [{ type: 'underline' }] },
        ],
      },
      { type: 'horizontalRule', attrs: { variant: 'wavy', label: null } },
    ])
    expect(md).toBe('==亮==<u>线</u>\n\n---')
    const back = parse(md)
    expect(back[0].content).toEqual([
      { type: 'text', text: '亮', marks: [{ type: 'highlight', attrs: { color: null } }] },
      { type: 'text', text: '线', marks: [{ type: 'underline' }] },
    ])
    expect(back[1]).toEqual({ type: 'horizontalRule', attrs: { variant: 'solid', label: null } })
  })

  it('CJK emphasis parses without surrounding spaces', () => {
    expect(parse('今天**很开心**。')[0].content).toEqual([
      { type: 'text', text: '今天' },
      { type: 'text', text: '很开心', marks: [{ type: 'bold' }] },
      { type: 'text', text: '。' },
    ])
  })

  it('every node and mark in the schema declares a markdown renderer', () => {
    const missing = h.editor.extensionManager.extensions
      .filter(
        (e) =>
          (e.type === 'node' || e.type === 'mark') &&
          !['doc', 'text', 'tableRow', 'tableCell', 'tableHeader'].includes(e.name),
      )
      .filter(
        (e) =>
          !(e.config as { renderMarkdown?: unknown }).renderMarkdown &&
          !(e.parent?.config as { renderMarkdown?: unknown } | undefined)?.renderMarkdown,
      )
      .map((e) => e.name)
    expect(missing).toEqual([])
  })
})

describe('markdown paste', () => {
  const paste = async (text: string, types = ['text/plain']): Promise<void> => {
    const event = new Event('paste', { bubbles: true, cancelable: true })
    Object.defineProperty(event, 'clipboardData', {
      value: { files: [], types, getData: (t: string) => (t === 'text/plain' ? text : '') },
    })
    h.editor.view.dom.dispatchEvent(event)
    await flush()
  }

  it('heuristic needs several lines and a block marker', () => {
    expect(looksLikeMarkdown('# 标题\n正文')).toBe(true)
    expect(looksLikeMarkdown('- a\n- b')).toBe(true)
    expect(looksLikeMarkdown('> 引\n用')).toBe(true)
    expect(looksLikeMarkdown('```\ncode\n```')).toBe(true)
    expect(looksLikeMarkdown('| a | b |\n| - | - |')).toBe(true)
    expect(looksLikeMarkdown('# 只有一行')).toBe(false)
    expect(looksLikeMarkdown('第一行\n第二行 2*3*4')).toBe(false)
  })

  it('markdown-looking plain text is parsed in one undoable step', async () => {
    h.load(doc([p('前')]))
    h.editor.commands.setTextSelection(2)
    await paste('# 标题\n\n- [ ] 事\n- [x] 完')
    expect(h.topTypes().slice(0, 3)).toEqual(['paragraph', 'heading', 'taskList'])
    h.editor.commands.undo()
    expect(h.editor.getJSON().content).toEqual([p('前')])
  })

  it('ordinary text and rich clipboard content fall through to the default paste', async () => {
    h.load(doc([p()]))
    h.editor.commands.setTextSelection(1)
    await paste('# not parsed', ['text/plain'])
    expect(h.topTypes()[0]).toBe('paragraph')
    await paste('# a\n- b', ['text/plain', 'text/html'])
    expect(h.nodes('heading')).toHaveLength(0)
  })
})

describe('dialect edge cases shared with Dart', () => {
  it('only tight ==pairs== become highlight', () => {
    const marks = (md: string): string[] =>
      (parse(md)[0]?.content ?? []).filter((n) => n.marks?.some((m) => m.type === 'highlight')).map((n) => n.text ?? '')
    expect(marks('今天==很开心==啊')).toEqual(['很开心'])
    expect(marks('if a==b and c==d')).toEqual([])
    expect(marks('a===b===c')).toEqual([])
    expect(marks('a == b == c')).toEqual([])
  })

  it('an inline file link stays a link', () => {
    expect(parse('x[a](file-y.pdf)').map((n) => n.type)).toEqual(['paragraph'])
    expect(parse('x\n[a](file-y.pdf)\n').map((n) => n.type)).toEqual(['paragraph', 'attachment'])
  })
})

describe('input rules', () => {
  beforeEach(() => {
    h.load(doc([p()]))
    h.editor.commands.setTextSelection(1)
  })

  const typeChars = (text: string): void => {
    for (const ch of Array.from(text)) h.type(ch)
  }
  const first = (): JSONContent => h.editor.getJSON().content![0]
  const backspace = (): void => {
    h.editor.view.dom.dispatchEvent(new KeyboardEvent('keydown', { key: 'Backspace', bubbles: true, cancelable: true }))
  }

  describe('CJK block shortcuts', () => {
    const cases: Array<[string, string, Record<string, unknown>?]> = [
      ['＃ ', 'heading', { level: 1 }],
      ['＃＃　', 'heading', { level: 2 }],
      ['#　', 'heading', { level: 1 }],
      ['》 ', 'blockquote'],
      ['＞ ', 'blockquote'],
      ['－ ', 'bulletList'],
      ['＊ ', 'bulletList'],
      ['· ', 'bulletList'],
      ['• ', 'bulletList'],
      ['1． ', 'orderedList', { start: 1 }],
      ['３． ', 'orderedList', { start: 3 }],
      ['【】 ', 'taskList'],
      ['【 】 ', 'taskList'],
      ['「」 ', 'taskList'],
      ['··· ', 'codeBlock'],
    ]
    for (const [input, type, attrs] of cases) {
      it(`${JSON.stringify(input)} → ${type}`, () => {
        typeChars(input)
        expect(first().type).toBe(type)
        if (attrs) expect(first().attrs).toMatchObject(attrs)
        expect(h.editor.state.doc.textContent).toBe('')
      })
    }

    it('——— and －－－ become a horizontal rule', () => {
      typeChars('———')
      expect(h.topTypes()[0]).toBe('horizontalRule')
      h.load(doc([p()]))
      h.editor.commands.setTextSelection(1)
      typeChars('－－－')
      expect(h.topTypes()[0]).toBe('horizontalRule')
    })

    it('Backspace right after a conversion undoes it', () => {
      typeChars('＃ ')
      expect(first().type).toBe('heading')
      backspace()
      expect(first().type).toBe('paragraph')
      expect(h.editor.state.doc.textContent).toBe('＃ ')
    })
  })

  describe('relaxed inline marks', () => {
    const marked = (): Array<[string, string[]]> =>
      (first().content ?? []).map((n) => [n.text ?? '', (n.marks ?? []).map((m) => m.type)])

    it('bold right after CJK text', () => {
      typeChars('今天**很开心**')
      expect(marked()).toEqual([
        ['今天', []],
        ['很开心', ['bold']],
      ])
    })

    it('italic, strike and highlight without a leading space', () => {
      typeChars('好*斜*')
      expect(marked()).toEqual([
        ['好', []],
        ['斜', ['italic']],
      ])
      h.load(doc([p()]))
      h.editor.commands.setTextSelection(1)
      typeChars('删~~掉~~亮==点==')
      expect(marked()).toEqual([
        ['删', []],
        ['掉', ['strike']],
        ['亮', []],
        ['点', ['highlight']],
      ])
    })

    it('arithmetic is left alone', () => {
      typeChars('2*3*')
      expect(marked()).toEqual([['2*3*', []]])
    })

    it('Backspace right after a mark conversion restores the markup', () => {
      typeChars('今天**很开心**')
      backspace()
      expect(h.editor.getText()).toBe('今天**很开心**')
      expect(marked()).toEqual([['今天**很开心**', []]])
    })

    it('finder rejects padded content and word-adjacent openers', () => {
      const find = relaxedDelimiter('*') as (text: string) => unknown
      expect(find('a* b*')).toBeNull()
      expect(find('x*y*')).toBeNull()
      expect(find('中*y*')).toMatchObject({ text: '*y*', replaceWith: 'y' })
      expect(find('*y*')).toMatchObject({ index: 0 })
    })
  })
})
