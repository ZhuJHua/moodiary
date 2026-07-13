// 滚动视口存取：页内双链跳转（同一 webview 换日记）时由 Flutter 保存 / 恢复滚动位置。
// 视口元素（.moodiary-editor-viewport）由 MoodiaryEditor.vue 挂载时注册。

let viewport: HTMLElement | null = null

export function bindScrollViewport(el: HTMLElement | null): void {
  viewport = el
}

export function getScrollY(): number {
  return viewport?.scrollTop ?? 0
}

export function setScrollY(y: number): void {
  if (viewport) viewport.scrollTop = y
}
