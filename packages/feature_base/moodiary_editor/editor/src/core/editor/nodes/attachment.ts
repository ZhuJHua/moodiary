import { Node, mergeAttributes, type JSONContent, type MarkdownToken } from '@tiptap/core'
import { nameAttribute } from './media'

const LINE = /^\[((?:\\.|[^\]\\\n])*)\]\((file-[^)\s]+)\)[ \t]*(?:\n|$)/
// marked 拿段内剩余文本问 start，行首用 ^ 会把 x[a](file-y) 拆开，只认换行之后
const LINE_START = /(\n)\[(?:\\.|[^\]\\\n])*\]\(file-[^)\s]+\)[ \t]*(?:\n|$)/

const escapeLabel = (text: string): string => text.replace(/[\\[\]]/g, (c) => `\\${c}`)
const unescapeLabel = (text: string): string => text.replace(/\\(.)/g, '$1')

export const AttachmentNode = Node.create({
  name: 'attachment',
  group: 'block',
  atom: true,
  draggable: false,
  selectable: true,

  addAttributes() {
    return {
      src: {
        default: null,
        parseHTML: (el) => el.getAttribute('data-src'),
        renderHTML: (attrs) => (attrs.src ? { 'data-src': attrs.src } : {}),
      },
      name: nameAttribute,
      mime: {
        default: null,
        parseHTML: (el) => el.getAttribute('data-mime'),
        renderHTML: (attrs) => (attrs.mime ? { 'data-mime': attrs.mime } : {}),
      },
      size: {
        default: null,
        parseHTML: (el) => {
          const n = Number(el.getAttribute('data-size'))
          return Number.isFinite(n) && n >= 0 ? n : null
        },
        renderHTML: (attrs) => (typeof attrs.size === 'number' ? { 'data-size': String(attrs.size) } : {}),
      },
    }
  },

  parseHTML() {
    return [{ tag: 'div[data-type="attachment"]' }]
  },

  renderHTML({ node, HTMLAttributes }) {
    return [
      'div',
      mergeAttributes(HTMLAttributes, { 'data-type': 'attachment' }),
      String(node.attrs.name ?? node.attrs.src ?? ''),
    ]
  },

  markdownTokenName: 'attachment',

  markdownTokenizer: {
    name: 'attachment',
    level: 'block',
    start: (src: string) => {
      const m = LINE_START.exec(src)
      return m ? m.index + m[1].length : -1
    },
    tokenize: (src: string) => {
      const m = LINE.exec(src)
      if (!m) return undefined
      return { type: 'attachment', raw: m[0], name: unescapeLabel(m[1]), src: m[2] }
    },
  },

  parseMarkdown: (token: MarkdownToken) => ({
    type: 'attachment',
    attrs: { src: token.src ?? null, name: token.name || null, mime: null, size: null },
  }),

  renderMarkdown: (node: JSONContent) =>
    `[${escapeLabel(String(node.attrs?.name ?? ''))}](${String(node.attrs?.src ?? '')})`,
})
