import { Node, mergeAttributes, type Attribute, type JSONContent } from '@tiptap/core'
import { displaySrc, mediaKindOf, unproxyMedia } from '../media'
import { clampWidthPercent } from '../normalize'

const widthPercentAttribute: Partial<Attribute> = {
  default: null,
  parseHTML: (el) => {
    const raw = el.getAttribute('data-width-percent')
    return raw === null ? null : clampWidthPercent(Number(raw))
  },
  renderHTML: (attrs) => {
    const v = attrs.widthPercent
    return typeof v === 'number' ? { 'data-width-percent': String(v) } : {}
  },
}

export const nameAttribute: Partial<Attribute> = {
  default: null,
  parseHTML: (el) => el.getAttribute('data-name') || null,
  renderHTML: (attrs) => (attrs.name ? { 'data-name': attrs.name } : {}),
}

const srcOf = (el: HTMLElement): string => {
  const named = el.getAttribute('data-src') ?? ''
  return mediaKindOf(named) ? named : unproxyMedia(el.getAttribute('src') ?? '')
}

const escapeLabel = (text: string): string => text.replace(/[\\[\]]/g, (c) => `\\${c}`)
const unescapeLabel = (text: string): string => text.replace(/\\(.)/g, '$1')

const mediaMarkdown = (node: JSONContent): string =>
  `![${escapeLabel(String(node.attrs?.name ?? ''))}](${String(node.attrs?.src ?? '')})`

export const ImageNode = Node.create({
  name: 'image',
  group: 'block',
  atom: true,
  draggable: false,
  selectable: true,

  addAttributes() {
    return {
      src: {
        default: null,
        parseHTML: (el) => srcOf(el) || null,
      },
      name: {
        default: null,
        parseHTML: (el) => el.getAttribute('data-name') || el.getAttribute('alt') || null,
        renderHTML: (attrs) => (attrs.name ? { 'data-name': attrs.name, alt: attrs.name } : {}),
      },
      widthPercent: widthPercentAttribute,
    }
  },

  parseHTML() {
    return [{ tag: 'img[src]', getAttrs: (el) => (srcOf(el) ? null : false) }]
  },

  // data-src 让媒体名随剪贴板走，粘到别的会话不依赖本会话的地址映射
  renderHTML({ HTMLAttributes }) {
    const attrs = { ...HTMLAttributes }
    if (typeof attrs.src === 'string') {
      if (mediaKindOf(attrs.src)) attrs['data-src'] = attrs.src
      attrs.src = displaySrc(attrs.src)
    }
    return ['img', mergeAttributes(attrs)]
  },

  markdownTokenName: 'image',

  parseMarkdown: (token, helpers) => {
    const src = String(token.href ?? '')
    const kind = mediaKindOf(src)
    const name = unescapeLabel(String(token.text ?? '')) || token.title || null
    return helpers.createNode(kind === 'video' || kind === 'audio' ? kind : 'image', { src, name })
  },

  renderMarkdown: mediaMarkdown,
})

function createMediaNode(name: 'audio' | 'video'): Node {
  return Node.create({
    name,
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
        ...(name === 'video' ? { widthPercent: widthPercentAttribute } : {}),
      }
    },

    parseHTML() {
      return [{ tag: `div[data-media="${name}"]` }]
    },

    renderHTML({ HTMLAttributes }) {
      return ['div', mergeAttributes(HTMLAttributes, { 'data-media': name })]
    },

    renderMarkdown: mediaMarkdown,
  })
}

export const AudioNode = createMediaNode('audio')
export const VideoNode = createMediaNode('video')
