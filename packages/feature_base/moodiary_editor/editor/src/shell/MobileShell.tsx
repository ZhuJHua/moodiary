import { post } from '@/core/bridge/post'
import { dismissKeyboard } from '@/core/editor/keyboard'
import { editable as editableStore } from '@/core/state/editable'
import { useStore } from '@/lib/store'
import BlockMenu from '@/ui/block/BlockMenu'
import EditorSearchBar from '@/ui/EditorSearchBar'
import EditorViewport from '@/ui/EditorViewport'
import { useDiaryEditor } from '@/ui/hooks/use-diary-editor'
import { useKeepCaretVisible } from '@/ui/hooks/use-keep-caret-visible'
import UndoToast from '@/ui/overlay/UndoToast'
import EditorToolbar, { type PickType } from '@/ui/toolbar/EditorToolbar'

export default function MobileShell() {
  const editor = useDiaryEditor()
  const editable = useStore(editableStore)
  useKeepCaretVisible(editor)

  const pick = (type: PickType): void => {
    dismissKeyboard()
    post(type)
  }

  return (
    <div className="moodiary-editor-root">
      <EditorViewport editor={editor} />
      <EditorSearchBar className="border-t border-border" />
      <UndoToast />
      {editable && (
        <EditorToolbar editor={editor} dense className="border-t border-border" onPick={pick} />
      )}
      {editable && <BlockMenu editor={editor} />}
    </div>
  )
}
