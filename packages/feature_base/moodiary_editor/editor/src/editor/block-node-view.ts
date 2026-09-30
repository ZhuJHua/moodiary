import type { NodeViewRenderer } from '@tiptap/core'
import { ReactNodeViewRenderer } from '@tiptap/react'

const PASSTHROUGH = new Set(['copy', 'cut', 'paste', 'drop', 'dragover', 'dragenter'])

export function blockNodeView(view: Parameters<typeof ReactNodeViewRenderer>[0]): NodeViewRenderer {
  return ReactNodeViewRenderer(view, {
    stopEvent: ({ event }) => {
      if (PASSTHROUGH.has(event.type)) return false
      if (event.type === 'dragstart') event.preventDefault()
      return true
    },
  })
}
