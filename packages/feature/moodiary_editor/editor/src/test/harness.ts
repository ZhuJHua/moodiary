import { Editor } from '@tiptap/core'
import type { JSONContent } from '@tiptap/core'
import { expect, vi } from 'vitest'
import { linkSuggestion } from '../editor/diary-link'
import { createEditorKit } from '../editor/tiptap'
import type { EditorApi } from '../editor/tiptap'

export interface Posted {
  type: string
  payload?: { reqId: string; query: string }
}

export interface EditorHarness {
  editor: Editor
  api: EditorApi
  posted: Posted[]
  lastPost(type: string): Posted | undefined
  /** 插入文本并冲刷微任务（suggestion 插件的 onStart/onUpdate 是异步回调）。 */
  type(text: string): Promise<void>
  /** 走完 250ms 防抖，以 [items] 应答最近一次 requestLinkCandidates。 */
  respond(items: Array<{ id: string; label: string }>): Promise<void>
  press(key: string): Promise<void>
  findNode(type: string): JSONContent | undefined
  destroy(): void
}

export function setupEditor(): EditorHarness {
  const posted: Posted[] = []
  window.MoodiaryEditor = {
    postMessage: (raw: string) => {
      posted.push(JSON.parse(raw) as Posted)
    },
  }
  Object.assign(linkSuggestion, {
    open: false,
    loading: false,
    query: '',
    items: [],
    index: 0,
    rect: null,
  })

  const kit = createEditorKit({ editable: true, placeholder: '', onChange: () => {} })
  const host = document.createElement('div')
  document.body.appendChild(host)
  const editor = new Editor({ ...kit.options, element: host })
  kit.attach(editor)

  const lastPost = (type: string): Posted | undefined =>
    [...posted].reverse().find((m) => m.type === type)

  return {
    editor,
    api: kit.api,
    posted,
    lastPost,
    type: async (text) => {
      editor.commands.insertContent(text)
      await vi.advanceTimersByTimeAsync(0)
    },
    respond: async (items) => {
      await vi.advanceTimersByTimeAsync(250)
      const req = lastPost('requestLinkCandidates')
      expect(req).toBeDefined()
      kit.api.resolveLinkCandidates(req!.payload!.reqId, JSON.stringify(items))
      await vi.advanceTimersByTimeAsync(0)
    },
    press: async (key) => {
      editor.view.dom.dispatchEvent(
        new KeyboardEvent('keydown', { key, bubbles: true, cancelable: true }),
      )
      await vi.advanceTimersByTimeAsync(0)
    },
    findNode: (type) => {
      const walk = (n: JSONContent): JSONContent | undefined => {
        if (n.type === type) return n
        for (const c of n.content ?? []) {
          const hit = walk(c)
          if (hit) return hit
        }
        return undefined
      }
      return walk(editor.getJSON() as JSONContent)
    },
    destroy: () => {
      editor.destroy()
      document.body.innerHTML = ''
      delete window.MoodiaryEditor
    },
  }
}
