export { cn } from 'cn'

// 按钮按下不抢编辑器焦点
export const keepFocus = (e: { preventDefault(): void }): void => e.preventDefault()
