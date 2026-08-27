import { mount } from '@vue/test-utils'
import type { VueWrapper } from '@vue/test-utils'
import { nextTick } from 'vue'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { setupEditor } from '../test/harness'
import type { EditorHarness } from '../test/harness'
import EditorToolbar from './EditorToolbar.vue'

let h: EditorHarness
let toolbar: VueWrapper

beforeEach(() => {
  vi.useFakeTimers()
  h = setupEditor()
  toolbar = mount(EditorToolbar, {
    props: { editor: h.editor, platform: 'mobile' },
    attachTo: document.body,
  })
})

afterEach(() => {
  toolbar.unmount()
  h.destroy()
  vi.useRealTimers()
})

const btn = (id: string) => toolbar.get(`[data-testid="${id}"]`)
const disabled = (id: string): boolean =>
  (btn(id).element as HTMLButtonElement).disabled

describe('undo / redo buttons', () => {
  // 移动端软键盘不提供 Mod-Z，工具栏按钮是撤销重做的唯一入口 —— 这两条测试守的就是它。
  it('starts disabled on a fresh document', () => {
    expect(disabled('undo')).toBe(true)
    expect(disabled('redo')).toBe(true)
  })

  it('undoes and redoes an edit', async () => {
    await h.type('今天天气不错')
    await nextTick()
    expect(disabled('undo')).toBe(false)

    await btn('undo').trigger('click')
    await nextTick()
    expect(h.editor.getText()).not.toContain('今天天气不错')
    expect(disabled('redo')).toBe(false)

    await btn('redo').trigger('click')
    await nextTick()
    expect(h.editor.getText()).toContain('今天天气不错')
  })

  it('goes back to disabled after loading new content', async () => {
    await h.type('旧内容')
    await nextTick()
    expect(disabled('undo')).toBe(false)

    h.api.setContent(
      JSON.stringify({
        type: 'doc',
        content: [{ type: 'paragraph', content: [{ type: 'text', text: '新的一篇' }] }],
      }),
    )
    await nextTick()
    // 灌入即新文档的起点：撤销不能把用户带回上一篇日记。
    expect(disabled('undo')).toBe(true)
  })
})
