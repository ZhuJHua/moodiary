import { ref } from 'vue'

export interface EditorMetaMoodOption {
  value: string
  label: string
  color: string
  icon: string
}

export interface EditorMetaPlace {
  id: string
  name: string
  icon: string
  distance?: string | null
}

export interface EditorMetaWeatherOption {
  code: string
  label: string
}

export interface EditorMeta {
  dateText: string
  subText: string
  subTextRead: string
  mood: string
  moods: EditorMetaMoodOption[]
  category?: string | null
  weather?: { icon: string; text: string } | null
  weatherOptions: EditorMetaWeatherOption[]
  weatherAutoLabel?: string | null
  weatherClearLabel: string
  position?: string | null
  positionId?: string | null
  places: EditorMetaPlace[]
  positionAutoLabel?: string | null
  positionNewPlaceLabel: string
  positionManageLabel: string
  positionClearLabel: string
  tags: string[]
  deleteLabel: string
}

export interface EditorLinkItem {
  id: string
  title: string
  subtitle?: string
}

export interface EditorLinks {
  title: string
  outgoingLabel: string
  incomingLabel: string
  graphTip?: string
  outgoing: EditorLinkItem[]
  incoming: EditorLinkItem[]
}

export const meta = ref<EditorMeta | null>(null)

export const links = ref<EditorLinks | null>(null)

export function setMeta(json: string): void {
  try {
    meta.value = json ? (JSON.parse(json) as EditorMeta) : null
  } catch {
    meta.value = null
  }
}

export function setLinks(json: string): void {
  try {
    links.value = json ? (JSON.parse(json) as EditorLinks) : null
  } catch {
    links.value = null
  }
}
