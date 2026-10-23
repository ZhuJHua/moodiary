import { NodeViewWrapper, type NodeViewProps } from '@tiptap/react'
import { ArrowUpRight } from 'lucide-react'
import { postAttachmentTap } from '@/core/editor/commands'
import { fileExtension, formatFileSize } from '@/core/editor/media'
import { t } from '@/core/i18n'

export default function AttachmentNodeView({ node, selected, editor }: NodeViewProps) {
  const name = (node.attrs.name as string | null) || t('attachment.defaultName')
  const ext = fileExtension((node.attrs.src as string | null) ?? '').slice(0, 4)
  const size = formatFileSize(node.attrs.size as number | null)

  return (
    <NodeViewWrapper
      className={`md-block md-attachment${selected ? ' is-selected' : ''}`}
      data-block-node=""
      contentEditable={false}
    >
      <div
        className="md-block__body md-attachment__card"
        title={t('attachment.open')}
        onClick={() => {
          if (!editor.isEditable) postAttachmentTap(node)
        }}
      >
        <span className="md-attachment__tile">{ext ? ext.toUpperCase() : '?'}</span>
        <span className="md-attachment__text">
          <span className="md-attachment__name">{name}</span>
          {size && <span className="md-attachment__size">{size}</span>}
        </span>
        <ArrowUpRight className="md-attachment__open" aria-hidden="true" />
      </div>
    </NodeViewWrapper>
  )
}
