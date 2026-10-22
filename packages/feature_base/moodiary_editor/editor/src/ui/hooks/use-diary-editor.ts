import { useEffect, useState } from 'react'
import type { Editor } from '@tiptap/core'
import { useEditor } from '@tiptap/react'
import { bindApi, isReady, markReady } from '@/core/bridge'
import { createEditorKit } from '@/core/editor/kit'
import { t } from '@/core/i18n'
import { modeStore } from '@/core/state/editable'
import { nodeViews } from '@/ui/nodes'

export function useDiaryEditor(): Editor {
  const [kit] = useState(() =>
    createEditorKit({
      editable: modeStore.getState().editable,
      placeholder: t('content'),
      nodeViews,
      isPanelMode: () => modeStore.getState().panelMode,
      onChangeAllowed: isReady,
    }),
  )
  const editor = useEditor({ ...kit.options, immediatelyRender: true })

  useEffect(() => {
    kit.attach(editor)
    bindApi(kit.api)
    markReady()
  }, [editor, kit])

  return editor
}
