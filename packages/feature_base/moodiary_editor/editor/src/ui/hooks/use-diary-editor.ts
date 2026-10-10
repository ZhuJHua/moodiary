import { useEffect, useState } from 'react'
import type { Editor } from '@tiptap/core'
import { useEditor } from '@tiptap/react'
import { bindApi, emitChange, markReady } from '@/core/bridge'
import { createEditorKit } from '@/core/editor/tiptap'
import { t } from '@/core/i18n'
import { editable } from '@/core/state/editable'
import { nodeViews } from '@/ui/nodes'

// 建编辑器、挂 api、报 ready；两个壳共用
export function useDiaryEditor(): Editor {
  const [kit] = useState(() =>
    createEditorKit({
      editable: editable.get(),
      placeholder: t('content'),
      nodeViews,
      onChange: emitChange,
    }),
  )
  const [options] = useState(() => Object.assign(kit.options, { immediatelyRender: true as const }))
  const editor = useEditor(options)

  useEffect(() => {
    kit.attach(editor)
    bindApi(kit.api)
    markReady()
  }, [editor, kit])

  return editor
}
