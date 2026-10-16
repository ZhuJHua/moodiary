import type { EditorNodeViews } from '@/core/editor/kit'
import AttachmentNodeView from './AttachmentNodeView'
import AudioNodeView from './AudioNodeView'
import CodeBlockNodeView from './CodeBlockNodeView'
import ImageNodeView from './ImageNodeView'
import VideoNodeView from './VideoNodeView'

export const nodeViews: EditorNodeViews = {
  codeBlock: CodeBlockNodeView,
  image: ImageNodeView,
  audio: AudioNodeView,
  video: VideoNodeView,
  attachment: AttachmentNodeView,
}
