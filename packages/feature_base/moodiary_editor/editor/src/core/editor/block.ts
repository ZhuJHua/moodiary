import { Fragment, type Node as PMNode, type ResolvedPos } from '@tiptap/pm/model'
import { NodeSelection, Selection, TextSelection, type EditorState, type Transaction } from '@tiptap/pm/state'
import type { EditorView } from '@tiptap/pm/view'

const BLOCK_NODE_TYPES = ['image', 'video', 'audio', 'attachment', 'horizontalRule'] as const
export type BlockNodeType = (typeof BLOCK_NODE_TYPES)[number]

export const isBlockNodeType = (name: string): name is BlockNodeType =>
  (BLOCK_NODE_TYPES as readonly string[]).includes(name)

export function selectedBlock(state: EditorState): NodeSelection | null {
  const sel = state.selection
  return sel instanceof NodeSelection && sel.node.isBlock && sel.node.isAtom ? sel : null
}

const isEmptyParagraph = (node: PMNode | null | undefined): boolean =>
  !!node && node.type.name === 'paragraph' && node.content.size === 0

export function caretIntoNewParagraph(tr: Transaction, pos: number): void {
  if (!isEmptyParagraph(tr.doc.resolve(pos).nodeAfter)) {
    tr.insert(pos, tr.doc.type.schema.nodes.paragraph.create())
  }
  tr.setSelection(TextSelection.create(tr.doc, pos + 1))
}

export function leaveSelectedBlock(view: EditorView): boolean {
  const sel = selectedBlock(view.state)
  if (!sel) return false
  const tr = view.state.tr
  caretIntoNewParagraph(tr, sel.to)
  view.dispatch(tr.scrollIntoView())
  return true
}

export function caretAfterNode(tr: Transaction): boolean {
  const sel = tr.selection
  if (!(sel instanceof NodeSelection)) return false
  const after = tr.doc.resolve(sel.to).nodeAfter
  if (after?.isTextblock) {
    tr.setSelection(TextSelection.create(tr.doc, sel.to + 1))
  } else {
    caretIntoNewParagraph(tr, sel.to)
  }
  return true
}

function hostDepth($from: ResolvedPos, type: PMNode['type']): number {
  let depth = $from.depth
  while (depth > 1 && !$from.node(depth).isTextblock) depth -= 1
  for (let d = depth; d >= 1; d -= 1) {
    const parent = $from.node(d - 1)
    const index = $from.index(d - 1)
    if (parent.canReplaceWith(index + 1, index + 1, type)) return d
  }
  return 1
}

function insertBlockAfterCurrent(tr: Transaction, node: PMNode): number {
  const sel = tr.selection
  if (sel instanceof NodeSelection && sel.node.isBlock) {
    tr.insert(sel.to, node)
    return sel.to
  }
  const $from = sel.$from
  if ($from.depth === 0) {
    tr.insert($from.pos, node)
    return $from.pos
  }
  const d = hostDepth($from, node.type)
  const block = $from.node(d)
  const parent = $from.node(d - 1)
  const index = $from.index(d - 1)
  if (isEmptyParagraph(block) && parent.canReplaceWith(index, index + 1, node.type)) {
    const start = $from.before(d)
    tr.replaceWith(start, $from.after(d), node)
    return start
  }
  const pos = $from.after(d)
  tr.insert(pos, node)
  return pos
}

export function insertAtomBlock(tr: Transaction, node: PMNode): void {
  const pos = insertBlockAfterCurrent(tr, node)
  caretIntoNewParagraph(tr, pos + node.nodeSize)
}

export function insertContainerBlock(tr: Transaction, node: PMNode): void {
  const pos = insertBlockAfterCurrent(tr, node)
  tr.setSelection(Selection.near(tr.doc.resolve(pos + 1)))
}

export function currentTextblockIsEmptyParagraph(state: EditorState): boolean {
  const { selection } = state
  return selection.empty && isEmptyParagraph(selection.$from.parent)
}

interface MovableBlock {
  node: PMNode
  start: number
  parent: PMNode
  index: number
}

const LIST_ITEMS = new Set(['listItem', 'taskItem'])

function movableBlock(doc: PMNode, sel: Selection): MovableBlock | null {
  if (sel instanceof NodeSelection) {
    const $pos = doc.resolve(sel.from)
    return { node: sel.node, start: sel.from, parent: $pos.parent, index: $pos.index() }
  }
  const $from = sel.$from
  if ($from.depth === 0) return null
  let depth = 1
  for (let d = $from.depth; d >= 1; d -= 1) {
    if (LIST_ITEMS.has($from.node(d).type.name)) {
      depth = d
      break
    }
  }
  return {
    node: $from.node(depth),
    start: $from.before(depth),
    parent: $from.node(depth - 1),
    index: $from.index(depth - 1),
  }
}

export function moveBlock(tr: Transaction, dir: -1 | 1): boolean {
  const sel = tr.selection
  const target = movableBlock(tr.doc, sel)
  if (!target) return false
  const { node, start, parent, index } = target
  const sibling = parent.maybeChild(index + dir)
  if (!sibling) return false
  // 列表项须段落打头（paragraph block*），换位后不合法就不动
  const children: PMNode[] = []
  parent.forEach((child) => children.push(child))
  children[index] = sibling
  children[index + dir] = node
  if (!parent.type.validContent(Fragment.from(children))) return false
  const shift = dir < 0 ? -sibling.nodeSize : sibling.nodeSize
  tr.delete(start, start + node.nodeSize)
  tr.insert(start + shift, node)
  if (sel instanceof NodeSelection) {
    tr.setSelection(NodeSelection.create(tr.doc, start + shift))
  } else {
    tr.setSelection(TextSelection.create(tr.doc, sel.anchor + shift, sel.head + shift))
  }
  return true
}
