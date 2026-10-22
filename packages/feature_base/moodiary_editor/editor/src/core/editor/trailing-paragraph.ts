import { Extension } from '@tiptap/core'
import { Plugin, PluginKey } from '@tiptap/pm/state'

export const TrailingParagraph = Extension.create({
  name: 'trailingParagraph',

  addProseMirrorPlugins() {
    return [
      new Plugin({
        key: new PluginKey('trailingParagraph'),
        appendTransaction: (transactions, _old, state) => {
          if (!transactions.some((tr) => tr.docChanged)) return null
          // 输入规则转换的那次事务不补，否则 Backspace 撤销转换会失效
          if (transactions.some((tr) => tr.getMeta('inputRule'))) return null
          const last = state.doc.lastChild
          if (!last || last.type.name === 'paragraph') return null
          return state.tr.insert(state.doc.content.size, state.schema.nodes.paragraph.create())
        },
      }),
    ]
  },
})
