import {
  Building2,
  Coffee,
  Dumbbell,
  Hospital,
  House,
  MapPin,
  Plane,
  School,
  Trees,
  type LucideIcon,
} from 'lucide-react'
import qiFontUrl from 'qweather-icons/font/fonts/qweather-icons.woff2?url'
import qiCodepoints from 'qweather-icons/font/qweather-icons.json'

const PLACE_ICONS: Record<string, LucideIcon> = {
  house: House,
  'building-2': Building2,
  school: School,
  coffee: Coffee,
  dumbbell: Dumbbell,
  trees: Trees,
  hospital: Hospital,
  plane: Plane,
  'map-pin': MapPin,
}

export function placeIcon(name: string | undefined): LucideIcon {
  return PLACE_ICONS[name ?? ''] ?? MapPin
}

let fontLoaded = false

export function weatherGlyph(code: string | undefined | null): string {
  if (!code) return ''
  if (!fontLoaded) {
    fontLoaded = true
    const face = new FontFace('qweather-icons', `url('${qiFontUrl}')`)
    document.fonts.add(face)
    void face.load()
  }
  const cp = (qiCodepoints as Record<string, number>)[code]
  return cp ? String.fromCodePoint(cp) : ''
}
