import { type ChainedCommands, type Editor, type JSONContent } from '@tiptap/core'
import type { Node as PMNode } from '@tiptap/pm/model'
import { NodeSelection, TextSelection } from '@tiptap/pm/state'
import { post } from '@/core/bridge/post'
import {
  caretAfterNode,
  caretIntoNewParagraph,
  currentTextblockIsEmptyParagraph,
  insertAtomBlock,
  insertContainerBlock,
  moveBlock,
  selectedBlock,
} from './block'
import { linkAt } from './link'
import { HR_VARIANTS, clampWidthPercent, type HorizontalRuleVariant } from './normalize'
import {
  clearSearch,
  replaceAllMatches,
  replaceCurrent,
  searchNext,
  searchPrev,
  searchStatus,
  startSearch,
} from './search'

export type ExecArgs = Record<string, unknown>

interface ExecContext {
  editor: Editor
  // 面板顶替键盘时不 focus()：否则系统键盘会被叫回来
  panelMode: boolean
}

interface RunContext extends ExecContext {
  focus: boolean
}

type Handler = (ctx: RunContext, args: ExecArgs) => void

const chain = (ctx: RunContext): ChainedCommands =>
  ctx.focus ? ctx.editor.chain().focus(undefined, { scrollIntoView: false }) : ctx.editor.chain()

const str = (v: unknown): string => (typeof v === 'string' ? v : '')

const listItemName = (editor: Editor): string | null => {
  const { $from } = editor.state.selection
  for (let d = $from.depth; d > 0; d -= 1) {
    const name = $from.node(d).type.name
    if (name === 'listItem' || name === 'taskItem') return name
  }
  return null
}

function insertAtom(ctx: RunContext, json: JSONContent): void {
  const node = ctx.editor.schema.nodeFromJSON(json)
  chain(ctx)
    .command(({ tr }) => {
      insertAtomBlock(tr, node)
      tr.scrollIntoView()
      return true
    })
    .run()
}

const MEDIA_TYPES = new Set(['image', 'video', 'audio', 'attachment'])

const SIZED_TYPES = new Set(['image', 'video'])

function sizedNode(editor: Editor): NodeSelection | null {
  const sel = editor.state.selection
  return sel instanceof NodeSelection && SIZED_TYPES.has(sel.node.type.name) ? sel : null
}

const mediaName = (v: unknown): string | null => str(v).trim() || null

function insertMedia(ctx: RunContext, type: 'image' | 'video' | 'audio', args: ExecArgs): void {
  if (str(args.name)) insertAtom(ctx, { type, attrs: { src: str(args.name), name: mediaName(args.displayName) } })
}

function insertContainer(
  ctx: RunContext,
  json: JSONContent,
  turnInto: (c: ChainedCommands) => ChainedCommands,
): void {
  if (currentTextblockIsEmptyParagraph(ctx.editor.state)) {
    turnInto(chain(ctx)).run()
    return
  }
  const node: PMNode = ctx.editor.schema.nodeFromJSON(json)
  chain(ctx)
    .command(({ tr }) => {
      insertContainerBlock(tr, node)
      tr.scrollIntoView()
      return true
    })
    .run()
}

const LINK_SCHEMES = new Set(['http', 'https', 'mailto', 'tel', 'sms'])

export function normalizeHref(raw: string): string {
  const href = raw.trim()
  if (!href) return ''
  if (/^(mailto|tel|sms):/i.test(href)) return href
  // 冒号后跟数字是端口（example.com:8080），不是协议
  const scheme = /^([a-z][a-z0-9+.-]*):(?!\d)/i.exec(href)?.[1]
  if (scheme) return LINK_SCHEMES.has(scheme.toLowerCase()) ? href : ''
  return `https://${href.replace(/^\/+/, '')}`
}

function setLink(ctx: RunContext, args: ExecArgs): void {
  const href = normalizeHref(str(args.href))
  if (!href) return
  const { editor } = ctx
  const { selection } = editor.state
  const range = selection.empty ? linkAt(editor.state) : { from: selection.from, to: selection.to }
  const text = str(args.text) || (range ? editor.state.doc.textBetween(range.from, range.to, ' ') : '') || href
  const from = range?.from ?? selection.from
  const to = range?.to ?? selection.to
  chain(ctx)
    .command(({ tr }) => {
      const type = editor.schema.marks.link
      const link = type.create({ href })
      if (from < to && tr.doc.textBetween(from, to, ' ') === text) {
        tr.removeMark(from, to, type).addMark(from, to, link)
      } else {
        const marks = tr.doc.resolve(from).marks().filter((m) => m.type !== type)
        tr.replaceWith(from, to, editor.schema.text(text, [...marks, link]))
      }
      tr.setSelection(TextSelection.create(tr.doc, from + text.length))
      tr.removeStoredMark(type)
      return true
    })
    .run()
}

function selectedNodeOf(editor: Editor, type: string): PMNode | null {
  const sel = editor.state.selection
  return sel instanceof NodeSelection && sel.node.type.name === type ? sel.node : null
}

