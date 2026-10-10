import { createElement } from 'react'
import { act } from 'react'
import { createRoot, type Root } from 'react-dom/client'
import { Editor, EditorContent } from '@tiptap/react'
import type { JSONContent } from '@tiptap/core'
import { expect, vi } from 'vitest'
import { linkSuggestion } from '@/core/editor/diary-link'
import { editable } from '@/core/state/editable'
import { createEditorKit } from '@/core/editor/tiptap'
import type { EditorApi } from '@/core/editor/tiptap'
import { nodeViews } from '@/ui/nodes'

export interface Posted {
  type: string
  payload?: { reqId: string; query: string }
}

export interface EditorHarness {
  editor: Editor
  api: EditorApi
  posted: Posted[]
  setEditable(value: boolean): void
  lastPost(type: string): Posted | undefined
  type(text: string): Promise<void>
  respond(items: Array<{ id: string; label: string }>): Promise<void>
  press(key: string): Promise<void>
  findNode(type: string): JSONContent | undefined
  flush(): Promise<void>
  destroy(): void
}

// React 节点视图经 EditorContent 的 portal 渲染，harness 必须挂一个真实的 EditorContent
function mountContent(editor: Editor): Root {
  const host = document.createElement('div')
  document.body.appendChild(host)
  const root = createRoot(host)
  act(() => root.render(createElement(EditorContent, { editor })))
  if (!(editor as { contentComponent?: unknown }).contentComponent) {
    throw new Error('harness: contentComponent 未注入，node view 会静默回退成裸 renderHTML')
  }
  return root
}

export function setupEditor(): EditorHarness {
  const posted: Posted[] = []
  window.MoodiaryEditor = {
    postMessage: (raw: string) => {
      posted.push(JSON.parse(raw) as Posted)
    },
  }
  linkSuggestion.set({ open: false, loading: false, query: '', items: [], index: 0, rect: null })

  const kit = createEditorKit({ editable: true, placeholder: '', nodeViews, onChange: () => {} })
  const editor = new Editor({ ...kit.options })
  kit.attach(editor)
  const root = mountContent(editor)

  const lastPost = (type: string): Posted | undefined =>
    [...posted].reverse().find((m) => m.type === type)
  const flush = async (): Promise<void> => {
    await act(async () => {
      await vi.advanceTimersByTimeAsync(0)
    })
  }

  return {
    editor,
    api: kit.api,
    posted,
    // 与 bridge 的 setEditable 同步：store 归 bridge 写，内核只改 editor
    setEditable: (value) => {
      editable.set(value)
      kit.api.setEditable(value)
    },
    lastPost,
    flush,
    type: async (text) => {
      editor.commands.insertContent(text)
      await flush()
    },
    respond: async (items) => {
      await act(async () => {
        await vi.advanceTimersByTimeAsync(250)
      })
      const req = lastPost('requestLinkCandidates')
      expect(req).toBeDefined()
      kit.api.resolveLinkCandidates(req!.payload!.reqId, JSON.stringify(items))
      await flush()
    },
    press: async (key) => {
      editor.view.dom.dispatchEvent(
        new KeyboardEvent('keydown', { key, bubbles: true, cancelable: true }),
      )
      await flush()
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
      act(() => root.unmount())
      editor.destroy()
      document.body.innerHTML = ''
      delete window.MoodiaryEditor
    },
  }
}
