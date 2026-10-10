import { Ellipsis } from 'lucide-react'
import { t } from '@/core/i18n'
import { keepFocus } from '@/lib/utils'

export default function BlockHandle({
  variant,
  onOpen,
}: {
  variant: 'corner' | 'inline'
  onOpen: (anchor: HTMLElement) => void
}) {
  return (
    <button
      type="button"
      className={`moodiary-block__handle moodiary-block__handle--${variant}`}
      title={t('block.more')}
      onMouseDown={keepFocus}
      onClick={(e) => {
        e.stopPropagation()
        onOpen(e.currentTarget)
      }}
    >
      <span className="moodiary-block__chip">
        <Ellipsis className="size-[18px]" />
      </span>
    </button>
  )
}
