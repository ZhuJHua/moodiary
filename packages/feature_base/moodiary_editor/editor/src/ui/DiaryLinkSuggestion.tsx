import { useCallback, useEffect, useLayoutEffect, useRef, useState, type CSSProperties } from 'react'
import { Loader2 } from 'lucide-react'
import { cn } from 'cn'
import { dismissSuggestion, linkSuggestion, selectCandidate } from '@/core/editor/diary-link'
import { closeOverlay, openOverlay, type Overlay } from '@/core/state/overlay'
import { useT } from '@/core/i18n'
import { useStore } from '@/lib/store'

const MARGIN = 8
const GAP = 4
const HARD_MAX = 320

interface Pos {
  left: number
  top: number | null
  bottom: number | null
  maxH: number
  ready: boolean
}

const overlay: Overlay = { dismiss: dismissSuggestion }

export default function DiaryLinkSuggestion() {
  const t = useT()
  const s = useStore(linkSuggestion)
  const box = useRef<HTMLDivElement>(null)
  const [pos, setPos] = useState<Pos>({ left: 0, top: 0, bottom: null, maxH: 240, ready: false })

  const place = useCallback((): void => {
    const r = linkSuggestion.get().rect
    const el = box.current
    if (!r || !el) return
    const vw = window.innerWidth
    const vh = window.innerHeight
    const w = el.offsetWidth
    const h = el.offsetHeight

    let left = r.left
    if (left + w > vw - MARGIN) left = vw - w - MARGIN
    if (left < MARGIN) left = MARGIN

    const belowSpace = vh - r.bottom - GAP - MARGIN
    const aboveSpace = r.top - GAP - MARGIN

    const next: Pos = { left: Math.round(left), top: null, bottom: null, maxH: 240, ready: true }
    if (h <= belowSpace || belowSpace >= aboveSpace) {
      next.top = Math.round(r.bottom + GAP)
      next.maxH = Math.max(120, Math.min(HARD_MAX, belowSpace))
    } else {
      next.bottom = Math.round(vh - (r.top - GAP))
      next.maxH = Math.max(120, Math.min(HARD_MAX, aboveSpace))
    }
    setPos(next)
  }, [])

  const shown = s.open && s.rect !== null

  useLayoutEffect(() => {
    if (!shown) {
      setPos((p) => (p.ready ? { ...p, ready: false } : p))
      return
    }
    place()
  }, [shown, s.rect?.left, s.rect?.top, s.rect?.bottom, s.items.length, s.loading, s.query, place])

  useEffect(() => {
    if (!s.open) return
    openOverlay(overlay)
    return () => closeOverlay(overlay)
  }, [s.open])

  useEffect(() => {
    const onWin = (): void => {
      if (linkSuggestion.get().open) place()
    }
    window.addEventListener('resize', onWin)
    window.addEventListener('scroll', onWin, true)
    return () => {
      window.removeEventListener('resize', onWin)
      window.removeEventListener('scroll', onWin, true)
    }
  }, [place])

  if (!shown) return null

  const style: CSSProperties = {
    left: `${pos.left}px`,
    top: pos.top != null ? `${pos.top}px` : 'auto',
    bottom: pos.bottom != null ? `${pos.bottom}px` : 'auto',
    maxHeight: `${pos.maxH}px`,
    width: 'min(18rem, calc(100vw - 1rem))',
    visibility: pos.ready ? 'visible' : 'hidden',
  }

  let body
  if (s.loading) {
    body = (
      <div className="flex items-center gap-2 px-2 py-2 text-sm text-muted-foreground">
        <Loader2 className="size-3.5 animate-spin" />
        <span>{t('link.searching')}</span>
      </div>
    )
  } else if (!s.query.trim()) {
    body = <div className="px-2 py-2 text-sm text-muted-foreground">{t('link.prompt')}</div>
  } else if (!s.items.length) {
    body = <div className="px-2 py-2 text-sm text-muted-foreground">{t('link.empty')}</div>
  } else {
    body = s.items.map((it, i) => (
      <button
        key={it.id}
        type="button"
        className={cn(
          'block w-full truncate rounded-md px-2 py-1.5 text-left text-sm',
          i === s.index ? 'bg-primary text-primary-foreground' : 'hover:bg-muted',
        )}
        onMouseDown={(e) => {
          e.preventDefault()
          selectCandidate(it)
        }}
      >
        {it.label}
      </button>
    ))
  }

  return (
    <div
      ref={box}
      className="fixed z-[70] overflow-y-auto rounded-lg border border-border bg-popover p-1 text-popover-foreground shadow-lg"
      style={style}
    >
      {body}
    </div>
  )
}
