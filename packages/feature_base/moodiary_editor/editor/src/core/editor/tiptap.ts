import type { Editor, EditorOptions, JSONContent } from '@tiptap/core'
import { history } from '@tiptap/pm/history'
import { NodeSelection } from '@tiptap/pm/state'
import type { EditorView } from '@tiptap/pm/view'
import StarterKit from '@tiptap/starter-kit'
import { Placeholder, Selection } from '@tiptap/extensions'
import FileHandler from '@tiptap/extension-file-handler'
import CodeBlockLowlight from '@tiptap/extension-code-block-lowlight'
import { TableKit } from '@tiptap/extension-table'
import { TaskList } from '@tiptap/extension-task-list'
import { TaskItem } from '@tiptap/extension-task-item'
import { ReactNodeViewRenderer } from '@tiptap/react'
import { common, createLowlight } from 'lowlight'
import { DiaryLink, resolveLinkCandidates as applyLinkCandidates } from './diary-link'
import { SearchExtension } from './search'

import { post } from '@/core/bridge/post'
import { caretAfter, caretBefore } from './block-caret'
import { blockNodeView } from './block-node-view'
import { hideUndoToast } from '@/core/state/undo-toast'
import { MediaImage } from './image-node'
import { MoodiaryMarkdown } from './markdown'
import { Audio, Video } from './media-nodes'

type NodeViewComponent = Parameters<typeof ReactNodeViewRenderer>[0]

// 节点视图由壳层注入，内核不认识任何 React 组件
export interface EditorNodeViews {
  codeBlock: NodeViewComponent
  image: NodeViewComponent
  audio: NodeViewComponent
  video: NodeViewComponent
}

const lowlight = createLowlight(common)

// HISTORY_OPTIONS 须与 StarterKit 内置 UndoRedo 的默认值一致，参数不同等于改了撤销行为
const HISTORY_OPTIONS = { depth: 100, newGroupDelay: 500 }

const BLOCK = '.moodiary-image, .moodiary-media'
const BLOCK_BODY = '.moodiary-block__body'
const BLOCK_CONTROL =
  'button, input, a, [role="button"], [role="slider"], .moodiary-video__el, .moodiary-video__bar'
const TAP_SLOP = 10
const LONG_PRESS = 500
const FLING_STOP = 100
const SCROLL_MARGIN = 8

export interface EditorApi {
  setContent(content: string): void
  getContent(): string
  setEditable(value: boolean): void
  focus(): void
  blur(): void
  reset(): void
  insertMedia(name: string, alt?: string): void
  insertAudio(name: string): void
  insertVideo(name: string): void
  resolveUpload(id: string, name: string): void
  resolveLinkCandidates(reqId: string, json: string): void
  scrollToHeading(index: number): void
  resumeVideo(name: string, seconds: number): void
  imageSources(): string[]
  previewImage(name: string): void
}

export interface EditorKitOptions {
  editable: boolean
  placeholder: string
  nodeViews: EditorNodeViews
  onChange: (content: string) => void
}

export interface EditorKit {
  options: Partial<EditorOptions>
  api: EditorApi
  attach(editor: Editor): void
}

function parseDoc(content: string): JSONContent | null {
  const trimmed = content.trimStart()
  if (!trimmed.startsWith('{')) return null
  try {
    const obj = JSON.parse(content)
    if (!obj || typeof obj !== 'object' || obj.type !== 'doc') return null
    const doc = obj as JSONContent
    if (!Array.isArray(doc.content) || doc.content.length === 0) {
      doc.content = [{ type: 'paragraph' }]
    }
    return doc
  } catch {
    return null
  }
}

export function wrapPlainText(text: string): JSONContent {
  const content = text.split(/\r?\n/).map((line) => ({
    type: 'paragraph',
    ...(line ? { content: [{ type: 'text', text: line }] } : {}),
  }))
  return { type: 'doc', content: content.length ? content : [{ type: 'paragraph' }] }
}

const isBlankDoc = (doc: JSONContent): boolean => {
  const content = doc.content ?? []
  return content.length === 0 || (content.length === 1 && content[0].type === 'paragraph' && !content[0].content?.length)
}

// prosemirror-view 对高于视口的矩形会把顶边滚到视口外 margin 处，反复调用就来回翻
function scrollNodeSelection(view: EditorView): boolean {
  const { selection } = view.state
  if (!(selection instanceof NodeSelection)) return false
  const dom = view.nodeDOM(selection.from)
  const scroller = view.dom.closest('.moodiary-editor-viewport')
  if (!(dom instanceof HTMLElement) || !(scroller instanceof HTMLElement)) return true
  const rect = dom.getBoundingClientRect()
  const bounds = scroller.getBoundingClientRect()
  if (rect.bottom > bounds.top && rect.top < bounds.bottom) return true
  scroller.scrollTop +=
    rect.top < bounds.top
      ? rect.top - bounds.top - SCROLL_MARGIN
      : Math.min(rect.bottom - bounds.bottom + SCROLL_MARGIN, rect.top - bounds.top - SCROLL_MARGIN)
  return true
}

