import { useEffect } from 'react'
import { openSearch } from '@/core/editor/search'
import { editable } from '@/core/state/editable'

export function useFindShortcut(): void {
  useEffect(() => {
    const onKeydown = (e: KeyboardEvent): void => {
      if (!(e.metaKey || e.ctrlKey) || (e.key !== 'f' && e.key !== 'F')) return
      if (!editable.get()) return
      e.preventDefault()
      openSearch()
    }
    window.addEventListener('keydown', onKeydown)
    return () => window.removeEventListener('keydown', onKeydown)
  }, [])
}
