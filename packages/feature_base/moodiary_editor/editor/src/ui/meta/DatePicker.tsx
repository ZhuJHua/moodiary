import { useEffect, useImperativeHandle, useRef, useState, type Ref } from 'react'
import { ChevronDown, ChevronLeft, ChevronRight } from 'lucide-react'
import Popover, { type PopoverHandle } from '@/ui/overlay/Popover'
import { post } from '@/core/bridge/post'
import type { EditorMeta } from '@/core/state/meta'
import type { PickerHandle } from './picker'
import { dateLocale, t } from '@/core/i18n'

interface Ymd {
  y: number
  m: number
  d: number
}

const parse = (iso: string | undefined): Ymd | null => {
  const m = iso ? /^(\d{4})-(\d{2})-(\d{2})/.exec(iso) : null
  return m ? { y: Number(m[1]), m: Number(m[2]) - 1, d: Number(m[3]) } : null
}
const key = (v: Ymd): number => v.y * 10000 + v.m * 100 + v.d
const monthKey = (y: number, m: number): number => y * 12 + m
const splitMonthKey = (k: number): { y: number; m: number } => ({ y: Math.floor(k / 12), m: k % 12 })

export default function DatePicker({ ref, meta }: { ref?: Ref<PickerHandle>; meta: EditorMeta }) {
  const pop = useRef<PopoverHandle>(null)
  const yearList = useRef<HTMLDivElement>(null)
  const [mode, setMode] = useState<'day' | 'year'>('day')
  const [view, setView] = useState({ y: 2000, m: 0 })
  const [today, setToday] = useState<Ymd>({ y: 2000, m: 0, d: 1 })

  const selected = parse(meta.time)
  const minDate: Ymd = parse(meta.minDate) ?? { y: 1949, m: 9, d: 1 }
  const first = meta.firstDayOfWeek ?? 0

  const clamp = (y: number, m: number, limit: Ymd): { y: number; m: number } =>
    splitMonthKey(
      Math.min(
        Math.max(monthKey(y, m), monthKey(minDate.y, minDate.m)),
        monthKey(limit.y, limit.m),
      ),
    )

  const monthTitle = new Intl.DateTimeFormat(dateLocale(), { year: 'numeric', month: 'long' }).format(
    new Date(view.y, view.m, 1),
  )

  const weekdayFmt = new Intl.DateTimeFormat(dateLocale(), { weekday: 'narrow' })
  const weekdays = Array.from({ length: 7 }, (_, i) =>
    weekdayFmt.format(new Date(2024, 0, 7 + ((first + i) % 7))),
  )

  const lead = (new Date(view.y, view.m, 1).getDay() - first + 7) % 7
  const days = new Date(view.y, view.m + 1, 0).getDate()
  const cells: Array<Ymd | null> = Array.from({ length: lead }, () => null)
  for (let d = 1; d <= days; d++) cells.push({ y: view.y, m: view.m, d })

  const years: number[] = []
  for (let y = minDate.y; y <= today.y; y++) years.push(y)

  const canPrev = monthKey(view.y, view.m) > monthKey(minDate.y, minDate.m)
  const canNext = monthKey(view.y, view.m) < monthKey(today.y, today.m)

  const disabled = (v: Ymd): boolean => key(v) < key(minDate) || key(v) > key(today)
  const isSelected = (v: Ymd): boolean => !!selected && key(v) === key(selected)
  const isToday = (v: Ymd): boolean => key(v) === key(today)

  function shiftMonth(delta: number): void {
    setView(splitMonthKey(monthKey(view.y, view.m) + delta))
  }

  useEffect(() => {
    if (mode !== 'year') return
    yearList.current
      ?.querySelector<HTMLElement>('[aria-current="true"]')
      ?.scrollIntoView({ block: 'center' })
  }, [mode])

  function pickYear(y: number): void {
    setView(clamp(y, view.m, today))
    setMode('day')
  }

  function pick(v: Ymd): void {
    pop.current?.close()
    if (!isSelected(v)) post('changeDate', { year: v.y, month: v.m + 1, day: v.d })
  }

  useImperativeHandle(ref, () => ({
    open: (anchor) => {
      const now = new Date()
      const nowYmd = { y: now.getFullYear(), m: now.getMonth(), d: now.getDate() }
      const start = selected ?? nowYmd
      setToday(nowYmd)
      setView(clamp(start.y, start.m, nowYmd))
      setMode('day')
      pop.current?.open(anchor)
    },
  }))

  return (
    <Popover ref={pop} panelClass="w-[300px]" label={t('meta.date')}>
      <div className="flex items-center justify-between">
        <button
          type="button"
          className="moodiary-pop-item w-auto gap-1 px-2.5 font-semibold"
          onClick={() => setMode(mode === 'day' ? 'year' : 'day')}
        >
          {monthTitle}
          <ChevronDown
            className={`size-4 opacity-70 transition-transform${mode === 'year' ? ' rotate-180' : ''}`}
          />
        </button>
        {mode === 'day' && (
          <div className="flex gap-0.5 pr-1">
            <button
              type="button"
              className="moodiary-pop-icon"
              disabled={!canPrev}
              aria-label={t('meta.prevMonth')}
              onClick={() => shiftMonth(-1)}
            >
              <ChevronLeft />
            </button>
            <button
              type="button"
              className="moodiary-pop-icon"
              disabled={!canNext}
              aria-label={t('meta.nextMonth')}
              onClick={() => shiftMonth(1)}
            >
              <ChevronRight />
            </button>
          </div>
        )}
      </div>

      {mode === 'day' ? (
        <div className="grid grid-cols-7 gap-y-0.5 px-1 pb-1 text-center text-sm">
          {weekdays.map((w, i) => (
            <span key={`w-${i}`} className="py-1 text-xs opacity-60">
              {w}
            </span>
          ))}
          {cells.map((c, i) =>
            c ? (
              <button
                key={`c-${i}`}
                type="button"
                className={`moodiary-pop-icon mx-auto size-9 tabular-nums${isSelected(c) ? ' is-active' : ''}${isToday(c) ? ' is-today' : ''}`}
                disabled={disabled(c)}
                aria-pressed={isSelected(c)}
                onClick={() => pick(c)}
              >
                {c.d}
              </button>
            ) : (
              <span key={`c-${i}`}></span>
            ),
          )}
        </div>
      ) : (
        <div
          ref={yearList}
          className="grid max-h-64 grid-cols-4 gap-0.5 overflow-y-auto overscroll-contain"
        >
          {years.map((y) => (
            <button
              key={y}
              type="button"
              className={`moodiary-pop-item justify-center px-0 tabular-nums${y === view.y ? ' is-active' : ''}`}
              aria-current={y === view.y}
              onClick={() => pickYear(y)}
            >
              {y}
            </button>
          ))}
        </div>
      )}
    </Popover>
  )
}
