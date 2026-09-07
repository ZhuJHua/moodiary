import { Editor } from '@tiptap/vue-3'
import type { JSONContent } from '@tiptap/core'
import { createApp, defineComponent, getCurrentInstance } from 'vue'
import type { App, AppContext, ComponentInternalInstance } from 'vue'
import { expect, vi } from 'vitest'
import { linkSuggestion } from '../editor/diary-link'
import { createEditorKit } from '../editor/tiptap'
import type { EditorApi } from '../editor/tiptap'

function attachVueRuntime(editor: Editor): App {
  let instance: ComponentInternalInstance | null = null
  const app = createApp(
    defineComponent({
      setup: () => {
        instance = getCurrentInstance()
        return () => null
      },
    }),
  )
  const mountPoint = document.createElement('div')
  document.body.appendChild(mountPoint)
  app.mount(mountPoint)
  if (instance) {
    const found = instance as ComponentInternalInstance
    editor.contentComponent = found as NonNullable<Editor['contentComponent']>
    editor.appContext = {
      ...found.appContext,
      provides: (found as unknown as { provides: AppContext['provides'] }).provides,
    }
  }
  editor.createNodeViews()
  if (!editor.contentComponent) {
    throw new Error('harness: contentComponent 未注入，node view 会静默回退成裸 renderHTML')
  }
  return app
}

export interface Posted {
  type: string
  payload?: { reqId: string; query: string }
}

export interface EditorHarness {
  editor: Editor
  api: EditorApi
  posted: Posted[]
  lastPost(type: string): Posted | undefined
  type(text: string): Promise<void>
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
  const app = attachVueRuntime(editor)

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
      app.unmount()
      document.body.innerHTML = ''
      delete window.MoodiaryEditor
    },
  }
}
