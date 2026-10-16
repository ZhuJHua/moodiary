import { Extension, type AnyExtension, type Editor, type EditorOptions, type JSONContent } from '@tiptap/core'
import CodeBlockLowlight from '@tiptap/extension-code-block-lowlight'
import Highlight from '@tiptap/extension-highlight'
import Link from '@tiptap/extension-link'
import { TaskItem, TaskList } from '@tiptap/extension-list'
import { TableKit } from '@tiptap/extension-table'
import Underline from '@tiptap/extension-underline'
import { Placeholder } from '@tiptap/extensions'
import { history } from '@tiptap/pm/history'
import type { Node as PMNode, Schema } from '@tiptap/pm/model'
import { NodeSelection, Selection } from '@tiptap/pm/state'
import type { EditorView } from '@tiptap/pm/view'
import { ReactNodeViewRenderer } from '@tiptap/react'
import StarterKit from '@tiptap/starter-kit'
import { common, createLowlight } from 'lowlight'
import { cancelChange, flushChange, scheduleChange } from '@/core/bridge/change'
import { post } from '@/core/bridge/post'
import { leaveSelectedBlock, selectedBlock } from './block'
import { execCommand, type ExecArgs } from './commands'
import { CjkInputRules } from './input-rules'
import { createMarkdownExtension, looksLikeMarkdown } from './markdown'
import { docVersion, normalizeDoc, SCHEMA_VERSION } from './normalize'
import { AttachmentNode } from './nodes/attachment'
import { DiaryLink, dismissSuggestion } from './nodes/diary-link'
import { HorizontalRuleNode } from './nodes/horizontal-rule'
import { AudioNode, ImageNode, VideoNode } from './nodes/media'
import { clearSearch, SearchExtension } from './search'
import { deriveState, type EditorState } from './state'
import { TrailingParagraph } from './trailing-paragraph'

type NodeViewComponent = Parameters<typeof ReactNodeViewRenderer>[0]

export interface EditorNodeViews {
  codeBlock: NodeViewComponent
  image: NodeViewComponent
  audio: NodeViewComponent
  video: NodeViewComponent
  attachment: NodeViewComponent
}

interface EditorKitOptions {
  editable: boolean
  placeholder: string
  nodeViews: EditorNodeViews
  isPanelMode: () => boolean
  onChangeAllowed?: () => boolean
}

export interface EditorApi {
  setContent(content: string): void
  setEditable(value: boolean): void
  focus(): void
  blur(): void
  holdSelection(): void
  resolveUpload(id: string, name: string): void
  scrollToHeading(index: number): void
  resumeVideo(name: string, seconds: number): void
  exec(command: string, args?: ExecArgs): void
  currentState(): EditorState | null
}

interface EditorKit {
  options: Partial<EditorOptions>
  api: EditorApi
  attach(editor: Editor): void
}

const lowlight = createLowlight(common)

const HISTORY_OPTIONS = { depth: 100, newGroupDelay: 500 }

// 光标离底边至少留 56px：Flutter 工具栏贴在 WebView 底边上方
const CARET_BOTTOM_MARGIN = 56

const SCROLL_MARGIN = 8
const TAP_SLOP = 10
const TAP_MAX_MS = 500

const BLOCK = '[data-block-node]'
const BLOCK_CONTROL = 'button, input, a, [role="button"], [role="slider"], .md-video__bar'
const NOT_TEXT_TAP = `${BLOCK}, input, label, button, [data-type="diaryLink"], [data-type="horizontalRule"]`

const DocVersion = Extension.create({
  name: 'docVersion',
  addGlobalAttributes() {
    return [{ types: ['doc'], attributes: { v: { default: SCHEMA_VERSION, rendered: false } } }]
  },
})

const LinkHrefOnly = Link.extend({
  inclusive: false,
  addAttributes() {
    return { href: { default: null, parseHTML: (el) => el.getAttribute('href') } }
  },
})

const UnderlineHtml = Underline.extend({
  renderMarkdown: (node, h) => `<u>${h.renderChildren(node)}</u>`,
})

const HIGHLIGHT_START = /(?<![=A-Za-z0-9_])==(?=[^=\s])/
const HIGHLIGHT = /^==([^=\s](?:[^=\n]*[^=\s])?)==(?!=)/

