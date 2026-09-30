import type { Component } from 'vue'
import IconSmile from '~icons/lucide/smile'
import IconMeh from '~icons/lucide/meh'
import IconFrown from '~icons/lucide/frown'
import IconSparkles from '~icons/lucide/sparkles'
import IconAngry from '~icons/lucide/angry'
import IconTornado from '~icons/lucide/tornado'
import IconBatteryLow from '~icons/lucide/battery-low'
import IconAnnoyed from '~icons/lucide/annoyed'
import IconHeart from '~icons/lucide/heart'
import IconBookOpen from '~icons/lucide/book-open'
import IconFish from '~icons/lucide/fish'
import IconUtensils from '~icons/lucide/utensils'
import IconBriefcase from '~icons/lucide/briefcase'
import IconPlane from '~icons/lucide/plane'
import IconDumbbell from '~icons/lucide/dumbbell'
import IconThermometer from '~icons/lucide/thermometer'
import IconMapPin from '~icons/lucide/map-pin'
import IconHouse from '~icons/lucide/house'
import IconBuilding from '~icons/lucide/building-2'
import IconSchool from '~icons/lucide/school'
import IconCoffee from '~icons/lucide/coffee'
import IconTrees from '~icons/lucide/trees'
import IconHospital from '~icons/lucide/hospital'
import qiFontUrl from 'qweather-icons/font/fonts/qweather-icons.woff2?url'
import qiCodepoints from 'qweather-icons/font/qweather-icons.json'

const MOOD_ICONS: Record<string, Component> = {
  smile: IconSmile,
  meh: IconMeh,
  frown: IconFrown,
  sparkles: IconSparkles,
  angry: IconAngry,
  tornado: IconTornado,
  'battery-low': IconBatteryLow,
  annoyed: IconAnnoyed,
  heart: IconHeart,
  'book-open': IconBookOpen,
  fish: IconFish,
  utensils: IconUtensils,
  briefcase: IconBriefcase,
  plane: IconPlane,
  dumbbell: IconDumbbell,
  thermometer: IconThermometer,
}

const PLACE_ICONS: Record<string, Component> = {
  house: IconHouse,
  'building-2': IconBuilding,
  school: IconSchool,
  coffee: IconCoffee,
  dumbbell: IconDumbbell,
  trees: IconTrees,
  hospital: IconHospital,
  plane: IconPlane,
  'map-pin': IconMapPin,
}

export function moodIcon(name: string | undefined): Component {
  return MOOD_ICONS[name ?? ''] ?? IconMeh
}

export function placeIcon(name: string | undefined): Component {
  return PLACE_ICONS[name ?? ''] ?? IconMapPin
}

const qiFace = new FontFace('qweather-icons', `url('${qiFontUrl}')`)
document.fonts.add(qiFace)
void qiFace.load().catch(() => {})

export function weatherGlyph(code: string | undefined | null): string {
  if (!code) return ''
  const cp = (qiCodepoints as Record<string, number>)[code]
  return cp ? String.fromCodePoint(cp) : ''
}
