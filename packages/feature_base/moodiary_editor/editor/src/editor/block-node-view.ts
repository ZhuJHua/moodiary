import type { NodeViewRenderer } from '@tiptap/core'
import { VueNodeViewRenderer } from '@tiptap/vue-3'
import type { Component } from 'vue'

const PASSTHROUGH = new Set(['copy', 'cut', 'paste', 'drop', 'dragover', 'dragenter'])

export function blockNodeView(view: Component): NodeViewRenderer {
  return VueNodeViewRenderer(view, {
    stopEvent: ({ event }) => {
      if (PASSTHROUGH.has(event.type)) return false
      if (event.type === 'dragstart') event.preventDefault()
      return true
    },
  })
}