function imageSources(editor: Editor): string[] {
  const srcs: string[] = []
  editor.state.doc.descendants((node) => {
    if (node.type.name === 'image') {
      const src = str(node.attrs.src)
      if (src && !src.startsWith('data:')) srcs.push(src)
    }
    return true
  })
  return srcs
}

export function postImageTap(editor: Editor, src: string): void {
  if (!src || src.startsWith('data:')) return
  const srcs = imageSources(editor)
  const index = srcs.indexOf(src)
  post('imageTap', { src, srcs: srcs.length ? srcs : [src], index: index < 0 ? 0 : index })
}

export function postAttachmentTap(node: PMNode): void {
  post('attachmentTap', {
    src: node.attrs.src ?? '',
    name: node.attrs.name ?? null,
    mime: node.attrs.mime ?? null,
  })
}

const postSearch = (editor: Editor): void => post('searchState', searchStatus(editor.state))

const HANDLERS: Record<string, Handler> = {
  toggleBold: (c) => void chain(c).toggleBold().run(),
  toggleItalic: (c) => void chain(c).toggleItalic().run(),
  toggleUnderline: (c) => void chain(c).toggleUnderline().run(),
  toggleStrike: (c) => void chain(c).toggleStrike().run(),
  toggleCode: (c) => void chain(c).toggleCode().run(),
  toggleHighlight: (c) => void chain(c).toggleHighlight().run(),
  clearFormatting: (c) => void chain(c).unsetAllMarks().clearNodes().run(),
  setParagraph: (c) => void chain(c).setParagraph().run(),
  setHeading: (c, a) => {
    const level = Number(a.level)
    if (level >= 1 && level <= 6) chain(c).toggleHeading({ level: level as 1 | 2 | 3 | 4 | 5 | 6 }).run()
  },
  toggleBlockquote: (c) => void chain(c).toggleBlockquote().run(),
  toggleCodeBlock: (c) => void chain(c).toggleCodeBlock().run(),
  toggleBulletList: (c) => void chain(c).toggleBulletList().run(),
  toggleOrderedList: (c) => void chain(c).toggleOrderedList().run(),
  toggleTaskList: (c) => void chain(c).toggleTaskList().run(),
  indent: (c) => {
    const item = listItemName(c.editor)
    if (item) chain(c).sinkListItem(item).run()
  },
  outdent: (c) => {
    const item = listItemName(c.editor)
    if (item) chain(c).liftListItem(item).run()
  },
  undo: (c) => void chain(c).undo().run(),
  redo: (c) => void chain(c).redo().run(),
  insertImage: (c, a) => insertMedia(c, 'image', a),
  insertVideo: (c, a) => insertMedia(c, 'video', a),
  insertAudio: (c, a) => insertMedia(c, 'audio', a),
  insertAttachment: (c, a) => {
    if (!str(a.name)) return
    insertAtom(c, {
      type: 'attachment',
      attrs: {
        src: str(a.name),
        name: mediaName(a.displayName),
        mime: str(a.mime) || null,
        size: typeof a.size === 'number' && Number.isFinite(a.size) ? a.size : null,
      },
    })
  },
  insertTable: (c) => void chain(c).insertTable({ rows: 3, cols: 3, withHeaderRow: true }).run(),
  insertHorizontalRule: (c, a) => {
    const variant = HR_VARIANTS.includes(a.variant as HorizontalRuleVariant) ? a.variant : 'solid'
    insertAtom(c, { type: 'horizontalRule', attrs: { variant, label: null } })
  },
  insertBlockquote: (c) =>
    insertContainer(c, { type: 'blockquote', content: [{ type: 'paragraph' }] }, (ch) => ch.toggleBlockquote()),
  insertCodeBlock: (c) => insertContainer(c, { type: 'codeBlock' }, (ch) => ch.setCodeBlock()),
  insertTaskList: (c) =>
    insertContainer(
      c,
      { type: 'taskList', content: [{ type: 'taskItem', attrs: { checked: false }, content: [{ type: 'paragraph' }] }] },
      (ch) => ch.toggleTaskList(),
    ),
  insertDiaryLink: (c) => void chain(c).insertContent('[[').run(),
  setLink,
  unsetLink: (c) => {
    const link = linkAt(c.editor.state)
    if (link) chain(c).setTextSelection({ from: link.from, to: link.to }).unsetLink().run()
  },
  openLink: (c) => {
    const href = linkAt(c.editor.state)?.href
    if (href) post('urlTap', { href })
  },
  copyLink: (c) => {
    const href = linkAt(c.editor.state)?.href
    if (href) post('copy', { text: href })
  },
  setMediaWidth: (c, a) => {
    const sel = sizedNode(c.editor)
    const reset = a.percent === null
    const percent = reset ? null : clampWidthPercent(Number(a.percent))
    if (!sel || (!reset && percent === null)) return
    chain(c).updateAttributes(sel.node.type.name, { widthPercent: percent }).run()
  },
  previewMediaWidth: (c, a) => {
    const sel = sizedNode(c.editor)
    const percent = clampWidthPercent(Number(a.percent))
    const dom = sel && c.editor.view.nodeDOM(sel.from)
    if (percent === null || !(dom instanceof HTMLElement)) return
    const wrapper = dom.matches('[data-node-view-wrapper]')
      ? dom
      : dom.querySelector<HTMLElement>('[data-node-view-wrapper]')
    if (wrapper) wrapper.style.width = `${percent}%`
  },
  setMediaName: (c, a) => {
    const sel = c.editor.state.selection
    if (!(sel instanceof NodeSelection) || !MEDIA_TYPES.has(sel.node.type.name)) return
    chain(c).updateAttributes(sel.node.type.name, { name: mediaName(a.name) }).run()
  },
  moveBlockUp: (c) => void chain(c).command(({ tr }) => moveBlock(tr, -1)).scrollIntoView().run(),
  moveBlockDown: (c) => void chain(c).command(({ tr }) => moveBlock(tr, 1)).scrollIntoView().run(),
  deleteBlock: (c) => {
    if (c.editor.state.selection instanceof NodeSelection) chain(c).deleteSelection().run()
  },
  setHorizontalRule: (c, a) => {
    if (!selectedNodeOf(c.editor, 'horizontalRule')) return
    const variant = HR_VARIANTS.includes(a.variant as HorizontalRuleVariant) ? a.variant : 'solid'
    const label = variant === 'text' ? str(a.label) || null : null
    chain(c).updateAttributes('horizontalRule', { variant, label }).run()
  },
  previewImage: (c) => {
    const node = selectedNodeOf(c.editor, 'image')
    if (node) postImageTap(c.editor, str(node.attrs.src))
  },
  openAttachment: (c) => {
    const node = selectedNodeOf(c.editor, 'attachment')
    if (node) postAttachmentTap(node)
  },
  copyCode: (c) => {
    const { $from } = c.editor.state.selection
    if ($from.parent.type.name === 'codeBlock') post('copy', { text: $from.parent.textContent })
  },
  exitCode: (c) => {
    const { $from } = c.editor.state.selection
    if ($from.parent.type.name !== 'codeBlock') return
    const after = $from.after()
    chain(c)
      .command(({ tr }) => {
        caretIntoNewParagraph(tr, after)
        return true
      })
      .scrollIntoView()
      .run()
  },
  caretAfterNode: (c) => {
    if (selectedBlock(c.editor.state)) chain(c).command(({ tr }) => caretAfterNode(tr)).scrollIntoView().run()
  },
  tableAddRowAfter: (c) => void chain(c).addRowAfter().run(),
  tableDeleteRow: (c) => void chain(c).deleteRow().run(),
  tableAddColumnAfter: (c) => void chain(c).addColumnAfter().run(),
  tableDeleteColumn: (c) => void chain(c).deleteColumn().run(),
  tableToggleHeaderRow: (c) => void chain(c).toggleHeaderRow().run(),
  tableDelete: (c) => void chain(c).deleteTable().run(),
  search: (c, a) => {
    startSearch(c.editor, str(a.query), a.caseSensitive === true)
    postSearch(c.editor)
  },
  searchNext: (c) => {
    searchNext(c.editor)
    postSearch(c.editor)
  },
  searchPrev: (c) => {
    searchPrev(c.editor)
    postSearch(c.editor)
  },
  replace: (c, a) => {
    if (c.editor.isEditable) replaceCurrent(c.editor, str(a.text))
    postSearch(c.editor)
  },
  replaceAll: (c, a) => {
    if (c.editor.isEditable) replaceAllMatches(c.editor, str(a.text))
    postSearch(c.editor)
  },
  clearSearch: (c) => {
    clearSearch(c.editor)
    postSearch(c.editor)
  },
}

