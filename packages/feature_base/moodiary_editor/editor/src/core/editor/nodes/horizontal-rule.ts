import { mergeAttributes, nodeInputRule } from '@tiptap/core'
import HorizontalRule from '@tiptap/extension-horizontal-rule'
import { HR_VARIANTS, type HorizontalRuleVariant } from '../normalize'

const variantOf = (value: unknown): HorizontalRuleVariant =>
  HR_VARIANTS.includes(value as HorizontalRuleVariant) ? (value as HorizontalRuleVariant) : 'solid'

export const HorizontalRuleNode = HorizontalRule.extend({
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
    return [{ tag: 'div[data-type="horizontalRule"]' }, ...(this.parent?.() ?? [])]
  },

  renderHTML({ node, HTMLAttributes }) {
    const attrs = mergeAttributes(this.options.HTMLAttributes, HTMLAttributes, {
      'data-type': 'horizontalRule',
      'data-block-node': '',
      class: 'md-hr',
    })
    if (variantOf(node.attrs.variant) === 'text') {
      return ['div', attrs, ['span', { class: 'md-hr__label' }, String(node.attrs.label ?? '')]]
    }
    return ['div', attrs, ['hr']]
  },

  addInputRules() {
    return [
      ...(this.parent?.() ?? []),
      nodeInputRule({ find: /^(?:—{3,}|－{3,})$/, type: this.type }),
    ]
  },
})
