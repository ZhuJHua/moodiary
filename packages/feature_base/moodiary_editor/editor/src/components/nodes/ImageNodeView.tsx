import { useState } from 'react'
import { NodeViewWrapper, type NodeViewProps } from '@tiptap/react'
import BlockHandle from './BlockHandle'
import { blockMenu, openBlockMenu } from '../../editor/block-menu'
import { editable } from '../../editor/editable'
import { displaySrc } from '../../editor/media'
import { useStore } from '../../lib/store'

export default function ImageNodeView({ node, selected, getPos }: NodeViewProps) {
  const [owner] = useState(() => Symbol('image'))
  const menu = useStore(blockMenu)
  const canEdit = useStore(editable)
  const menuOpen = menu.owner === owner

  const raw = node.attrs.src
  const src = typeof raw === 'string' ? displaySrc(raw) : ''
  const alt = (node.attrs.alt as string | null) ?? ''
  const title = (node.attrs.title as string | null) ?? undefined
  const v = node.attrs.widthPercent
  const widthPercent = typeof v === 'number' ? v : null
  const shown = menuOpen && menu.previewWidth !== null ? menu.previewWidth : widthPercent

  return (
    <NodeViewWrapper
      className={`moodiary-image${selected ? ' is-selected' : ''}${menuOpen ? ' is-menu-open' : ''}`}
      style={shown === null ? undefined : { maxWidth: `${shown}%` }}
      contentEditable={false}
    >
      <img
        className="moodiary-image__img moodiary-block__body"
        src={src}
        alt={alt}
        title={title}
        draggable={false}
      />
      {canEdit && (
        <BlockHandle
          variant="corner"
          onOpen={(anchor) => openBlockMenu({ owner, kind: 'image', anchor, getPos: () => getPos() })}
        />
      )}
    </NodeViewWrapper>
  )
}
