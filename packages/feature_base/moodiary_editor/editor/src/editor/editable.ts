// 可编辑性的共享状态。node view 拿不到响应式的 editor.isEditable（切阅读↔编辑不发 transaction），
// 故由 kit 显式推入：createEditorKit 用初始值初始化，api.setEditable 后续写入。
// 初始化不能省 —— 默认 true 会让只读浏览态误显编辑控件。
import { ref } from 'vue'

export const editable = ref(true)

export function setEditableState(value: boolean): void {
  editable.value = value
}
