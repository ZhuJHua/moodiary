import { useEffect, useImperativeHandle, useRef, useState, type Ref } from 'react'
import Popover, { type PopoverHandle } from '../ui/Popover'
import WheelColumn, { type WheelColumnHandle } from '../ui/WheelColumn'
import { post } from '../../bridge/post'
import type { EditorMeta } from '../../bridge/meta'
import type { PickerHandle } from './picker'
import { useT } from '../../i18n'

const pad = (n: number): string => String(n).padStart(2, '0')
const minutes = Array.from({ length: 60 }, (_, i) => pad(i))

interface Hm {
  h: number
  m: number
}

export default function TimePicker({ ref, meta }: { ref?: Ref<PickerHandle>; meta: EditorMeta }) {
  const t = useT()
  const pop = useRef<PopoverHandle>(null)
  const period = useRef<WheelColumnHandle>(null)
  const hour = useRef<WheelColumnHandle>(null)
  const minute = useRef<WheelColumnHandle>(null)
  // 每次打开换一个新对象，让滚轮定位的 effect 在 popover 挂载后再跑
  const [pending, setPending] = useState<(Hm & { use24h: boolean }) | null>(null)

  const use24h = meta.use24h !== false
  const hours = use24h
    ? Array.from({ length: 24 }, (_, i) => pad(i))
    : Array.from({ length: 12 }, (_, i) => String(i === 0 ? 12 : i))
  const periods = [t('meta.am'), t('meta.pm')]

  function initial(): Hm {
    const match = meta.time ? /T(\d{2}):(\d{2})/.exec(meta.time) : null
    return match ? { h: Number(match[1]), m: Number(match[2]) } : { h: 0, m: 0 }
  }

  useEffect(() => {
    if (!pending) return
    const { h, m } = pending
    if (pending.use24h) {
      hour.current?.scrollTo(h)
    } else {
      period.current?.scrollTo(h >= 12 ? 1 : 0)
      hour.current?.scrollTo(h % 12)
    }
    minute.current?.scrollTo(m)
  }, [pending])

  useImperativeHandle(ref, () => ({
    open: (anchor) => {
      pop.current?.open(anchor)
      setPending({ ...initial(), use24h })
    },
  }))

  function confirm(): void {
    const h = hour.current?.current() ?? 0
    const m = minute.current?.current() ?? 0
    const value = use24h ? h : h + ((period.current?.current() ?? 0) === 1 ? 12 : 0)
    pop.current?.close()
    const before = initial()
    if (value !== before.h || m !== before.m) post('changeTime', { hour: value, minute: m })
  }

  return (
    <Popover ref={pop} panelClass="w-[264px]" label={t('meta.time')}>
      <div className="flex items-center justify-center gap-2 pt-1">
        {!use24h && (
          <WheelColumn ref={period} className="w-18" items={periods} label={t('meta.period')} />
        )}
        <WheelColumn ref={hour} className="w-18" items={hours} label={t('meta.hour')} />
        <span className="text-xl font-medium opacity-60">:</span>
        <WheelColumn ref={minute} className="w-18" items={minutes} label={t('meta.minute')} />
      </div>
      <div className="flex justify-end">
        <button
          type="button"
          className="moodiary-pop-item w-auto px-4 font-semibold text-primary"
          onClick={confirm}
        >
          {t('meta.confirm')}
        </button>
      </div>
    </Popover>
  )
}
