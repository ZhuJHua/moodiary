import type { Editor } from '@tiptap/core'
import { redoDepth, undoDepth } from '@tiptap/pm/history'
import { NodeSelection } from '@tiptap/pm/state'
import { isBlockNodeType, type BlockNodeType } from './block'
import { linkAt } from './link'

type BlockKind =
  | 'paragraph'
  | 'heading1'
  | 'heading2'
  | 'heading3'
  | 'heading4'
  | 'heading5'
  | 'heading6'
  | 'blockquote'
  | 'codeBlock'

export interface EditorState {
  marks: {
    bold: boolean
    italic: boolean
    underline: boolean
    strike: boolean
    code: boolean
    highlight: boolean
    link: boolean
  }
  block: BlockKind
  list: null | 'bullet' | 'ordered' | 'task'
  canIndent: boolean
  canOutdent: boolean
  canUndo: boolean
  canRedo: boolean
  selection: 'caret' | 'text' | 'node'
  node: null | { type: BlockNodeType; attrs: Record<string, unknown> }
  inTable: boolean
  link: null | { href: string; text: string }
  selectedText: string
}

const LIST_KIND: Record<string, EditorState['list']> = {
  bulletList: 'bullet',
  orderedList: 'ordered',
  taskList: 'task',
}

export function deriveState(editor: Editor): EditorState {
  const { state } = editor
  const { selection } = state
  const { $from } = selection

  let block: BlockKind = 'paragraph'
  let list: EditorState['list'] = null
  let listItem = ''
  let inTable = false
  let inBlockquote = false
  for (let d = $from.depth; d > 0; d -= 1) {
    const name = $from.node(d).type.name
    if (!list && LIST_KIND[name] !== undefined) list = LIST_KIND[name]
    if (!listItem && (name === 'listItem' || name === 'taskItem')) listItem = name
    if (name === 'table') inTable = true
    if (name === 'blockquote') inBlockquote = true
  }
  const parent = $from.parent
  if (parent.type.name === 'codeBlock') block = 'codeBlock'
  else if (parent.type.name === 'heading') block = `heading${parent.attrs.level}` as BlockKind
  else if (inBlockquote) block = 'blockquote'

  const isNode = selection instanceof NodeSelection
  const node =
    isNode && isBlockNodeType(selection.node.type.name)
      ? { type: selection.node.type.name as BlockNodeType, attrs: { ...selection.node.attrs } }
      : null

  const at = linkAt(state)
  const link: EditorState['link'] = at
    ? { href: at.href, text: state.doc.textBetween(at.from, at.to, ' ') }
    : null
  const linkActive = editor.isActive('link') || at !== null

  const can = editor.can()
  return {
    marks: {
      bold: editor.isActive('bold'),
      italic: editor.isActive('italic'),
      underline: editor.isActive('underline'),
      strike: editor.isActive('strike'),
      code: editor.isActive('code'),
      highlight: editor.isActive('highlight'),
      link: linkActive,
    },
    block,
    list,
    canIndent: !!listItem && can.sinkListItem(listItem),
    canOutdent: !!listItem && can.liftListItem(listItem),
    canUndo: undoDepth(state) > 0,
    canRedo: redoDepth(state) > 0,
    selection: isNode ? 'node' : selection.empty ? 'caret' : 'text',
    node,
    inTable,
    link,
    selectedText:
      isNode || selection.empty ? '' : state.doc.textBetween(selection.from, selection.to, ' ').slice(0, 200),
  }
}
