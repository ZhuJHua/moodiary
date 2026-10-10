import { useImperativeHandle, useRef, type Ref } from 'react'
import Popover, { type PopoverHandle } from '@/ui/overlay/Popover'
import { post } from '@/core/bridge/post'
import type { EditorMeta } from '@/core/state/meta'
import { moodIcon } from './icons'
import type { PickerHandle } from './picker'
import { t } from '@/core/i18n'

export default function MoodPicker({ ref, meta }: { ref?: Ref<PickerHandle>; meta: EditorMeta }) {
  const pop = useRef<PopoverHandle>(null)

  useImperativeHandle(ref, () => ({ open: (anchor) => pop.current?.open(anchor) }), [])

  function select(mood: string): void {
    pop.current?.close()
    post('changeMood', { mood })
  }

  return (
    <Popover ref={pop} panelClass="w-[276px]" label={t('meta.mood')}>
      <div className="grid grid-cols-4 gap-0.5">
        {meta.moods.map((m) => {
          const active = m.value === meta.mood
          const Icon = moodIcon(m.icon)
          return (
            <button
              key={m.value}
              type="button"
              className={`moodiary-pop-cell${active ? ' is-active' : ''}`}
              style={active ? { color: m.color, background: `${m.color}26` } : undefined}
              aria-pressed={active}
              onClick={() => select(m.value)}
            >
              <Icon />
              <span>{m.label}</span>
            </button>
          )
        })}
      </div>
    </Popover>
  )
}
