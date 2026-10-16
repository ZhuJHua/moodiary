import { createStore } from 'zustand/vanilla'

export const modeStore = createStore(() => ({ editable: true, panelMode: false }))
