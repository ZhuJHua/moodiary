import { ref } from 'vue'

export const editable = ref(true)

export function setEditableState(value: boolean): void {
  editable.value = value
}
