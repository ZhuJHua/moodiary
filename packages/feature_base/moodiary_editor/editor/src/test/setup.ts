import { config } from '@vue/test-utils'
import { i18n } from '../i18n'

config.global.plugins = [i18n]

const zeroRect = {
  x: 0,
  y: 0,
  width: 0,
  height: 0,
  top: 0,
  left: 0,
  right: 0,
  bottom: 0,
  toJSON: () => ({}),
} as DOMRect

Range.prototype.getBoundingClientRect = () => zeroRect
Range.prototype.getClientRects = () =>
  ({ length: 0, item: () => null, *[Symbol.iterator]() {} }) as unknown as DOMRectList
document.elementFromPoint = () => null
Element.prototype.scrollIntoView = () => {}

// jsdom 无选区时 collapseToEnd 会抛
const selectionProto = window.Selection?.prototype
if (selectionProto) {
  const collapseToEnd = selectionProto.collapseToEnd
  selectionProto.collapseToEnd = function (this: Selection) {
    if (this.rangeCount > 0) collapseToEnd.call(this)
  }
}

// jsdom 没有 FontFace / document.fonts
class FontFaceStub {
  load(): Promise<this> {
    return Promise.resolve(this)
  }
}
Object.assign(globalThis, { FontFace: FontFaceStub })
Object.defineProperty(document, 'fonts', { value: { add: () => {} }, configurable: true })
