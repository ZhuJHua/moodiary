import { Loader2 } from 'lucide-react'
import { useStore } from 'zustand'
import { linkSuggestionStore, selectCandidate } from '@/core/editor/nodes/diary-link'
import { t } from '@/core/i18n'
import { useAnchoredFloating, type HeightRange } from './overlay/floating'

const HEIGHT: HeightRange = { min: 96, max: 280 }

export default function DiaryLinkSuggestion() {
  const s = useStore(linkSuggestionStore)
  const shown = s.open && s.reference !== null
  const { refs, floatingStyles, isPositioned } = useAnchoredFloating(shown ? s.reference : null, HEIGHT)

  if (!shown) return null

  let body
  if (s.loading && !s.items.length) {
    body = (
      <div className="md-suggest__hint">
        <Loader2 className="md-spin" />
        <span>{t('link.searching')}</span>
      </div>
    )
  } else if (!s.items.length) {
    body = <div className="md-suggest__hint">{s.query.trim() ? t('link.empty') : t('link.prompt')}</div>
  } else {
    body = s.items.map((it, i) => (
      <button
        key={it.id}
        type="button"
        className={`md-suggest__item${i === s.index ? ' is-active' : ''}`}
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
      ref={refs.setFloating}
      className="md-suggest"
      style={{ ...floatingStyles, visibility: isPositioned ? 'visible' : 'hidden' }}
      role="listbox"
    >
      {body}
    </div>
  )
}
