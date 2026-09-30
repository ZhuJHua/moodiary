import { createStore } from '../lib/store'

export const editable = createStore(true)

export function setEditableState(value: boolean): void {
  editable.set(value)
}
