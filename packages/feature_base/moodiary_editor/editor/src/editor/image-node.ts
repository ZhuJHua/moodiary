import { mergeAttributes } from '@tiptap/core'
import Image from '@tiptap/extension-image'
import { VueNodeViewRenderer } from '@tiptap/vue-3'
import ImageNodeView from '../components/nodes/ImageNodeView.vue'
import { displaySrc, unproxyMedia } from './media'

export const MIN_IMAGE_PERCENT = 25

export const IMAGE_SIZE_STOPS: readonly number[] = [25, 50, 75, 100]

const SNAP_TOLERANCE = 3

export function clampWidthPercent(value: number): number {
  return Math.min(100, Math.max(MIN_IMAGE_PERCENT, Math.round(value)))
}

export function snapWidthPercent(value: number): number {
  const clamped = clampWidthPercent(value)
  const hit = IMAGE_SIZE_STOPS.find((stop) => Math.abs(clamped - stop) <= SNAP_TOLERANCE)
  return hit ?? clamped
}

export const MediaImage = Image.extend({
  draggable: false,

  addAttributes() {
    return {
      ...this.parent?.(),
      src: {
        default: null,
        parseHTML: (el) => unproxyMedia(el.getAttribute('src') ?? ''),
      },
      width: { default: null, rendered: false, parseHTML: () => null },
      height: { default: null, rendered: false, parseHTML: () => null },
      widthPercent: {
        default: null,
        parseHTML: (el) => {
          const raw = el.getAttribute('data-width-percent')
          if (raw === null) return null
          const n = Number(raw)
          return Number.isFinite(n) ? clampWidthPercent(n) : null
        },
        renderHTML: (attrs) => {
          const v = attrs.widthPercent
          if (typeof v !== 'number') return {}
          return { 'data-width-percent': String(v), style: `max-width: ${v}%` }
        },
      },
    }
  },

  renderHTML({ HTMLAttributes }) {
    const attrs = { ...HTMLAttributes }
    if (typeof attrs.src === 'string') attrs.src = displaySrc(attrs.src)
    return ['img', mergeAttributes(this.options.HTMLAttributes, attrs)]
  },

  addNodeView() {
    return VueNodeViewRenderer(ImageNodeView)
  },
})
