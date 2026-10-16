import { NodeViewWrapper, type NodeViewProps } from '@tiptap/react'
import { postImageTap } from '@/core/editor/commands'
import { useMediaSrc } from '@/ui/hooks/use-media-src'

export default function ImageNodeView({ node, selected, editor }: NodeViewProps) {
  const name = typeof node.attrs.src === 'string' ? node.attrs.src : null
  const src = useMediaSrc(name)
  const width = typeof node.attrs.widthPercent === 'number' ? node.attrs.widthPercent : null

  return (
    <NodeViewWrapper
      className={`md-block md-image${selected ? ' is-selected' : ''}`}
      style={width ? { width: `${width}%` } : undefined}
      data-block-node=""
      contentEditable={false}
    >
      <img
        className="md-block__body md-image__img"
        src={src}
        alt={(node.attrs.name as string | null) ?? ''}
        draggable={false}
        onClick={() => {
          if (!editor.isEditable && name) postImageTap(editor, name)
        }}
      />
    </NodeViewWrapper>
  )
}
