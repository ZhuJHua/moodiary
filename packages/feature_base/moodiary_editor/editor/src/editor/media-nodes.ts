import { Node, mergeAttributes } from '@tiptap/core'
import { VueNodeViewRenderer } from '@tiptap/vue-3'
import type { Component } from 'vue'
import AudioNodeView from '../components/nodes/AudioNodeView.vue'
import VideoNodeView from '../components/nodes/VideoNodeView.vue'

function createMediaNode(opts: { name: string; view: Component }): Node {
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
      }
    },
    parseHTML() {
      return [{ tag: `div[data-media="${opts.name}"]` }]
    },
    renderHTML({ HTMLAttributes }) {
      return ['div', mergeAttributes(HTMLAttributes, { 'data-media': opts.name })]
    },
    addNodeView() {
      return VueNodeViewRenderer(opts.view)
    },
  })
}

export const Audio = createMediaNode({ name: 'audio', view: AudioNodeView })
export const Video = createMediaNode({ name: 'video', view: VideoNodeView })
