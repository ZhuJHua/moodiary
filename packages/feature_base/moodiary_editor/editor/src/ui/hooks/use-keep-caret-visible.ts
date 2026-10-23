import { useEffect } from 'react'
import type { Editor } from '@tiptap/core'

// iOS WebKit 在 WebView 变矮（键盘、Flutter 面板）时不再自己把光标滚进视口
export function useKeepCaretVisible(editor: Editor): void {
  useEffect(() => {
    let frame = 0
    const onResize = (): void => {
      cancelAnimationFrame(frame)
      frame = requestAnimationFrame(() => {
        if (editor.isDestroyed || !editor.isEditable || !editor.isFocused) return
        editor.commands.scrollIntoView()
      })
    }
    const vv = window.visualViewport
    window.addEventListener('resize', onResize)
    vv?.addEventListener('resize', onResize)
    return () => {
      window.removeEventListener('resize', onResize)
      vv?.removeEventListener('resize', onResize)
      cancelAnimationFrame(frame)
    }
  }, [editor])
}
