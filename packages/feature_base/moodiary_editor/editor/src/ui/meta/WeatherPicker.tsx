import { useImperativeHandle, useRef, type Ref } from 'react'
import { RefreshCw, X } from 'lucide-react'
import Popover, { type PopoverHandle } from '@/ui/overlay/Popover'
import { post } from '@/core/bridge/post'
import type { EditorMeta } from '@/core/state/meta'
import { weatherGlyph } from './icons'
import type { PickerHandle } from './picker'
import { useT } from '@/core/i18n'

export default function WeatherPicker({ ref, meta }: { ref?: Ref<PickerHandle>; meta: EditorMeta }) {
  const t = useT()
  const pop = useRef<PopoverHandle>(null)

  useImperativeHandle(ref, () => ({ open: (anchor) => pop.current?.open(anchor) }), [])

  function act(type: string, payload?: unknown): void {
    pop.current?.close()
    post(type, payload)
  }

  return (
    <Popover ref={pop} panelClass="w-[276px]" label={t('meta.weather')}>
      <div className="grid grid-cols-4 gap-0.5">
        {meta.weatherOptions.map((w) => {
          const active = w.code === meta.weather?.icon
          return (
            <button
              key={w.code}
              type="button"
              className={`moodiary-pop-cell${active ? ' is-active' : ''}`}
              aria-pressed={active}
              onClick={() => act('changeWeather', { code: w.code })}
            >
              <span className="moodiary-qi">{weatherGlyph(w.code)}</span>
              <span>{w.label}</span>
            </button>
          )
        })}
      </div>
      {(meta.weatherAutoLabel || meta.weather) && (
        <>
          <div className="moodiary-pop-divider"></div>
          {meta.weatherAutoLabel && (
            <button type="button" className="moodiary-pop-item" onClick={() => act('fetchWeather')}>
              <RefreshCw />
              {meta.weatherAutoLabel}
            </button>
          )}
          {meta.weather && (
            <button type="button" className="moodiary-pop-item is-dim" onClick={() => act('clearWeather')}>
              <X />
              {meta.weatherClearLabel}
            </button>
          )}
        </>
      )}
    </Popover>
  )
}
