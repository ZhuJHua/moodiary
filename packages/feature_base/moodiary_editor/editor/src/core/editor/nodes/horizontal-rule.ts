import { Node, mergeAttributes, nodeInputRule } from '@tiptap/core'
import { HR_VARIANTS, type HorizontalRuleVariant } from '../normalize'

const variantOf = (value: unknown): HorizontalRuleVariant =>
  HR_VARIANTS.includes(value as HorizontalRuleVariant) ? (value as HorizontalRuleVariant) : 'solid'

export const HorizontalRuleNode = Node.create({
  name: 'horizontalRule',
  group: 'block',
  selectable: true,
  draggable: false,

  addAttributes() {
    return {
      variant: {
        default: 'solid',
        parseHTML: (el) => variantOf(el.getAttribute('data-variant')),
        renderHTML: (attrs) => ({ 'data-variant': variantOf(attrs.variant) }),
      },
      label: {
        default: null,
        parseHTML: (el) => el.getAttribute('data-label') || null,
        renderHTML: (attrs) => (attrs.label ? { 'data-label': attrs.label } : {}),
      },
    }
  },

  parseHTML() {
    return [{ tag: 'div[data-type="horizontalRule"]' }, { tag: 'hr' }]
  },

  renderHTML({ node, HTMLAttributes }) {
    const attrs = mergeAttributes(HTMLAttributes, {
      'data-type': 'horizontalRule',
      'data-block-node': '',
      class: 'md-hr',
    })
    if (variantOf(node.attrs.variant) === 'text') {
      return ['div', attrs, ['span', { class: 'md-hr__label' }, String(node.attrs.label ?? '')]]
    }
    return ['div', attrs, ['hr']]
  },

  markdownTokenName: 'hr',
  parseMarkdown: (_token, helpers) => helpers.createNode('horizontalRule', { variant: 'solid', label: null }),
  renderMarkdown: () => '---',

  addInputRules() {
    return [
      nodeInputRule({ find: /^(?:---|—-|___\s|\*\*\*\s)$/, type: this.type }),
      // 中文输入法 shift+- 一次出两个破折号，所以破折号不限三个
      nodeInputRule({ find: /^(?:—{3,}|－{3,})$/, type: this.type }),
    ]
  },
})