const READ_ONLY_SAFE = new Set([
  'openLink',
  'copyLink',
  'previewImage',
  'openAttachment',
  'copyCode',
  'search',
  'searchNext',
  'searchPrev',
  'clearSearch',
])

// 选中块时先把光标挪到块后，否则块会被替换掉
const LEAVE_BLOCK_FIRST = new Set(['insertTable', 'insertDiaryLink', 'setLink'])

// 不 focus：键盘收着时点这些命令不该把键盘叫出来
const NO_FOCUS = new Set([...READ_ONLY_SAFE, 'undo', 'redo', 'replace', 'replaceAll'])

export const EXEC_COMMANDS: readonly string[] = Object.keys(HANDLERS)

export function execCommand(ctx: ExecContext, command: string, args: ExecArgs = {}): boolean {
  const handler = Object.prototype.hasOwnProperty.call(HANDLERS, command) ? HANDLERS[command] : undefined
  if (!handler) return false
  if (!ctx.editor.isEditable && !READ_ONLY_SAFE.has(command)) return true
  if (LEAVE_BLOCK_FIRST.has(command) && selectedBlock(ctx.editor.state)) {
    const tr = ctx.editor.state.tr
    caretAfterNode(tr)
    ctx.editor.view.dispatch(tr)
  }
  handler({ ...ctx, focus: !ctx.panelMode && !NO_FOCUS.has(command) }, args)
  return true
}
