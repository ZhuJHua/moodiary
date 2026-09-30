import { Ellipsis } from 'lucide-react'
import { useT } from '../../i18n'

export default function BlockHandle({
  variant,
  onOpen,
}: {
  variant: 'corner' | 'inline'
  onOpen: (anchor: HTMLElement) => void
}) {
  const t = useT()
  return (
    <button
      type="button"
      className={`moodiary-block__handle moodiary-block__handle--${variant}`}
      title={t('block.more')}
      onMouseDown={(e) => e.preventDefault()}
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
