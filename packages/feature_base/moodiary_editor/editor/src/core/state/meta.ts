import { createStore } from '@/lib/store'

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

export interface EditorMetaCategory {
  id: string
  name: string
}

export interface EditorMeta {
  dateText: string
  subText: string
  time?: string
  minDate?: string
  firstDayOfWeek?: number
  use24h?: boolean
  mood: string
  moods: EditorMetaMoodOption[]
  category?: string | null
  categoryId?: string | null
  categories?: EditorMetaCategory[]
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

export const meta = createStore<EditorMeta | null>(null)

export const links = createStore<EditorLinks | null>(null)

function parseJson<T>(json: string): T | null {
  try {
    return json ? (JSON.parse(json) as T) : null
  } catch {
    return null
  }
}

export function setMeta(json: string): void {
  meta.set(parseJson<EditorMeta>(json))
}

export function setLinks(json: string): void {
  links.set(parseJson<EditorLinks>(json))
}
