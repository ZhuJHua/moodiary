import { useRef, useState } from 'react'
import { MIN_WIDTH_PERCENT, WIDTH_PERCENT_STOPS, snapWidthPercent } from '../../editor/media-size'
import { useT } from '../../i18n'
import { cn } from 'cn'
import { rangeClass } from '../../lib/range'

export default function WidthControl({
  value,
  onPreview,
  onCommit,
}: {
  value: number | null
  onPreview: (value: number | null) => void
  onCommit: (value: number | null) => void
}) {
  const t = useT()
  const [draft, setDraftState] = useState<number | null>(null)
  const draftRef = useRef<number | null>(null)

  const shown = draft ?? value
  const readout = shown === null ? t('mediaSize.defaultWidth') : `${shown}%`
  const fraction = (v: number): string =>
    `${((v - MIN_WIDTH_PERCENT) / (100 - MIN_WIDTH_PERCENT)) * 100}%`

  function setDraft(next: number | null): void {
    draftRef.current = next
    setDraftState(next)
    onPreview(next)
  }
  function commit(next: number | null): void {
    setDraft(null)
    onCommit(next)
  }
  // 拖动中松手在 range 外时个别 WebView 不发 change，按指针抬起提交
  function onPointerUp(): void {
    if (draftRef.current !== null) commit(draftRef.current)
  }

  return (
    <div className="flex flex-col px-1 pt-1">
      <div className="flex items-baseline justify-between px-2.5">
        <span className="text-xs text-muted-foreground">{t('mediaSize.width')}</span>
        <span className="text-sm font-medium tabular-nums">{readout}</span>
      </div>

      <input
        className={cn(rangeClass, 'mx-2.5 my-2 w-auto')}
        type="range"
        min={MIN_WIDTH_PERCENT}
        max={100}
        step={1}
        value={shown ?? 100}
        tabIndex={-1}
        aria-label={t('mediaSize.width')}
        onMouseDown={(e) => e.preventDefault()}
        onChange={(e) => setDraft(snapWidthPercent(Number(e.currentTarget.value)))}
        onPointerUp={onPointerUp}
        onPointerCancel={onPointerUp}
      />

      <div className="moodiary-width__stops">
        {WIDTH_PERCENT_STOPS.map((stop) => (
          <button
            key={stop}
            type="button"
            className={`moodiary-width__stop${shown === stop ? ' is-active' : ''}`}
            style={{ left: fraction(stop) }}
            onClick={() => commit(stop)}
          >
            {stop}
          </button>
        ))}
      </div>

      <button
        type="button"
        className="moodiary-pop-item is-dim mt-0.5 justify-center"
        disabled={value === null && draft === null}
        onClick={() => commit(null)}
      >
        {t('mediaSize.reset')}
      </button>
    </div>
  )
}
