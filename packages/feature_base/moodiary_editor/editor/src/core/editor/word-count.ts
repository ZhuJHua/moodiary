import type { Node as PMNode } from '@tiptap/pm/model'

// 与 Dart 侧 TiptapContent.plainText 同一套规则，两端字数才一致
const BLOCK_TYPES = new Set(['paragraph', 'heading', 'listItem', 'blockquote', 'codeBlock', 'horizontalRule'])

export function plainTextOf(doc: PMNode): string {
  let out = ''
  const walk = (node: PMNode): void => {
    if (node.isText) out += node.text ?? ''
    if (node.type.name === 'diaryLink') out += String(node.attrs.label ?? '')
    node.forEach(walk)
    if (BLOCK_TYPES.has(node.type.name)) out += '\n'
  }
  walk(doc)
  return out.replace(/\n{3,}/g, '\n\n').trim()
}

const segmenter =
  typeof Intl !== 'undefined' && 'Segmenter' in Intl
    ? new Intl.Segmenter(undefined, { granularity: 'grapheme' })
    : null

export function countGraphemes(text: string): number {
  if (!segmenter) return Array.from(text).length
  let n = 0
  for (const _ of segmenter.segment(text)) n += 1
  return n
}

export function wordCountOf(doc: PMNode): number {
  return countGraphemes(plainTextOf(doc))
}
