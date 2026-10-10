import { Node, mergeAttributes } from '@tiptap/core'
import { mediaMarkdownSpec } from './markdown'
import { widthPercentAttribute } from './media-size'

function createMediaNode(opts: { name: 'audio' | 'video'; sizable: boolean }): Node {
  return Node.create({
    name: opts.name,
    group: 'block',
    atom: true,
    draggable: false,
    selectable: true,
    addAttributes() {
      return {
        filename: {
          default: null,
          parseHTML: (el) => el.getAttribute('data-filename'),
          renderHTML: (attrs) => (attrs.filename ? { 'data-filename': attrs.filename } : {}),
        },
        ...(opts.sizable ? { widthPercent: widthPercentAttribute } : {}),
      }
    },
    parseHTML() {
      return [{ tag: `div[data-media="${opts.name}"]` }]
    },
    renderHTML({ HTMLAttributes }) {
      return ['div', mergeAttributes(HTMLAttributes, { 'data-media': opts.name })]
    },
    ...mediaMarkdownSpec,
  })
}

export const Audio = createMediaNode({ name: 'audio', sizable: false })
export const Video = createMediaNode({ name: 'video', sizable: true })
