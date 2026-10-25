import { createStore } from 'zustand/vanilla'

interface EditorMetaMoodOption {
  value: string
  label: string
  color: string
  icon: string
}

interface EditorMetaPlace {
  id: string
  name: string
  icon: string
  distance: string | null
}

interface EditorMetaWeatherOption {
  code: string
  label: string
}

export interface EditorMeta {
  dateText: string
  subText: string
  mood: string | null
  moods: EditorMetaMoodOption[]
  category: string | null
  weather: { icon: string; text: string } | null
  weatherOptions: EditorMetaWeatherOption[]
  weatherAutoLabel: string | null
  weatherClearLabel: string
  position: string | null
  positionId: string | null
  places: EditorMetaPlace[]
  positionAutoLabel: string | null
  positionNewPlaceLabel: string
  positionManageLabel: string
  positionClearLabel: string
  tags: string[]
  deleteLabel: string
}

interface EditorLinkItem {
  id: string
  title: string
  subtitle?: string
}

export interface EditorLinks {
  title: string
  outgoingLabel: string
  incomingLabel: string
  graphTip: string
  outgoing: EditorLinkItem[]
  incoming: EditorLinkItem[]
}

export const metaStore = createStore<{ meta: EditorMeta | null; links: EditorLinks | null }>()(() => ({
  meta: null,
  links: null,
}))

export function setMeta(json: string): void {
  metaStore.setState({ meta: json ? (JSON.parse(json) as EditorMeta) : null })
}

export function setLinks(json: string): void {
  metaStore.setState({ links: json ? (JSON.parse(json) as EditorLinks) : null })
}
