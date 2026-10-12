import { NodeViewWrapper, type NodeViewProps } from '@tiptap/react'
import BlockHandle from './BlockHandle'
import { useBlockMenu, widthPercentOf } from '@/ui/hooks/use-block-menu'
import { useMediaSrc } from '@/ui/hooks/use-media-src'

export default function ImageNodeView({ node, selected, getPos }: NodeViewProps) {
  const { canEdit, wrapperClass, widthStyle, openMenu } = useBlockMenu(
    'image',
    getPos,
    selected,
    widthPercentOf(node.attrs.widthPercent),
  )

  const raw = node.attrs.src
  const src = useMediaSrc(typeof raw === 'string' ? raw : null)
  const alt = (node.attrs.alt as string | null) ?? ''
  const title = (node.attrs.title as string | null) ?? undefined

  return (
    <NodeViewWrapper
      className={wrapperClass('moodiary-image')}
      style={widthStyle}
      contentEditable={false}
    >
      <img
        className="moodiary-image__img moodiary-block__body"
        src={src}
        alt={alt}
        title={title}
        draggable={false}
      />
      {canEdit && <BlockHandle variant="corner" onOpen={openMenu} />}
    </NodeViewWrapper>
  )
}
