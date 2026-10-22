import { useEffect, useRef } from 'react'
import DiaryLinkSuggestion from '@/ui/DiaryLinkSuggestion'
import EditorViewport from '@/ui/EditorViewport'
import { useDiaryEditor } from '@/ui/hooks/use-diary-editor'
import { useKeepCaretVisible } from '@/ui/hooks/use-keep-caret-visible'
import { interceptLinkClick } from '@/ui/link-intercept'

export default function EditorShell() {
  const shell = useRef<HTMLDivElement>(null)
  const editor = useDiaryEditor()
  useKeepCaretVisible(editor)

  useEffect(() => {
    const el = shell.current
    if (!el) return
    const onClick = (e: MouseEvent): void => interceptLinkClick(editor, e)
    el.addEventListener('click', onClick)
    return () => el.removeEventListener('click', onClick)
  }, [editor])

  return (
    <div ref={shell} className="md-shell">
      <EditorViewport editor={editor} />
      <DiaryLinkSuggestion />
    </div>
  )
}
