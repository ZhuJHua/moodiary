import { Node, mergeAttributes } from '@tiptap/core'
import { VueNodeViewRenderer } from '@tiptap/vue-3'
import type { Component } from 'vue'
import AudioNodeView from '../components/nodes/AudioNodeView.vue'
import VideoNodeView from '../components/nodes/VideoNodeView.vue'
import { mediaMarkdownSpec } from './markdown'
import { widthPercentAttribute } from './media-size'

function createMediaNode(opts: {
  name: 'audio' | 'video'
  view: Component
  sizable: boolean
}): Node {
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
    addNodeView() {
      return VueNodeViewRenderer(opts.view)
    },
  })
}

export const Audio = createMediaNode({ name: 'audio', view: AudioNodeView, sizable: false })
export const Video = createMediaNode({ name: 'video', view: VideoNodeView, sizable: true })
