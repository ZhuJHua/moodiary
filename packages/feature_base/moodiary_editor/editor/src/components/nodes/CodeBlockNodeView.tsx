import { useEffect, useRef, useState } from 'react'
import { NodeViewContent, NodeViewWrapper, type NodeViewProps } from '@tiptap/react'
import { Check, Copy } from 'lucide-react'
import { useT } from '../../i18n'

export default function CodeBlockNodeView({ node }: NodeViewProps) {
  const t = useT()
  const l = node.attrs.language as string | null
  const language = l && l.length ? l : t('code.plainText')

  const [copied, setCopied] = useState(false)
  const timer = useRef(0)
  useEffect(() => () => clearTimeout(timer.current), [])

  async function copy(): Promise<void> {
    const text = node.textContent
    try {
      await navigator.clipboard.writeText(text)
    } catch {
      const ta = document.createElement('textarea')
      ta.value = text
      ta.style.position = 'fixed'
      ta.style.opacity = '0'
      document.body.appendChild(ta)
      ta.select()
      try {
        document.execCommand('copy')
      } catch {
      }
      document.body.removeChild(ta)
    }
    setCopied(true)
    clearTimeout(timer.current)
    timer.current = window.setTimeout(() => setCopied(false), 1500)
  }

  const Icon = copied ? Check : Copy
  return (
    <NodeViewWrapper className="moodiary-code-block">
      <div className="moodiary-code-block__head" contentEditable={false}>
        <span className="moodiary-code-block__lang">{language}</span>
        <button
          className="moodiary-code-block__copy"
          type="button"
          title={copied ? t('code.copied') : t('code.copy')}
          onMouseDown={(e) => e.preventDefault()}
          onClick={() => void copy()}
        >
          <Icon className="size-4" />
          <span>{copied ? t('code.copied') : t('code.copy')}</span>
        </button>
      </div>
      <pre>
        <NodeViewContent<'code'> as="code" style={{ whiteSpace: 'pre' }} />
      </pre>
    </NodeViewWrapper>
  )
}
