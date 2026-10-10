import { act, cleanup, render } from '@testing-library/react'
import type { JSONContent } from '@tiptap/core'
import { Editor, EditorContent } from '@tiptap/react'
import { vi } from 'vitest'
import { applyEditable } from '@/core/bridge'
import { linkSuggestion } from '@/core/editor/diary-link'
import { createEditorKit, type EditorApi } from '@/core/editor/tiptap'
import { nodeViews } from '@/ui/nodes'

export interface Posted {
  type: string
  payload?: unknown
}

// 顶替 Flutter 注入的 JS channel，收下页面发出的每条消息
export function captureBridge(): Posted[] {
  const posted: Posted[] = []
  window.MoodiaryEditor = {
    postMessage: (raw: string) => {
      posted.push(JSON.parse(raw) as Posted)
    },
  }
  return posted
}

export const lastPost = (posted: Posted[], type: string): Posted | undefined =>
  [...posted].reverse().find((m) => m.type === type)

// 让 React 提交并清掉到期的宏任务；假时钟下用 vi 推进
export const flush = (): Promise<void> =>
  act(async () => {
    if (vi.isFakeTimers()) await vi.advanceTimersByTimeAsync(0)
    else await new Promise((r) => setTimeout(r, 0))
  })

export interface EditorFixture {
  editor: Editor
  api: EditorApi
  posted: Posted[]
  lastPost(type: string): Posted | undefined
  insert(text: string): Promise<void>
  press(key: string): Promise<void>
  setEditable(value: boolean): void
  nodes(type: string): JSONContent[]
  destroy(): void
}

// 真实的 Editor + EditorContent：React 节点视图经 portal 渲染，不挂 EditorContent 会静默退成裸 HTML
export function renderEditor(): EditorFixture {
  const posted = captureBridge()
  const kit = createEditorKit({ editable: true, placeholder: '', nodeViews, onChange: () => {} })
  const editor = new Editor(kit.options)
  kit.attach(editor)
  render(<EditorContent editor={editor} />)

  return {
    editor,
    api: kit.api,
    posted,
    lastPost: (type) => lastPost(posted, type),
    insert: async (text) => {
      editor.commands.insertContent(text)
      await flush()
    },
    press: async (key) => {
      editor.view.dom.dispatchEvent(new KeyboardEvent('keydown', { key, bubbles: true, cancelable: true }))
      await flush()
    },
    setEditable: (value) => applyEditable(kit.api, value),
    nodes: (type) => {
      const found: JSONContent[] = []
      const walk = (n: JSONContent): void => {
        if (n.type === type) found.push(n)
        n.content?.forEach(walk)
      }
      walk(editor.getJSON())
      return found
    },
    destroy: () => {
      cleanup()
      editor.destroy()
      linkSuggestion.set({ open: false, loading: false, query: '', items: [], index: 0, rect: null })
      delete window.MoodiaryEditor
    },
  }
}
