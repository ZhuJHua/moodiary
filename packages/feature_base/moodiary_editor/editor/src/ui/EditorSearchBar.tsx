import { useEffect, useRef, useState, type KeyboardEvent } from 'react'
import { ChevronDown, ChevronUp, X } from 'lucide-react'
import { cn } from 'cn'
import { closeOverlay, openOverlay, type Overlay } from '@/core/state/overlay'
import {
  closeSearch,
  editorSearch,
  nextMatch,
  prevMatch,
  replaceAllMatches,
  replaceOne,
  setReplace,
  setTerm,
  toggleCase,
} from '@/core/editor/search'
import { t } from '@/core/i18n'
import { useStore } from '@/lib/store'
import { Button } from '@/ui/primitives/button'
import { Input } from '@/ui/primitives/input'
import { keepFocus } from '@/lib/utils'

export default function EditorSearchBar({ className }: { className?: string }) {
  const s = useStore(editorSearch)
  const findInput = useRef<HTMLInputElement>(null)
  const [overlay] = useState<Overlay>(() => ({ dismiss: () => closeSearch() }))

  useEffect(() => {
    if (!s.open) return
    openOverlay(overlay)
    findInput.current?.focus()
    findInput.current?.select()
    return () => closeOverlay(overlay)
  }, [s.open, overlay])

  function onFindKey(e: KeyboardEvent<HTMLInputElement>): void {
    if (e.key === 'Enter') {
      e.preventDefault()
      if (e.shiftKey) prevMatch()
      else nextMatch()
    } else if (e.key === 'Escape') {
      e.preventDefault()
      closeSearch()
    }
  }

  if (!s.open) return null
  return (
    <div
      className={cn('moodiary-search flex-none bg-background px-2 py-1.5', className)}
    >
      <div className="grid grid-cols-[1fr_auto] items-center gap-x-1.5 gap-y-1">
        <Input
          ref={findInput}
          value={s.term}
          type="text"
          placeholder={t('search.findPlaceholder')}
          className="h-7 rounded-md text-xs md:text-xs"
          onChange={(e) => setTerm(e.target.value)}
          onKeyDown={onFindKey}
        />
        <div className="flex items-center gap-0.5">
          <span className="min-w-[2.5rem] px-0.5 text-right text-xs text-muted-foreground tabular-nums">
            {s.term ? `${s.current}/${s.count}` : ''}
          </span>
          <Button
            variant="ghost"
            size="icon-xs"
            className={cn('rounded-md', s.caseSensitive && 'bg-accent text-primary')}
            title={t('search.matchCase')}
            onMouseDown={keepFocus}
            onClick={toggleCase}
          >
            <span className="text-[11px] font-bold">Aa</span>
          </Button>
          <Button
            variant="ghost"
            size="icon-xs"
            className="rounded-md"
            title={t('search.previous')}
            onMouseDown={keepFocus}
            onClick={prevMatch}
          >
            <ChevronUp className="size-4" />
          </Button>
          <Button
            variant="ghost"
            size="icon-xs"
            className="rounded-md"
            title={t('search.next')}
            onMouseDown={keepFocus}
            onClick={nextMatch}
          >
            <ChevronDown className="size-4" />
          </Button>
          <Button
            variant="ghost"
            size="icon-xs"
            className="rounded-md"
            title={t('search.close')}
            onMouseDown={keepFocus}
            onClick={closeSearch}
          >
            <X className="size-4" />
          </Button>
        </div>

        <Input
          value={s.replace}
          type="text"
          placeholder={t('search.replacePlaceholder')}
          className="h-7 rounded-md text-xs md:text-xs"
          onChange={(e) => setReplace(e.target.value)}
        />
        <div className="flex items-center justify-end gap-0.5">
          <Button variant="ghost" size="xs" className="rounded-md" onMouseDown={keepFocus} onClick={replaceOne}>
            {t('search.replace')}
          </Button>
          <Button variant="ghost" size="xs" className="rounded-md" onMouseDown={keepFocus} onClick={replaceAllMatches}>
            {t('search.replaceAll')}
          </Button>
        </div>
      </div>
    </div>
  )
}
