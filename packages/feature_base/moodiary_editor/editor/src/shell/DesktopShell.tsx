import { post } from '@/core/bridge/post'
import { editable as editableStore } from '@/core/state/editable'
import { useStore } from '@/lib/store'
import BlockMenu from '@/ui/block/BlockMenu'
import EditorSearchBar from '@/ui/EditorSearchBar'
import EditorViewport from '@/ui/EditorViewport'
import { useDiaryEditor } from '@/ui/hooks/use-diary-editor'
import UndoToast from '@/ui/overlay/UndoToast'
import EditorToolbar, { type PickType } from '@/ui/toolbar/EditorToolbar'

export default function DesktopShell() {
  const editor = useDiaryEditor()
  const editable = useStore(editableStore)

  return (
    <div className="moodiary-editor-root">
      {editable && (
        <EditorToolbar
          editor={editor}
          className="border-b border-border"
          onPick={(type: PickType) => post(type)}
        />
      )}
      <EditorSearchBar className="border-b border-border" />
      <EditorViewport editor={editor} />
      <UndoToast />
      {editable && <BlockMenu editor={editor} />}
    </div>
  )
}
