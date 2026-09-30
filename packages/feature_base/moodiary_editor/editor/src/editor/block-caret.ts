import { TextSelection, type Transaction } from '@tiptap/pm/state'

export function caretAfter(tr: Transaction, pos: number): void {
  if (!tr.doc.resolve(pos).nodeAfter?.isTextblock) {
    tr.insert(pos, tr.doc.type.schema.nodes.paragraph.create())
  }
  tr.setSelection(TextSelection.create(tr.doc, pos + 1))
}

export function caretBefore(tr: Transaction, pos: number): void {
  if (tr.doc.resolve(pos).nodeBefore?.isTextblock) {
    tr.setSelection(TextSelection.create(tr.doc, pos - 1))
    return
  }
  insertParagraph(tr, pos)
}

export function insertParagraph(tr: Transaction, pos: number): void {
  tr.insert(pos, tr.doc.type.schema.nodes.paragraph.create())
  tr.setSelection(TextSelection.create(tr.doc, pos + 1))
}
