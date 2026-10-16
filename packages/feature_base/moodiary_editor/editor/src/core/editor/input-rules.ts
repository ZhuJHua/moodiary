import {
  Extension,
  markInputRule,
  textblockTypeInputRule,
  wrappingInputRule,
  type InputRule,
  type InputRuleFinder,
} from '@tiptap/core'

const escapeRe = (s: string): string => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')

// 不要求前面有空格（今天**很开心**），但前一个字是 ASCII 字母数字时不触发（2*3*）
export function relaxedDelimiter(delim: string): InputRuleFinder {
  const ch = delim[0]
  const pattern = new RegExp(`${escapeRe(delim)}([^${escapeRe(ch)}\\n]+?)${escapeRe(delim)}$`)
  return (text) => {
    const m = pattern.exec(text)
    if (!m || m.index === undefined) return null
    const inner = m[1]
    if (/^\s|\s$/.test(inner)) return null
    const before = text.charAt(m.index - 1)
    if (before && (before === ch || /[A-Za-z0-9_]/.test(before))) return null
    return { index: m.index, text: m[0], replaceWith: inner }
  }
}

const FULLWIDTH_DIGIT = /[０-９]/g
const toAsciiDigits = (s: string): string =>
  s.replace(FULLWIDTH_DIGIT, (d) => String.fromCharCode(d.charCodeAt(0) - 0xfee0))

export const CjkInputRules = Extension.create({
  name: 'cjkInputRules',

  addInputRules() {
    const { nodes, marks } = this.editor.schema
    const rules: InputRule[] = []

    if (nodes.heading) {
      rules.push(
        textblockTypeInputRule({
          find: /^(＃{1,6})\s$/,
          type: nodes.heading,
          getAttributes: (match) => ({ level: match[1].length }),
        }),
      )
    }
    if (nodes.blockquote) {
      rules.push(wrappingInputRule({ find: /^\s*[》＞]\s$/, type: nodes.blockquote }))
    }
    if (nodes.bulletList) {
      rules.push(wrappingInputRule({ find: /^\s*[－＊·•]\s$/, type: nodes.bulletList }))
    }
    if (nodes.orderedList) {
      rules.push(
        wrappingInputRule({
          find: /^([0-9０-９]+)[．.]\s$/,
          type: nodes.orderedList,
          getAttributes: (match) => ({ start: Number(toAsciiDigits(match[1])) }),
          joinPredicate: (match, node) =>
            node.childCount + node.attrs.start === Number(toAsciiDigits(match[1])),
        }),
      )
    }
    if (nodes.taskItem) {
      rules.push(
        wrappingInputRule({
          find: /^\s*(?:【\s?】|「」)\s$/,
          type: nodes.taskItem,
          getAttributes: () => ({ checked: false }),
        }),
      )
    }
    if (nodes.codeBlock) {
      rules.push(
        textblockTypeInputRule({
          find: /^···([a-z]+)?[\s\n]$/,
          type: nodes.codeBlock,
          getAttributes: (match) => ({ language: match[1] ?? null }),
        }),
      )
    }

    const relaxed: Array<[string, string]> = [
      ['**', 'bold'],
      ['~~', 'strike'],
      ['==', 'highlight'],
      ['*', 'italic'],
    ]
    for (const [delim, name] of relaxed) {
      const type = marks[name]
      if (type) rules.push(markInputRule({ find: relaxedDelimiter(delim), type }))
    }
    return rules
  },
})
