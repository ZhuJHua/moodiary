import { mergeAttributes } from '@tiptap/core'
import Image from '@tiptap/extension-image'
import ImageNodeView from '@/ui/nodes/ImageNodeView'
import { blockNodeView } from './block-node-view'
import { mediaNodeFor } from './markdown'
import { displaySrc, unproxyMedia } from './media'
import { widthPercentAttribute } from './media-size'

export const MediaImage = Image.extend({
  draggable: false,

  addAttributes() {
    const { width: _w, height: _h, ...parent } = (this.parent?.() ?? {}) as Record<string, unknown>
    return {
      ...parent,
      src: {
        default: null,
        parseHTML: (el) => unproxyMedia(el.getAttribute('src') ?? ''),
      },
      widthPercent: widthPercentAttribute,
    }
  },

  parseMarkdown: (token, helpers) => {
    const src = String(token.href ?? '')
    const kind = mediaNodeFor(src)
    if (kind !== 'image') return helpers.createNode(kind, { filename: src })
    return helpers.createNode('image', {
      src,
      alt: token.text || null,
      title: token.title || null,
    })
  },

  renderHTML({ HTMLAttributes }) {
    const attrs = { ...HTMLAttributes }
    if (typeof attrs.src === 'string') attrs.src = displaySrc(attrs.src)
    return ['img', mergeAttributes(this.options.HTMLAttributes, attrs)]
  },

  addNodeView() {
    return blockNodeView(ImageNodeView)
  },
})
