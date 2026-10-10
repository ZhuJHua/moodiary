import { useEffect, useRef } from 'react'
import type { Editor } from '@tiptap/core'
import { EditorContent, useEditorState } from '@tiptap/react'
import { bindScrollViewport } from '@/core/bridge/scroll'
import { wordCountOf } from '@/core/editor/word-count'
import { editable as editableStore } from '@/core/state/editable'
import { links as linksStore, meta as metaStore } from '@/core/state/meta'
import { useStore } from '@/lib/store'
import EditorLinksPanel from './EditorLinksPanel'
import EditorMetaHeader from './meta/EditorMetaHeader'
import TitleField from './TitleField'
import { useScrollSpy } from './hooks/use-scroll-spy'

export default function EditorViewport({ editor }: { editor: Editor }) {
  const editable = useStore(editableStore)
  const meta = useStore(metaStore)
  const links = useStore(linksStore)
  const viewport = useRef<HTMLDivElement>(null)
  const onScroll = useScrollSpy(editor, viewport)

  const wordCount = useEditorState({
    editor,
    selector: ({ editor: ed }) => (editable ? 0 : wordCountOf(ed.state.doc)),
  })

  useEffect(() => {
    bindScrollViewport(viewport.current)
    return () => bindScrollViewport(null)
  }, [])

  const showLinks =
    !editable && links != null && links.outgoing.length + links.incoming.length > 0

  return (
    <div className="moodiary-editor-scroll">
      <div ref={viewport} className="moodiary-editor-viewport" onScroll={onScroll}>
        {meta && <EditorMetaHeader meta={meta} editable={editable} wordCount={wordCount} />}
        <TitleField editor={editor} editable={editable} />
        <EditorContent editor={editor} className="moodiary-editor" />
        {showLinks && links && <EditorLinksPanel links={links} />}
      </div>
    </div>
  )
}
