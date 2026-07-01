import { ref } from 'vue'

/** 自动保存状态：'saving'（保存中）/ 'saved'（已保存）/ 'failed'（保存失败）/ 其它（'idle' 等，
 * 不显示气泡）。Flutter 经 bridge 的 setSaveStatus 推入，编辑器右下角气泡读取。 */
export const saveStatus = ref('idle')

export function setSaveStatus(status: string): void {
  saveStatus.value = status || 'idle'
}
