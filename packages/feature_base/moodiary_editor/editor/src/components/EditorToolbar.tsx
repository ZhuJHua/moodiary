import type { Editor } from '@tiptap/core'

export type PickType = 'pickImage' | 'pickVideo' | 'recordAudio' | 'pickAudioFile'

// TODO(react-migration): port from EditorToolbar.vue
export default function EditorToolbar(_props: {
  editor: Editor
  platform: 'mobile' | 'desktop'
  onPick: (type: PickType) => void
}) {
  return null
}