export function createEditorKit(opts: EditorKitOptions): EditorKit {
  const { editable, placeholder, nodeViews, onChange } = opts

  let editor: Editor | null = null
  let suppress = false
  const pendingUploads = new Map<string, (name: string) => void>()
  let uploadSeq = 0
  let touchOrigin: { x: number; y: number; at: number } | null = null
  let lastScrollAt = -Infinity
  const markScroll = (): void => {
    lastScrollAt = Date.now()
  }

  // 没聚焦时 PM 不滚动选区
  const revealInserted = (ed: Editor): void => {
    const $caret = ed.state.selection.$from
    const block = ed.state.doc.resolve($caret.before()).nodeBefore
    if (!block) return
    const dom = ed.view.nodeDOM($caret.before() - block.nodeSize)
    if (dom instanceof HTMLElement) dom.scrollIntoView?.({ block: 'nearest' })
  }

  const insertBlock = (content: JSONContent): void => {
    const ed = editor
    if (!ed) return
    const { selection } = ed.state
    const chain = ed.chain()
    if (selection instanceof NodeSelection) {
      chain.insertContentAt(selection.to, content)
    } else {
      chain.insertContent(content)
    }
    chain
      .command(({ tr, dispatch }) => {
        if (dispatch && tr.selection instanceof NodeSelection) caretAfter(tr, tr.selection.to)
        return true
      })
      .scrollIntoView()
      .run()
    if (!ed.view.hasFocus()) revealInserted(ed)
  }

  const insertImage = (name: string, alt?: string): void => {
    insertBlock({ type: 'image', attrs: { src: name, alt } })
  }

  const uploadFiles = (files: File[], pos?: number): void => {
    for (const file of files) {
      if (!file.type.startsWith('image/')) continue
      const reader = new FileReader()
      reader.onload = () => {
        const dataUri = String(reader.result)
        const id = `up-${++uploadSeq}`
        pendingUploads.set(id, (name) => {
          if (!name) return
          if (pos != null) editor?.commands.setTextSelection(pos)
          insertImage(name)
        })
        post('saveImage', { id, dataUri, name: file.name })
      }
      reader.readAsDataURL(file)
    }
  }

  const withoutEmit = (fn: () => void): void => {
    suppress = true
    fn()
    suppress = false
  }

  const loadContent = (content: string): void => {
    const ed = editor
    if (!ed) return
    hideUndoToast()
    const doc = parseDoc(content) ?? wrapPlainText(content)
    withoutEmit(() => {
      try {
        ed.commands.setContent(doc, { emitUpdate: false, errorOnInvalidContent: true })
      } catch (e) {
        ed.commands.setContent(doc, { emitUpdate: false })
        post('contentError', {
          message: String((e as { cause?: unknown }).cause ?? e),
          lost: ed.isEmpty && !isBlankDoc(doc),
        })
      }
      // 不可用 view.updateState()：会绕过 dispatchTransaction 导致 history 复活，撤销后内容变空
      ed.unregisterPlugin('history')
      ed.registerPlugin(history(HISTORY_OPTIONS))
    })
  }

  const blockAt = (el: Element): Element | null =>
    el.closest(BLOCK_CONTROL) ? null : el.closest(BLOCK)

  const options: Partial<EditorOptions> = {
    editable,
    content: '',
    extensions: [
      // 两者节点同名，须关掉 StarterKit 自带 codeBlock 才能换成 CodeBlockLowlight
      StarterKit.configure({ codeBlock: false, link: { openOnClick: false } }),
      CodeBlockLowlight.configure({ lowlight }).extend({
        addNodeView: () => ReactNodeViewRenderer(nodeViews.codeBlock),
      }),
      MediaImage.extend({ addNodeView: () => blockNodeView(nodeViews.image) }),
      Audio.extend({ addNodeView: () => blockNodeView(nodeViews.audio) }),
      Video.extend({ addNodeView: () => blockNodeView(nodeViews.video) }),
      TableKit.configure({ table: { resizable: true } }),
      TaskList,
      TaskItem.configure({ nested: true }),
      DiaryLink,
      Selection,
      MoodiaryMarkdown,
      FileHandler.configure({
        onPaste: (_editor, files) => uploadFiles(files),
        onDrop: (_editor, files, pos) => uploadFiles(files, pos),
      }),
      SearchExtension,
      Placeholder.configure({ placeholder }),
    ],
    editorProps: {
      handleScrollToSelection: scrollNodeSelection,
      handlePaste: (_view, event) => {
        const data = event.clipboardData
        const ed = editor
        if (!ed || !data || data.files.length > 0 || data.types.includes('text/html')) return false
        const text = data.getData('text/plain')
        if (!text) return false
        ed.commands.insertContent(text, { contentType: 'markdown' })
        return true
      },
      handleDOMEvents: {
        // touchstart 会被块节点视图的 stopEvent 吞掉，触点只能在 pointerdown 记
        pointerdown: (_view, event) => {
          const target = event.target instanceof Element ? event.target : null
          const block = target ? blockAt(target) : null
          const now = Date.now()
          touchOrigin =
            block && event.pointerType !== 'mouse' && now - lastScrollAt > FLING_STOP
              ? { x: event.clientX, y: event.clientY, at: now }
              : null
          return false
        },
        pointercancel: () => {
          touchOrigin = null
          return false
        },
        // 吃掉合成 mousedown/click：iOS 的合成 click 会重新聚焦并落光标
        touchend: (view, event) => {
          const origin = touchOrigin
          touchOrigin = null
          if (!origin || !view.editable) return false
          if (event.touches.length > 0 || event.changedTouches.length !== 1) return false
          const t = event.changedTouches[0]
          if (Math.hypot(t.clientX - origin.x, t.clientY - origin.y) > TAP_SLOP) return false
          if (Date.now() - origin.at > LONG_PRESS || origin.at < lastScrollAt) return false
          const target = event.target instanceof Element ? event.target : null
          const block = target ? blockAt(target) : null
          if (!block) return false
          const pos = view.posAtDOM(block, 0)
          // ReactNodeViewRenderer 把节点视图包在 div.react-renderer 里，nodeDOM 返回的是外壳
          const host = view.nodeDOM(pos)
          const node = host instanceof Node && host.contains(block) ? view.state.doc.nodeAt(pos) : null
          if (!node?.isAtom) return false
          event.preventDefault()
          const body = block.querySelector(BLOCK_BODY)?.getBoundingClientRect()
          if (body && (t.clientY < body.top || t.clientY > body.bottom)) {
            const tr = view.state.tr
            if (t.clientY < body.top) caretBefore(tr, pos)
            else caretAfter(tr, pos + node.nodeSize)
            view.dispatch(tr.scrollIntoView())
            view.focus()
            return true
          }
          if (node.type.name === 'image') api.previewImage(String(node.attrs.src ?? ''))
          return true
        },
      },
    },
    onUpdate: ({ editor }) => {
      if (!suppress) onChange(JSON.stringify(editor.getJSON()))
    },
    onFocus: () => post('focusChange', 'editor'),
    onBlur: () => post('focusChange', ''),
  }

  const api: EditorApi = {
    setContent: (content) => loadContent(content ?? ''),
    getContent: () => (editor ? JSON.stringify(editor.getJSON()) : ''),
    setEditable: (value) => {
      if (!value) hideUndoToast()
      options.editable = value
      editor?.setEditable(value, false)
    },
    focus: () => {
      editor?.commands.focus()
    },
    blur: () => {
      editor?.commands.blur()
    },
    reset: () => {
      const ed = editor
      if (!ed) return
      hideUndoToast()
      withoutEmit(() => ed.commands.setContent('', { emitUpdate: false }))
    },
    insertMedia: (name, alt) => insertImage(name, alt),
    insertAudio: (name) => insertBlock({ type: 'audio', attrs: { filename: name } }),
    insertVideo: (name) => insertBlock({ type: 'video', attrs: { filename: name } }),
    resolveUpload: (id, name) => {
      const resolver = pendingUploads.get(id)
      if (resolver) {
        pendingUploads.delete(id)
        resolver(name)
      }
    },
    resolveLinkCandidates: (reqId, json) => applyLinkCandidates(reqId, json),
    resumeVideo: (name, seconds) => {
      const ed = editor
      if (!ed || !name) return
      // NodePos.element 对原子块返回父容器
      const hit = ed.$nodes('video')?.find((p) => p.node.attrs.filename === name)
      const host = hit ? (ed.view.nodeDOM(hit.pos) as HTMLElement | null) : null
      const el = host?.querySelector<HTMLVideoElement>('video.moodiary-video__el') ?? null
      if (!el) return
      const apply = (): void => {
        try {
          el.currentTime = seconds
        } catch {
        }
      }
      // readyState 0（HAVE_NOTHING）时设 currentTime 必抛，等 metadata 到了再设。
      if (el.readyState >= 1) apply()
      else el.addEventListener('loadedmetadata', apply, { once: true })
    },
    scrollToHeading: (index) => {
      const ed = editor
      if (!ed) return
      const positions: number[] = []
      ed.state.doc.descendants((node, pos) => {
        if (node.type.name === 'heading') positions.push(pos)
        return true
      })
      const pos = positions[index]
      if (pos == null) return
      const dom = ed.view.nodeDOM(pos) as HTMLElement | null
      dom?.scrollIntoView?.({ behavior: 'smooth', block: 'start' })
    },
    imageSources: () =>
      (editor?.$nodes('image') ?? [])
        .map((p) => String(p.node.attrs.src ?? ''))
        .filter((s) => s && !s.startsWith('data:')),
    previewImage: (name) => {
      if (!name || name.startsWith('data:')) return
      const srcs = api.imageSources()
      const index = srcs.indexOf(name)
      post('imageTap', { src: name, srcs: srcs.length ? srcs : [name], index: index < 0 ? 0 : index })
    },
  }

  return {
    options,
    api,
    attach: (e) => {
      editor = e
      document.addEventListener('scroll', markScroll, { capture: true, passive: true })
      e.on('destroy', () => document.removeEventListener('scroll', markScroll, { capture: true }))
    },
  }
}
