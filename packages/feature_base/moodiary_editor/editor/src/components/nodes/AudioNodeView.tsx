import { NodeViewWrapper, type NodeViewProps } from '@tiptap/react'

// TODO(react-migration): port from AudioNodeView.vue
export default function AudioNodeView({ selected }: NodeViewProps) {
  return (
    <NodeViewWrapper
      className={`moodiary-media moodiary-media--audio${selected ? ' is-selected' : ''}`}
      contentEditable={false}
    >
      <div className="moodiary-block__body" />
    </NodeViewWrapper>
  )
}