const SingleHighlight = Highlight.extend({
  addAttributes() {
    return { color: { default: null, parseHTML: () => null, rendered: false } }
  },

  // 与 Dart MarkdownToTiptap 同一套规则：只认紧贴的 ==x==，a==b、a===b 里的等号原样保留
  markdownTokenizer: {
    name: 'highlight',
    level: 'inline',
    start: (src: string) => src.search(HIGHLIGHT_START),
    tokenize(src, tokens, h) {
      const prev = tokens.at(-1)?.raw?.slice(-1) ?? ''
      if (/[=A-Za-z0-9_]/.test(prev)) return undefined
      const m = HIGHLIGHT.exec(src)
      if (!m) return undefined
      return { type: 'highlight', raw: m[0], text: m[1], tokens: h.inlineTokens(m[1]) }
    },
  },
})

type ParsedContent = { doc: JSONContent } | { error: string }

function parseContent(text: string): ParsedContent {
  if (!text.trim()) return { doc: { type: 'doc', content: [{ type: 'paragraph' }] } }
  if (!text.trimStart().startsWith('{')) return { doc: wrapPlainText(text) }
  let obj: unknown
  try {
    obj = JSON.parse(text)
  } catch (e) {
    return { error: `invalid JSON: ${String(e)}` }
  }
  if (!obj || typeof obj !== 'object' || (obj as JSONContent).type !== 'doc') {
    return { error: 'not a document' }
  }
  const doc = obj as JSONContent
  if (!Array.isArray(doc.content) || doc.content.length === 0) doc.content = [{ type: 'paragraph' }]
  return { doc }
}

function wrapPlainText(text: string): JSONContent {
  const content = text.split(/\r?\n/).map((line) => ({
    type: 'paragraph',
    ...(line ? { content: [{ type: 'text', text: line }] } : {}),
  }))
  return { type: 'doc', content: content.length ? content : [{ type: 'paragraph' }] }
}

function textOf(node: JSONContent): string {
  if (typeof node.text === 'string') return node.text
  return (node.content ?? []).map(textOf).join('')
}

function sanitizeForDisplay(node: JSONContent, schema: Schema, inline = false): JSONContent | null {
  const type = node.type ?? ''
  if (type !== 'text' && !schema.nodes[type]) {
    const text = textOf(node)
    if (!text) return null
    return inline ? { type: 'text', text } : { type: 'paragraph', content: [{ type: 'text', text }] }
  }
  const out: JSONContent = { ...node }
  if (node.marks) out.marks = node.marks.filter((m) => !!schema.marks[m.type ?? ''])
  if (node.content) {
    const childInline = !!schema.nodes[type]?.isTextblock
    out.content = node.content
      .map((child) => sanitizeForDisplay(child, schema, childInline))
      .filter((c): c is JSONContent => c !== null)
  }
  return out
}

function errorMessage(e: unknown): string {
  const cause = (e as { cause?: unknown })?.cause
  return String(cause ?? e)
}

function blockPosFromDOM(view: EditorView, el: Element): number | null {
  const pos = view.posAtDOM(el, 0)
  for (const candidate of [pos, pos - 1]) {
    if (candidate < 0) continue
    const node = view.state.doc.nodeAt(candidate)
    const dom = node ? view.nodeDOM(candidate) : null
    if (node?.isAtom && node.isBlock && dom instanceof Node && (dom === el || dom.contains(el))) {
      return candidate
    }
  }
  return null
}

// 点块只选中、不碰焦点：PM 默认会顺手 focus 编辑器，键盘收着时就被叫出来
function selectBlockOnPress(view: EditorView, event: MouseEvent): boolean {
  if (!view.editable || event.button !== 0) return false
  const target = event.target instanceof Element ? event.target : null
  if (!target || target.closest(BLOCK_CONTROL)) return false
  const block = target.closest(BLOCK)
  if (!block) return false
  const pos = blockPosFromDOM(view, block)
  if (pos === null) return false
  event.preventDefault()
  view.dispatch(view.state.tr.setSelection(NodeSelection.create(view.state.doc, pos)))
  return true
}

