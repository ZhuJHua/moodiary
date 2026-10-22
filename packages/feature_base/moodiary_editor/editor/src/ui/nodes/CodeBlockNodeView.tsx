import { useEffect, useRef, useState } from 'react'
import { NodeViewContent, NodeViewWrapper, type NodeViewProps } from '@tiptap/react'
import { Check, Copy } from 'lucide-react'
import { post } from '@/core/bridge/post'
import { t } from '@/core/i18n'

export default function CodeBlockNodeView({ node }: NodeViewProps) {
  const language = (node.attrs.language as string | null) || t('code.plainText')

  const [copied, setCopied] = useState(false)
  const timer = useRef(0)
  useEffect(() => () => window.clearTimeout(timer.current), [])

  // 由 Flutter 统一处理 WebView 的剪贴板访问。
  function copy(): void {
    post('copy', { text: node.textContent })
    setCopied(true)
    window.clearTimeout(timer.current)
    timer.current = window.setTimeout(() => setCopied(false), 1500)
  }

  const Icon = copied ? Check : Copy
  return (
    <NodeViewWrapper className="md-code">
      <div className="md-code__head" contentEditable={false}>
        <span className="md-code__lang">{language}</span>
        <button type="button" className="md-code__copy" onMouseDown={(e) => e.preventDefault()} onClick={copy}>
          <Icon />
          <span>{copied ? t('code.copied') : t('code.copy')}</span>
        </button>
      </div>
      <pre>
        <NodeViewContent<'code'> as="code" />
      </pre>
    </NodeViewWrapper>
  )
}
