import { ref } from 'vue'

export const saveStatus = ref('idle')

export function setSaveStatus(status: string): void {
  saveStatus.value = status || 'idle'
}
