import { useImperativeHandle, useRef, type Ref } from 'react'
import { Check } from 'lucide-react'
import Popover, { type PopoverHandle } from '@/ui/overlay/Popover'
import { post } from '@/core/bridge/post'
import type { EditorMeta } from '@/core/state/meta'
import type { PickerHandle } from './picker'
import { t } from '@/core/i18n'

export default function CategoryPicker({ ref, meta }: { ref?: Ref<PickerHandle>; meta: EditorMeta }) {
  const pop = useRef<PopoverHandle>(null)

  useImperativeHandle(ref, () => ({ open: (anchor) => pop.current?.open(anchor) }), [])

  function select(id: string | null): void {
    pop.current?.close()
    if (id !== (meta.categoryId ?? null)) post('changeCategory', { id })
  }

  return (
    <Popover ref={pop} panelClass="w-[236px]" label={t('meta.category')}>
      <button
        type="button"
        className={`moodiary-pop-item${meta.categoryId ? '' : ' is-active'}`}
        onClick={() => select(null)}
      >
        <span className="flex-1">{t('meta.noCategory')}</span>
        {!meta.categoryId && <Check />}
      </button>
      <div className="flex max-h-[240px] flex-col gap-0.5 overflow-y-auto overscroll-contain">
        {(meta.categories ?? []).map((c) => {
          const active = c.id === meta.categoryId
          return (
            <button
              key={c.id}
              type="button"
              className={`moodiary-pop-item${active ? ' is-active' : ''}`}
              onClick={() => select(c.id)}
            >
              <span className="min-w-0 flex-1 truncate">{c.name}</span>
              {active && <Check />}
            </button>
          )
        })}
      </div>
    </Popover>
  )
}
