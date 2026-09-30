import { NodeViewWrapper, type NodeViewProps } from '@tiptap/react'

// TODO(react-migration): port from VideoNodeView.vue
export default function VideoNodeView({ selected }: NodeViewProps) {
  return (
    <NodeViewWrapper
      className={`moodiary-media moodiary-media--video${selected ? ' is-selected' : ''}`}
      contentEditable={false}
    >
      <div className="moodiary-block__body" />
    </NodeViewWrapper>
  )
}
