import type { Editor, EditorOptions, JSONContent } from '@tiptap/core'
import { history } from '@tiptap/pm/history'
import { NodeSelection } from '@tiptap/pm/state'
import StarterKit from '@tiptap/starter-kit'
import { Placeholder, CharacterCount } from '@tiptap/extensions'
import { Markdown } from 'tiptap-markdown'
import CodeBlockLowlight from '@tiptap/extension-code-block-lowlight'
import { TableKit } from '@tiptap/extension-table'
import { TaskList } from '@tiptap/extension-task-list'
import { TaskItem } from '@tiptap/extension-task-item'
import { VueNodeViewRenderer } from '@tiptap/vue-3'
import { common, createLowlight } from 'lowlight'
import CodeBlockNodeView from '../components/nodes/CodeBlockNodeView.vue'
import { DiaryLink, resolveLinkCandidates as applyLinkCandidates } from './diary-link'
import { SearchExtension } from './search'

import { post } from '../bridge/post'
import { setEditableState } from './editable'
import { MediaImage } from './image-node'
import { stripMediaPrefix } from './media'
import { Audio, Video } from './media-nodes'

const lowlight = createLowlight(common)

// HISTORY_OPTIONS 须与 StarterKit 内置 UndoRedo 的默认值一致，参数不同等于改了撤销行为
const HISTORY_OPTIONS = { depth: 100, newGroupDelay: 500 }

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
}

export interface EditorKitOptions {
  editable: boolean
  placeholder: string
  onChange: (content: string) => void
  onEditableChange?: (value: boolean) => void
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
    return obj && typeof obj === 'object' && obj.type === 'doc' ? (obj as JSONContent) : null
  } catch {
    return null
  }
}

export function createEditorKit(opts: EditorKitOptions): EditorKit {
  const { editable, placeholder, onChange, onEditableChange } = opts

  let editor: Editor | null = null
  let suppress = false
  const pendingUploads = new Map<string, (name: string) => void>()
  let uploadSeq = 0

  // NodeSelection 上直接 insertContent 会替换该节点，需改用 insertContentAt(selection.to)
  const insertBlock = (content: JSONContent): void => {
    const ed = editor
    if (!ed) return
    const { selection } = ed.state
    const chain = ed.chain().focus()
    if (selection instanceof NodeSelection) {
      chain.insertContentAt(selection.to, content)
    } else {
      chain.insertContent(content)
    }
    chain.run()
  }

  const insertImage = (name: string, alt?: string): void => {
    insertBlock({ type: 'image', attrs: { src: name, alt } })
  }

  const handleFiles = (files: FileList | null | undefined): boolean => {
    const images = files ? Array.from(files).filter((f) => f.type.startsWith('image/')) : []
    if (images.length === 0) return false
    for (const file of images) {
      const reader = new FileReader()
      reader.onload = () => {
        const dataUri = String(reader.result)
        const id = `up-${++uploadSeq}`
        pendingUploads.set(id, (name) => {
          if (name) insertImage(name)
        })
        post('saveImage', { id, dataUri, name: file.name })
      }
      reader.readAsDataURL(file)
    }
    return true
  }

  const withoutEmit = (fn: () => void): void => {
    suppress = true
    fn()
    suppress = false
  }

  const loadContent = (content: string): void => {
    const ed = editor
    if (!ed) return
    const doc = parseDoc(content)
    withoutEmit(() => {
      if (doc) {
        ed.commands.setContent(doc, { emitUpdate: false })
      } else {
        ed.commands.setContent(stripMediaPrefix(content), { emitUpdate: false })
      }
      // 不可用 view.updateState()：会绕过 dispatchTransaction 导致 history 复活，撤销后内容变空
      ed.unregisterPlugin('history')
      ed.registerPlugin(history(HISTORY_OPTIONS))
    })
  }

  const options: Partial<EditorOptions> = {
    editable,
    content: '',
    extensions: [
      // 两者节点同名，须关掉 StarterKit 自带 codeBlock 才能换成 CodeBlockLowlight
      StarterKit.configure({ codeBlock: false }),
      CodeBlockLowlight.configure({ lowlight }).extend({
        addNodeView() {
          return VueNodeViewRenderer(CodeBlockNodeView)
        },
      }),
      MediaImage,
      Audio,
      Video,
      TableKit.configure({ table: { resizable: true } }),
      TaskList,
      TaskItem.configure({ nested: true }),
      DiaryLink,
      CharacterCount,
      SearchExtension,
      Placeholder.configure({ placeholder }),
      Markdown.configure({ html: false, linkify: false, breaks: false, transformPastedText: true }),
    ],
    editorProps: {
      handlePaste: (_view, event) => handleFiles(event.clipboardData?.files),
      handleDrop: (_view, event) => handleFiles(event.dataTransfer?.files),
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
      editor?.setEditable(value, false)
      // setEditable(value, false) 不触发 onUpdate，需显式回调驱动 UI
      setEditableState(value)
      onEditableChange?.(value)
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
      const els = Array.from(
        ed.view.dom.querySelectorAll<HTMLVideoElement>('video.moodiary-video__el'),
      )
      const el = els.find((v) => v.src.endsWith(name))
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
  }

  return {
    options,
    api,
    attach: (e) => {
      editor = e
      // 初始值须显式推入，否则只读态会被当成可编辑（共享模块级状态）
      setEditableState(editable)
    },
  }
}
