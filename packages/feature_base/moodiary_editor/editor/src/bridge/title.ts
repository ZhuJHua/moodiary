import { ref } from 'vue'

/** 日记标题：Flutter 经 bridge setTitle 推入初值，编辑器顶部标题区读写；用户改动经 titleChange 回传。
 *  标题不进正文文档（不污染 content JSON / contentText），单独映射到 Flutter 侧的 Diary.title。
 *  组件用「非受控 textarea」消费：程序化推入经 watch 同步进 DOM，用户输入只读 DOM 回传，避免中文
 *  输入法组合被受控回写打断（也避开 v-model 对「导入的 ref」写回不可靠的问题）。 */
export const title = ref('')

export function setTitle(value: string): void {
  title.value = value ?? ''
}

// 标题聚焦句柄：textarea 在组件内，挂载时注册，bridge.focusTitle 经此恢复标题焦点。
let focusHandler: (() => void) | null = null

export function registerTitleFocus(handler: (() => void) | null): void {
  focusHandler = handler
}

export function focusTitle(): void {
  focusHandler?.()
}
