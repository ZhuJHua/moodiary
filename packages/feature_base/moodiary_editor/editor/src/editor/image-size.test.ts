import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { nextTick } from 'vue'
import { setupEditor } from '../test/harness'
import type { EditorHarness } from '../test/harness'
import { clampWidthPercent, IMAGE_SIZE_STOPS, snapWidthPercent } from './image-node'
import { setMediaPrefix } from './media'

const PREFIX = 'http://127.0.0.1:5321/tok/media/'

let h: EditorHarness

beforeEach(() => {
  vi.useFakeTimers()
  setMediaPrefix(PREFIX)
  h = setupEditor()
})

afterEach(() => {
  h.destroy()
  vi.useRealTimers()
})

const imageNode = (): { attrs?: Record<string, unknown> } | undefined => h.findNode('image')
const imageNodes = (): Array<Record<string, unknown>> => {
  const out: Array<Record<string, unknown>> = []
  h.editor.state.doc.descendants((n) => {
    if (n.type.name === 'image') out.push(n.attrs)
    return true
  })
  return out
}
const wrapper = (): HTMLElement | null => h.editor.view.dom.querySelector('.moodiary-image')
const badge = (): HTMLElement | null => h.editor.view.dom.querySelector('.moodiary-image__badge')
const menuHost = (): HTMLElement | null => h.editor.view.dom.querySelector('.moodiary-image__menu')
// 面板 Teleport 到 body，不在编辑器 DOM 里。
const panel = (): HTMLElement | null => document.body.querySelector('.moodiary-image__panel')
const slider = (): HTMLInputElement | null =>
  document.body.querySelector('.moodiary-image__panel input[type="range"]')

/** 已开则原样（点角标是 toggle，重复点会关掉）。 */
const openPanel = async (): Promise<void> => {
  if (!panel()) {
    badge()?.click()
    await nextTick()
  }
}

const emitRange = (value: string, type: 'input' | 'change'): void => {
  const range = slider()
  expect(range).not.toBeNull()
  range!.value = value
  range!.dispatchEvent(new Event(type, { bubbles: true }))
}
/** 拖动中（连续触发）。 */
const drag = (value: string): void => emitRange(value, 'input')
/** 松手。 */
const release = (value: string): void => emitRange(value, 'change')

describe('image node view', () => {
  it('mounts the Vue node view instead of falling back to bare renderHTML', () => {
    h.api.insertMedia('image-1.jpg')
    // 回退形态是一个光秃秃的 <img>，没有外层包裹；有 .moodiary-image 才说明 node view 真挂上了。
    expect(wrapper()).not.toBeNull()
  })

  it('keeps a real <img> in the document so the fullscreen gallery still matches it', () => {
    h.api.insertMedia('image-1.jpg')
    const img = h.editor.view.dom.querySelector('.ProseMirror img, img')
    expect(img).not.toBeNull()
    expect(img?.getAttribute('src')).toBe(`${PREFIX}image-1.jpg`)
  })

  it('leaves external http(s) sources untouched', async () => {
    h.editor.commands.setContent(
      { type: 'doc', content: [{ type: 'image', attrs: { src: 'https://example.com/a.png' } }] },
      { emitUpdate: false },
    )
    await nextTick()
    expect(h.editor.view.dom.querySelector('img')?.getAttribute('src')).toBe(
      'https://example.com/a.png',
    )
  })
})

