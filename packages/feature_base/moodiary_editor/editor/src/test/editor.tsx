import { act, cleanup, render } from '@testing-library/react'
import type { JSONContent } from '@tiptap/core'
import { Editor, EditorContent } from '@tiptap/react'
import { vi } from 'vitest'
import { cancelChange } from '@/core/bridge/change'
import { respond } from '@/core/bridge/request'
import { createEditorKit, type EditorApi } from '@/core/editor/kit'
import { linkSuggestionStore } from '@/core/editor/nodes/diary-link'
import { nodeViews } from '@/ui/nodes'

export interface Posted {
  type: string
  payload?: unknown
}

const testMediaUrl = (name: string, poster = false): string =>
  poster ? `file:///media/poster/${name}` : `file:///media/${name}`

function captureBridge(): Posted[] {
  const posted: Posted[] = []
  window.MoodiaryEditor = {
    postMessage: (raw: string) => {
      const message = JSON.parse(raw) as Posted
      posted.push(message)
      const p = message.payload as
        | { reqId?: string; items?: { name: string; poster?: boolean }[] }
        | undefined
      if (message.type === 'resolveMedia' && p?.reqId) {
        const urls = Object.fromEntries(
          (p.items ?? []).map((i) => [i.poster ? `${i.name}#poster` : i.name, testMediaUrl(i.name, i.poster)]),
        )
        respond(p.reqId, JSON.stringify(urls))
      }
    },
  }
  return posted
}

const lastPost = (posted: Posted[], type: string): Posted | undefined =>
  [...posted].reverse().find((m) => m.type === type)

export const flush = (): Promise<void> =>
  act(async () => {
    if (vi.isFakeTimers()) await vi.advanceTimersByTimeAsync(20)
    else await new Promise((r) => setTimeout(r, 20))
  })

export interface EditorFixture {
  editor: Editor
  api: EditorApi
  posted: Posted[]
  panel: { on: boolean }
  lastPost(type: string): Posted | undefined
  load(doc: JSONContent | string): void
  type(text: string): boolean
  press(key: string): Promise<void>
  nodes(type: string): JSONContent[]
  topTypes(): string[]
  destroy(): void
}

export const doc = (content: JSONContent[]): JSONContent => ({ type: 'doc', content })

export const p = (text?: string): JSONContent =>
  text ? { type: 'paragraph', content: [{ type: 'text', text }] } : { type: 'paragraph' }

// 不挂 EditorContent，React 节点视图会静默退成裸 HTML
export function renderEditor(opts: { editable?: boolean } = {}): EditorFixture {
  const posted = captureBridge()
  const panel = { on: false }
  const kit = createEditorKit({
    editable: opts.editable ?? true,
    placeholder: '',
    nodeViews,
    isPanelMode: () => panel.on,
  })
  const editor = new Editor(kit.options)
  kit.attach(editor)
  render(<EditorContent editor={editor} />)

  return {
    editor,
    api: kit.api,
    posted,
    panel,
    lastPost: (type) => lastPost(posted, type),
    load: (value) => kit.api.setContent(typeof value === 'string' ? value : JSON.stringify(value)),
    // 走 handleTextInput，输入规则才会触发
    type: (text) => {
      const { view } = editor
      const { from, to } = view.state.selection
      const handled = view.someProp('handleTextInput', (f) => f(view, from, to, text, () => view.state.tr.insertText(text, from, to)))
      if (!handled) view.dispatch(view.state.tr.insertText(text, from, to))
      return !!handled
    },
    press: async (key) => {
      editor.view.dom.dispatchEvent(new KeyboardEvent('keydown', { key, bubbles: true, cancelable: true }))
      await flush()
    },
    nodes: (type) => {
      const found: JSONContent[] = []
      const walk = (n: JSONContent): void => {
        if (n.type === type) found.push(n)
        n.content?.forEach(walk)
      }
      walk(editor.getJSON())
      return found
    },
    topTypes: () => (editor.getJSON().content ?? []).map((n) => n.type ?? ''),
    destroy: () => {
      cancelChange()
      cleanup()
      editor.destroy()
      linkSuggestionStore.setState({ open: false, loading: false, query: '', items: [], index: 0, reference: null }, true)
      delete window.MoodiaryEditor
    },
  }
}
