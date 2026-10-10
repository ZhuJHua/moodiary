import {
  Angry,
  Annoyed,
  BatteryLow,
  BookOpen,
  Briefcase,
  Building2,
  Coffee,
  Dumbbell,
  Fish,
  Frown,
  Heart,
  Hospital,
  House,
  MapPin,
  Meh,
  Plane,
  School,
  Smile,
  Sparkles,
  Thermometer,
  Tornado,
  Trees,
  Utensils,
  type LucideIcon,
} from 'lucide-react'
import qiFontUrl from 'qweather-icons/font/fonts/qweather-icons.woff2?url'
import qiCodepoints from 'qweather-icons/font/qweather-icons.json'

const MOOD_ICONS: Record<string, LucideIcon> = {
  smile: Smile,
  meh: Meh,
  frown: Frown,
  sparkles: Sparkles,
  angry: Angry,
  tornado: Tornado,
  'battery-low': BatteryLow,
  annoyed: Annoyed,
  heart: Heart,
  'book-open': BookOpen,
  fish: Fish,
  utensils: Utensils,
  briefcase: Briefcase,
  plane: Plane,
  dumbbell: Dumbbell,
  thermometer: Thermometer,
}

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

export function moodIcon(name: string | undefined): LucideIcon {
  return MOOD_ICONS[name ?? ''] ?? Meh
}

export function placeIcon(name: string | undefined): LucideIcon {
  return PLACE_ICONS[name ?? ''] ?? MapPin
}

const qiFace = new FontFace('qweather-icons', `url('${qiFontUrl}')`)
document.fonts.add(qiFace)
void qiFace.load().catch(() => {})

export function weatherGlyph(code: string | undefined | null): string {
  if (!code) return ''
  const cp = (qiCodepoints as Record<string, number>)[code]
  return cp ? String.fromCodePoint(cp) : ''
}