describe('widthPercent attribute', () => {
  it('defaults to null on insert and stores the bare filename', () => {
    h.api.insertMedia('image-1.jpg')
    expect(imageNode()?.attrs).toMatchObject({ src: 'image-1.jpg', widthPercent: null })
  })

  it('round-trips through getContent/setContent', () => {
    h.api.insertMedia('image-1.jpg')
    h.editor.commands.updateAttributes('image', { widthPercent: 50 })
    const saved = h.api.getContent()
    expect(saved).toContain('"widthPercent":50')

    h.api.setContent(saved)
    expect(imageNode()?.attrs).toMatchObject({ src: 'image-1.jpg', widthPercent: 50 })
  })

  it('reads old documents that predate the attribute as auto', () => {
    h.api.setContent(
      JSON.stringify({
        type: 'doc',
        content: [{ type: 'image', attrs: { src: 'image-old.jpg' } }],
      }),
    )
    expect(imageNode()?.attrs).toMatchObject({ src: 'image-old.jpg', widthPercent: null })
  })

  it('drives the wrapper max-width, and auto leaves it unset', async () => {
    h.api.insertMedia('image-1.jpg')
    await nextTick()
    expect(wrapper()?.style.maxWidth).toBe('')

    h.editor.commands.updateAttributes('image', { widthPercent: 33 })
    await nextTick()
    expect(wrapper()?.style.maxWidth).toBe('33%')

    h.editor.commands.updateAttributes('image', { widthPercent: null })
    await nextTick()
    expect(wrapper()?.style.maxWidth).toBe('')
  })

  it('clamps values coming from pasted HTML', () => {
    expect(clampWidthPercent(0)).toBe(25)
    expect(clampWidthPercent(999)).toBe(100)
    expect(clampWidthPercent(33.4)).toBe(33)
  })

  it('snaps near a stop but leaves free positions alone', () => {
    expect(snapWidthPercent(52)).toBe(50)
    expect(snapWidthPercent(48)).toBe(50)
    expect(snapWidthPercent(62)).toBe(62)
    expect(snapWidthPercent(98)).toBe(100)
  })
})

describe('size badge', () => {
  beforeEach(async () => {
    h.api.insertMedia('image-1.jpg')
    await nextTick()
  })

  it('renders only while editable', async () => {
    expect(badge()).not.toBeNull()

    h.api.setEditable(false)
    await nextTick()
    expect(badge()).toBeNull()

    h.api.setEditable(true)
    await nextTick()
    expect(badge()).not.toBeNull()
  })

  it('anchors the panel on the badge itself, not on a stand-in element', () => {
    // PopupMenu 按 trigger 插槽的包裹元素定位。角标必须真的在那个包裹里，否则面板会弹到
    // 图片下方的满宽处（这是「拇指手柄」方案评审里挑出的必现 bug）。
    const host = menuHost()
    expect(host).not.toBeNull()
    expect(host?.contains(badge())).toBe(true)
  })

  it('offers a continuous slider with the stops as tick labels', async () => {
    await openPanel()

    const range = slider()
    expect(range).not.toBeNull()
    expect(range?.min).toBe('25')
    expect(range?.max).toBe('100')
    expect(range?.step).toBe('1')

    const stops = Array.from(document.body.querySelectorAll<HTMLElement>('.moodiary-image__stop'))
    expect(stops.map((el) => Number(el.textContent?.trim()))).toEqual([...IMAGE_SIZE_STOPS])
  })

  it('previews while dragging and only writes the attribute on release', async () => {
    await openPanel()

    drag('62')
    await nextTick()
    // 拖动中：画面已经跟手，但还没落库 —— 否则一次拖拽会往 undo 栈塞几十步。
    expect(wrapper()?.style.maxWidth).toBe('62%')
    expect(imageNode()?.attrs).toMatchObject({ widthPercent: null })

    release('62')
    await nextTick()
    expect(imageNode()?.attrs).toMatchObject({ widthPercent: 62 })
  })

  it('snaps onto a stop when released near one', async () => {
    await openPanel()
    release('52')
    await nextTick()
    expect(imageNode()?.attrs).toMatchObject({ widthPercent: 50 })
  })

  it('commits a pending preview when the panel closes without a change event', async () => {
    await openPanel()
    drag('40')
    await nextTick()

    menuHost()?.querySelector<HTMLElement>('.moodiary-image__badge')?.click()
    await nextTick()
    expect(imageNode()?.attrs).toMatchObject({ widthPercent: 40 })
  })

  it('jumps to a stop when its tick label is tapped', async () => {
    await openPanel()
    document.body.querySelectorAll<HTMLElement>('.moodiary-image__stop')[2].click() // 75
    await nextTick()
    expect(imageNode()?.attrs).toMatchObject({ widthPercent: 75 })
  })

  it('restores the default', async () => {
    await openPanel()
    release('62')
    await nextTick()

    await openPanel()
    const reset = Array.from(document.body.querySelectorAll<HTMLButtonElement>('button')).find(
      (el) => el.textContent?.trim() === '恢复默认',
    )
    expect(reset?.disabled).toBe(false)
    reset?.click()
    await nextTick()
    expect(imageNode()?.attrs).toMatchObject({ widthPercent: null })
    expect(wrapper()?.style.maxWidth).toBe('')
  })
})

