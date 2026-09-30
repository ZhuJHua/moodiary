import { createStore } from '../lib/store'

export const saveStatus = createStore('idle')

export function setSaveStatus(status: string): void {
  saveStatus.set(status || 'idle')
}
