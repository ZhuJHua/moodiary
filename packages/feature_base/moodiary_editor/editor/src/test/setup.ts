// jsdom 无布局引擎：补齐 prosemirror-view 读坐标用的 Range API。
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