// prosemirror-view 对高于视口的矩形会把顶边滚到视口外 margin 处，反复调用就来回翻
function scrollNodeSelection(view: EditorView): boolean {
  const { selection } = view.state
  if (!(selection instanceof NodeSelection)) return false
  const dom = view.nodeDOM(selection.from)
  const scroller = view.dom.closest('.md-viewport')
  if (!(dom instanceof HTMLElement) || !(scroller instanceof HTMLElement)) return true
  const rect = dom.getBoundingClientRect()
  const bounds = scroller.getBoundingClientRect()
  const bottom = bounds.bottom - CARET_BOTTOM_MARGIN
  if (rect.top >= bounds.top && rect.bottom <= bottom) return true
  scroller.scrollTop +=
    rect.top < bounds.top || rect.height > bottom - bounds.top
      ? rect.top - bounds.top - SCROLL_MARGIN
      : rect.bottom - bottom
  return true
}

export function createEditorKit(opts: EditorKitOptions): EditorKit {
  const { placeholder, nodeViews, isPanelMode } = opts

  let editor: Editor | null = null
  let suppress = false
  let broken = false
  let requestedEditable = opts.editable
  let stateFrame = 0
  let lastStateJson = ''
  let tapStart: { x: number; y: number; t: number } | null = null
  // Flutter 表单抢焦点时 Chromium 会折叠选区，所以弹表单前先 holdSelection，回来时还原一次
  let held: { doc: PMNode; selection: Selection } | null = null
  let pointerDownAt = 0
  const pendingUploads = new Map<string, (name: string) => void>()
  let uploadSeq = 0

  const serialize = (): string => (editor ? JSON.stringify(editor.getJSON()) : '')

  const currentState = (): EditorState | null => (editor && !editor.isDestroyed ? deriveState(editor) : null)

  const postState = (): void => {
    stateFrame = 0
    const s = currentState()
    if (!s) return
    const json = JSON.stringify(s)
    if (json === lastStateJson) return
    lastStateJson = json
    post('state', s)
  }

  const scheduleState = (): void => {
    if (stateFrame) return
    stateFrame = requestAnimationFrame(postState)
  }

  const applyEditable = (): void => {
    const value = requestedEditable && !broken
    if (editor && editor.isEditable !== value) editor.setEditable(value, false)
    scheduleState()
  }

  const holdSelection = (): void => {
    if (editor) held = { doc: editor.state.doc, selection: editor.state.selection }
  }

  const restoreHeldSelection = (ed: Editor): void => {
    const saved = held
    held = null
    if (!saved || ed.state.doc !== saved.doc) return
    if (!ed.state.selection.eq(saved.selection)) ed.view.dispatch(ed.state.tr.setSelection(saved.selection))
  }

  const exec = (command: string, args?: ExecArgs): void => {
    const ed = editor
    if (!ed) return
    if (!ed.isFocused) restoreHeldSelection(ed)
    if (!execCommand({ editor: ed, panelMode: isPanelMode() }, command, args)) {
      post('error', `unknown exec command: ${command}`)
    }
  }

  const insertImageAt = (name: string, pos?: number): void => {
    const ed = editor
    if (!ed) return
    if (pos != null) ed.commands.setTextSelection(pos)
    exec('insertImage', { name })
  }

  const uploadFiles = (files: File[], pos?: number): boolean => {
    const images = files.filter((f) => f.type.startsWith('image/'))
    if (!images.length) return false
    for (const file of images) {
      const reader = new FileReader()
      reader.onload = () => {
        const id = `up-${++uploadSeq}`
        pendingUploads.set(id, (name) => insertImageAt(name, pos))
        post('saveImage', { id, dataUri: String(reader.result), name: file.name })
      }
      reader.readAsDataURL(file)
    }
    return true
  }

  const resetHistory = (ed: Editor): void => {
    // 不可用 view.updateState()：会绕过 dispatchTransaction 导致 history 复活，撤销后内容变空
    ed.unregisterPlugin('history')
    ed.registerPlugin(history(HISTORY_OPTIONS))
    const tr = ed.state.tr.setSelection(Selection.atStart(ed.state.doc))
    ed.view.dispatch(tr.setMeta('addToHistory', false))
  }

  const loadContent = (content: string): void => {
    const ed = editor
    if (!ed) return
    cancelChange()
    dismissSuggestion()
    clearSearch(ed)
    broken = false
    const parsed = parseContent(content)
    suppress = true
    try {
      if ('error' in parsed) {
        broken = true
        post('contentError', { message: parsed.error })
        ed.commands.setContent(wrapPlainText(content), { emitUpdate: false, errorOnInvalidContent: false })
      } else if (docVersion(parsed.doc) > SCHEMA_VERSION) {
        broken = true
        post('contentError', { message: `unsupported schema version ${docVersion(parsed.doc)}` })
        const shown = sanitizeForDisplay(normalizeDoc(parsed.doc), ed.schema)
        ed.commands.setContent(shown ?? '', { emitUpdate: false, errorOnInvalidContent: false })
      } else {
        const doc = normalizeDoc(parsed.doc)
        try {
          ed.commands.setContent(doc, { emitUpdate: false, errorOnInvalidContent: true })
        } catch (e) {
          broken = true
          post('contentError', { message: errorMessage(e) })
          const shown = sanitizeForDisplay(doc, ed.schema)
          ed.commands.setContent(shown ?? '', { emitUpdate: false, errorOnInvalidContent: false })
        }
      }
      resetHistory(ed)
    } finally {
      suppress = false
    }
    applyEditable()
  }

  const handleBeforeInput = (view: EditorView, event: InputEvent): boolean => {
    const type = event.inputType
    if (type === 'deleteContentBackward' && editor?.commands.undoInputRule()) {
      event.preventDefault()
      return true
    }
    if (!type.startsWith('insert') || !selectedBlock(view.state)) return false
    leaveSelectedBlock(view)
    if (type === 'insertParagraph' || type === 'insertLineBreak') {
      event.preventDefault()
      return true
    }
    // 自己落字：浏览器按事件前的选区插入，会把块的 DOM 换掉
    if (type === 'insertText' && event.data && event.cancelable) {
      event.preventDefault()
      view.dispatch(view.state.tr.insertText(event.data).scrollIntoView())
      return true
    }
    return false
  }

  const onPointerDown = (_view: EditorView, event: PointerEvent): boolean => {
    pointerDownAt = Date.now()
    held = null
    tapStart = event.isPrimary ? { x: event.clientX, y: event.clientY, t: pointerDownAt } : null
    return false
  }

  const onPointerUp = (view: EditorView, event: PointerEvent): boolean => {
    const start = tapStart
    tapStart = null
    if (!start || !isPanelMode() || !view.editable) return false
    if (Math.hypot(event.clientX - start.x, event.clientY - start.y) > TAP_SLOP) return false
    if (Date.now() - start.t > TAP_MAX_MS) return false
    const target = event.target instanceof Element ? event.target : null
    if (!target || target.closest(NOT_TEXT_TAP)) return false
    post('editorTap')
    return false
  }

  const handlePaste = (_view: EditorView, event: ClipboardEvent): boolean => {
    const ed = editor
    const data = event.clipboardData
    if (!ed || !data || !ed.isEditable) return false
    if (data.files.length > 0) return uploadFiles(Array.from(data.files))
    if (data.types.some((t) => t !== 'text/plain')) return false
    const text = data.getData('text/plain')
    if (!text || !looksLikeMarkdown(text)) return false
    if (ed.state.selection.$from.parent.type.spec.code) return false
    const parsed = ed.markdown?.parse(text)
    const blocks = parsed?.content
    if (!blocks?.length) return false
    // 解析出不合 schema 的结构（如段内图片）时退回默认粘贴
    try {
      ed.commands.insertContent(blocks)
    } catch {
      return false
    }
    return true
  }

  const extensions: AnyExtension[] = [
    StarterKit.configure({
      codeBlock: false,
      horizontalRule: false,
      link: false,
      underline: false,
      trailingNode: false,
    }),
    TrailingParagraph,
    DocVersion,
    LinkHrefOnly.configure({
      openOnClick: false,
      autolink: true,
      linkOnPaste: true,
      defaultProtocol: 'https',
      HTMLAttributes: { target: null, rel: null, class: null },
    }),
    UnderlineHtml,
    SingleHighlight,
    CodeBlockLowlight.configure({ lowlight }).extend({
      addNodeView: () => ReactNodeViewRenderer(nodeViews.codeBlock),
    }),
    ImageNode.extend({ addNodeView: () => ReactNodeViewRenderer(nodeViews.image) }),
    AudioNode.extend({ addNodeView: () => ReactNodeViewRenderer(nodeViews.audio) }),
    VideoNode.extend({ addNodeView: () => ReactNodeViewRenderer(nodeViews.video) }),
    AttachmentNode.extend({ addNodeView: () => ReactNodeViewRenderer(nodeViews.attachment) }),
    HorizontalRuleNode,
    TableKit.configure({ table: { resizable: false } }),
    TaskList,
    TaskItem.configure({ nested: true }),
    DiaryLink,
    CjkInputRules,
    SearchExtension,
    createMarkdownExtension(),
    Placeholder.configure({ placeholder }),
  ]

  const options: Partial<EditorOptions> = {
    editable: opts.editable,
    content: '',
    enableContentCheck: true,
    extensions,
    editorProps: {
      scrollMargin: { top: SCROLL_MARGIN, bottom: CARET_BOTTOM_MARGIN, left: 0, right: 0 },
      scrollThreshold: { top: SCROLL_MARGIN, bottom: CARET_BOTTOM_MARGIN, left: 0, right: 0 },
      handleScrollToSelection: scrollNodeSelection,
      handleTextInput: (view, _from, _to, text) => {
        if (!leaveSelectedBlock(view)) return false
        view.dispatch(view.state.tr.insertText(text).scrollIntoView())
        return true
      },
      handleKeyDown: (view, event) =>
        event.key === 'Enter' && !event.isComposing && leaveSelectedBlock(view),
      handlePaste,
      handleDrop: (_view, event, _slice, moved) => {
        if (moved || !event.dataTransfer?.files.length || !editor?.isEditable) return false
        const pos = editor.view.posAtCoords({ left: event.clientX, top: event.clientY })?.pos
        return uploadFiles(Array.from(event.dataTransfer.files), pos)
      },
      handleDOMEvents: {
        mousedown: (view, event) => selectBlockOnPress(view, event),
        pointerdown: onPointerDown,
        pointerup: onPointerUp,
        // 输入法组字不走 handleTextInput：先把选区挪出块再让浏览器落字
        compositionstart: (view) => {
          leaveSelectedBlock(view)
          return false
        },
        beforeinput: handleBeforeInput,
      },
    },
    onUpdate: () => {
      if (suppress || broken) return
      if (opts.onChangeAllowed && !opts.onChangeAllowed()) return
      scheduleChange(serialize)
    },
    onTransaction: () => scheduleState(),
    onFocus: () => {
      if (editor && Date.now() - pointerDownAt > 500) restoreHeldSelection(editor)
      post('focusChange', 'editor')
      scheduleState()
    },
    onBlur: () => {
      flushChange()
      post('focusChange', '')
      scheduleState()
    },
  }

  const api: EditorApi = {
    setContent: loadContent,
    setEditable: (value) => {
      requestedEditable = value
      applyEditable()
    },
    focus: () => {
      if (!editor) return
      restoreHeldSelection(editor)
      editor.commands.focus()
    },
    blur: () => {
      editor?.commands.blur()
    },
    holdSelection,
    resolveUpload: (id, name) => {
      const resolver = pendingUploads.get(id)
      if (!resolver) return
      pendingUploads.delete(id)
      if (name) resolver(name)
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
      dom?.scrollIntoView({ behavior: 'smooth', block: 'start' })
    },
    resumeVideo: (name, seconds) => {
      const ed = editor
      if (!ed) return
      let host: HTMLElement | null = null
      ed.state.doc.descendants((node, pos) => {
        if (host) return false
        if (node.type.name === 'video' && node.attrs.src === name) {
          host = ed.view.nodeDOM(pos) as HTMLElement | null
        }
        return true
      })
      const el = (host as HTMLElement | null)?.querySelector<HTMLVideoElement>('video') ?? null
      if (!el) return
      const apply = (): void => {
        el.currentTime = seconds
      }
      if (el.readyState >= 1) apply()
      else el.addEventListener('loadedmetadata', apply, { once: true })
    },
    exec,
    currentState,
  }

  return {
    options,
    api,
    attach: (e) => {
      editor = e
      applyEditable()
    },
  }
}
