let viewport: HTMLElement | null = null

export function bindScrollViewport(el: HTMLElement | null): void {
  viewport = el
}

export function scrollViewport(): HTMLElement | null {
  return viewport
}

export function getScrollY(): number {
  return viewport?.scrollTop ?? 0
}

export function setScrollY(y: number): void {
  if (viewport) viewport.scrollTop = y
}