describe('targets the right node', () => {
  it("changes its own image, not whichever one happens to be selected", async () => {
    h.api.insertMedia('image-1.jpg')
    h.api.insertMedia('image-2.jpg')
    await nextTick()

    // 选中第一张，却去点第二张的角标 —— 若实现里写成 commands.updateAttributes('image', …)
    // （按当前选区改），改中的会是第一张。
    h.editor.commands.setNodeSelection(0)
    const badges = h.editor.view.dom.querySelectorAll<HTMLElement>('.moodiary-image__badge')
    expect(badges.length).toBe(2)
    badges[1].click()
    await nextTick()

    document.body.querySelectorAll<HTMLElement>('.moodiary-image__stop')[1].click() // 50
    await nextTick()

    expect(imageNodes().map((a) => a.widthPercent)).toEqual([null, 50])
  })
})

describe('read-only mode', () => {
  it('keeps the size and the <img> after the badge is gone', async () => {
    h.api.insertMedia('image-1.jpg')
    h.editor.commands.updateAttributes('image', { widthPercent: 50 })
    await nextTick()

    h.api.setEditable(false)
    await nextTick()

    expect(badge()).toBeNull()
    // 只断言角标消失是不够的：node view 整个没挂、回退成裸 renderHTML 时它同样为 null。
    expect(wrapper()?.style.maxWidth).toBe('50%')
    expect(h.editor.view.dom.querySelector('img')?.getAttribute('src')).toBe(
      `${PREFIX}image-1.jpg`,
    )
  })
})

describe('HTML parsing (clipboard)', () => {
  const paste = (html: string): void => {
    h.editor.view.pasteHTML(html, new Event('paste') as unknown as ClipboardEvent)
  }

  it('strips the media prefix again so the stored src stays a bare filename', () => {
    h.api.insertMedia('image-1.jpg')
    // 复制走 renderHTML（拼了前缀），粘贴走 parseHTML —— 前缀必须能剥回来，否则带随机端口的
    // 绝对 URL 会落库，冷启动后永久裂图，且 Dart 侧的孤儿清理会误删真实文件。
    paste(h.editor.getHTML())
    expect(imageNodes().every((a) => String(a.src).startsWith('image-'))).toBe(true)
  })

  it('clamps a hostile data-width-percent instead of trusting it', () => {
    paste('<img src="image-2.jpg" data-width-percent="999">')
    const pasted = imageNodes().find((a) => a.src === 'image-2.jpg')
    expect(pasted?.widthPercent).toBe(100)
  })

  it('treats a non-numeric data-width-percent as auto', () => {
    paste('<img src="image-3.jpg" data-width-percent="abc">')
    const pasted = imageNodes().find((a) => a.src === 'image-3.jpg')
    expect(pasted?.widthPercent).toBeNull()
  })

  it('drops width/height so they cannot fight widthPercent', () => {
    paste('<img src="image-4.jpg" width="300" height="200">')
    const pasted = imageNodes().find((a) => a.src === 'image-4.jpg')
    expect(pasted?.width).toBeNull()
    expect(pasted?.height).toBeNull()
    expect(h.editor.getHTML()).not.toContain('width="300"')
  })
})
