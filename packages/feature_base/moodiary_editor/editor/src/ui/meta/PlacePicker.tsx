import { useImperativeHandle, useRef, type Ref } from 'react'
import { LocateFixed, Plus, Settings, X } from 'lucide-react'
import Popover, { type PopoverHandle } from '@/ui/overlay/Popover'
import { post } from '@/core/bridge/post'
import type { EditorMeta } from '@/core/state/meta'
import { placeIcon } from './icons'
import type { PickerHandle } from './picker'
import { useT } from '@/core/i18n'

export default function PlacePicker({ ref, meta }: { ref?: Ref<PickerHandle>; meta: EditorMeta }) {
  const t = useT()
  const pop = useRef<PopoverHandle>(null)

  useImperativeHandle(
    ref,
    () => ({
      open: (anchor) => {
        pop.current?.open(anchor)
        post('locateForPlaces')
      },
    }),
    [],
  )

  function act(type: string, payload?: unknown): void {
    pop.current?.close()
    post(type, payload)
  }

  const hasPlaces = meta.places.length > 0

  return (
    <Popover ref={pop} panelClass="w-[236px]" label={t('meta.place')}>
      {meta.positionAutoLabel && (
        <button type="button" className="moodiary-pop-item" onClick={() => act('fetchPosition')}>
          <LocateFixed />
          {meta.positionAutoLabel}
        </button>
      )}
      {hasPlaces && (
        <>
          {meta.positionAutoLabel && <div className="moodiary-pop-divider"></div>}
          <div className="flex max-h-[200px] flex-col gap-0.5 overflow-y-auto overscroll-contain">
            {meta.places.map((place) => {
              const Icon = placeIcon(place.icon)
              return (
                <button
                  key={place.id}
                  type="button"
                  className={`moodiary-pop-item${place.id === meta.positionId ? ' is-active' : ''}`}
                  onClick={() => act('pickPlace', { id: place.id })}
                >
                  <Icon />
                  <span className="min-w-0 flex-1 truncate">{place.name}</span>
                  {place.distance && (
                    <span className="text-xs font-normal tabular-nums opacity-70">{place.distance}</span>
                  )}
                </button>
              )
            })}
          </div>
        </>
      )}
      {(meta.positionAutoLabel || hasPlaces) && <div className="moodiary-pop-divider"></div>}
      <button type="button" className="moodiary-pop-item" onClick={() => act('newPlace')}>
        <Plus />
        {meta.positionNewPlaceLabel}
      </button>
      <button type="button" className="moodiary-pop-item is-dim" onClick={() => act('managePlaces')}>
        <Settings />
        {meta.positionManageLabel}
      </button>
      {meta.position && (
        <button type="button" className="moodiary-pop-item is-dim" onClick={() => act('clearPosition')}>
          <X />
          {meta.positionClearLabel}
        </button>
      )}
    </Popover>
  )
}
