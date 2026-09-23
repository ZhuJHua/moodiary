import type { JSONContent, MarkdownToken, NodeConfig } from '@tiptap/core'
import { Markdown } from '@tiptap/markdown'
import { isAudio, isVideo } from './media'

export const MoodiaryMarkdown = Markdown.configure({
  markedOptions: { breaks: true },
})

const DIARY_LINK_SCHEME = 'moodiary://diary/'
const diaryLinkPattern = /^\[\[((?:\\.|[^\]\\\n])+)\]\]\(moodiary:\/\/diary\/([^)\s]+)\)/
const escapeLabel = (label: string): string => label.replace(/[\\[\]]/g, (c) => `\\${c}`)
const unescapeLabel = (label: string): string => label.replace(/\\(.)/g, '$1')

type MarkdownSpec = Pick<
  NodeConfig,
  'markdownTokenName' | 'markdownTokenizer' | 'parseMarkdown' | 'renderMarkdown'
>

export const diaryLinkMarkdownSpec: MarkdownSpec = {
  markdownTokenName: 'diaryLink',
  markdownTokenizer: {
    name: 'diaryLink',
    level: 'inline',
    start: (src) => src.indexOf('[['),
    tokenize: (src) => {
      const match = diaryLinkPattern.exec(src)
      if (!match) return undefined
      return { type: 'diaryLink', raw: match[0], label: unescapeLabel(match[1]), id: match[2] }
    },
  },
  parseMarkdown: (token: MarkdownToken) => ({
    type: 'diaryLink',
    attrs: { id: token.id ?? null, label: token.label ?? null },
  }),
  renderMarkdown: (node) => {
    const label = escapeLabel(String(node.attrs?.label ?? node.attrs?.id ?? ''))
    const id = node.attrs?.id
    return id ? `[[${label}]](${DIARY_LINK_SCHEME}${id})` : `[[${label}]]`
  },
}

export const mediaMarkdownSpec: Pick<NodeConfig, 'renderMarkdown'> = {
  renderMarkdown: (node: JSONContent) => `![](${String(node.attrs?.filename ?? '')})`,
}

export function mediaNodeFor(src: string): 'audio' | 'video' | 'image' {
  if (isAudio(src)) return 'audio'
  if (isVideo(src)) return 'video'
  return 'image'
}
