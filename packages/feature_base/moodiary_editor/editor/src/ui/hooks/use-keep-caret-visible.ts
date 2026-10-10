import { useEffect, type RefObject } from 'react'
import type { Editor } from '@tiptap/core'
import { NodeSelection } from '@tiptap/pm/state'

// 软键盘弹出压矮视口时，把被盖住的光标滚回可见区
export function useKeepCaretVisible(editor: Editor, viewport: RefObject<HTMLElement | null>): void {
  useEffect(() => {
    let bottom = viewport.current?.getBoundingClientRect().bottom ?? Infinity
    let raf = 0
    const onResize = (): void => {
      const box = viewport.current
      if (!box) return
      const bounds = box.getBoundingClientRect()
      const bottomBefore = bottom
      bottom = bounds.bottom
      if (!editor.isEditable || !editor.isFocused) return
      const { selection } = editor.state
      const caret = editor.view.coordsAtPos(
        selection instanceof NodeSelection ? selection.from : selection.head,
      )
      if (caret.bottom < bounds.top || caret.top > bottomBefore) return
      cancelAnimationFrame(raf)
      raf = requestAnimationFrame(() => editor.commands.scrollIntoView())
    }
    window.addEventListener('resize', onResize)
    return () => {
      window.removeEventListener('resize', onResize)
      cancelAnimationFrame(raf)
    }
  }, [editor, viewport])
}
