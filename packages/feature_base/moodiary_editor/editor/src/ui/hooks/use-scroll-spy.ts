import { useCallback, useEffect, useRef, type RefObject } from 'react'
import type { Editor } from '@tiptap/core'
import { post } from '@/core/bridge/post'

const HEADINGS = '.ProseMirror h1, .ProseMirror h2, .ProseMirror h3, .ProseMirror h4, .ProseMirror h5, .ProseMirror h6'

export function useScrollSpy(editor: Editor, viewport: RefObject<HTMLElement | null>): () => void {
  const active = useRef(-1)
  const raf = useRef(0)

  const compute = useCallback((): void => {
    const vp = viewport.current
    if (!vp) return
    const vpTop = vp.getBoundingClientRect().top
    const heads = vp.querySelectorAll<HTMLElement>(HEADINGS)
    let index = heads.length > 0 ? 0 : -1
    heads.forEach((h, i) => {
      if (h.getBoundingClientRect().top - vpTop <= 12) index = i
    })
    if (index !== active.current) {
      active.current = index
      post('activeHeading', index)
    }
  }, [viewport])

  const schedule = useCallback((): void => {
    cancelAnimationFrame(raf.current)
    raf.current = requestAnimationFrame(compute)
  }, [compute])

  useEffect(() => {
    editor.on('transaction', schedule)
    return () => {
      editor.off('transaction', schedule)
      cancelAnimationFrame(raf.current)
    }
  }, [editor, schedule])

  return schedule
}
