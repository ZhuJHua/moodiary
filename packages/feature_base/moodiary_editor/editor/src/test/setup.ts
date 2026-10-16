// jsdom 无选区时 collapseToEnd 会抛
const collapseToEnd = Selection.prototype.collapseToEnd
Selection.prototype.collapseToEnd = function (this: Selection) {
  if (this.rangeCount > 0) collapseToEnd.call(this)
}

// jsdom 不实现媒体播放
HTMLMediaElement.prototype.pause = () => {}
