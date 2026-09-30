import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { createElement } from 'react'
import { cleanup, fireEvent, render } from '@testing-library/react'
import EditorMetaHeader from './EditorMetaHeader'
import type { EditorMeta } from '../bridge/meta'

interface Posted {
  type: string
  payload?: unknown
}

let posted: Posted[] = []

const meta = (over: Partial<EditorMeta> = {}): EditorMeta => ({
  dateText: '2026/9/14',
  subText: '周一 14:32:08',
  time: '2026-09-14T14:32:08',
  minDate: '1949-10-01',
  firstDayOfWeek: 1,
  use24h: true,
  mood: 'calm',
  moods: [
    { value: 'calm', label: '平静', color: '#888888', icon: 'meh' },
    { value: 'happy', label: '开心', color: '#ffaa00', icon: 'smile' },
  ],
  category: '工作',
  categoryId: 'c1',
  categories: [
    { id: 'c1', name: '工作' },
    { id: 'c2', name: '生活' },
  ],
  weather: null,
  weatherOptions: [{ code: '100', label: '晴' }],
  weatherClearLabel: '清除',
  places: [{ id: 'p1', name: '家', icon: 'house' }],
  positionNewPlaceLabel: '新建地点',
  positionManageLabel: '管理地点',
  positionClearLabel: '清除位置',
  tags: ['旅行'],
  ...over,
})

const mount = (m: EditorMeta = meta(), editable = true): HTMLElement =>
  render(createElement(EditorMetaHeader, { meta: m, editable, wordCount: 0 })).container

const find = (root: HTMLElement, selector: string): HTMLElement => {
  const el = root.querySelector<HTMLElement>(selector)
  if (!el) throw new Error(`missing ${selector}`)
  return el
}
const findAll = (root: HTMLElement, selector: string): HTMLElement[] =>
  Array.from(root.querySelectorAll<HTMLElement>(selector))
const click = (el: Element | undefined): void => {
  if (!el) throw new Error('missing element')
  fireEvent.click(el)
}

const openSheet = (): HTMLElement | null => document.body.querySelector('.moodiary-popover')
const sheetButtons = (): HTMLButtonElement[] =>
  Array.from(openSheet()?.querySelectorAll<HTMLButtonElement>('button') ?? [])
const sheetButton = (text: string): HTMLButtonElement | undefined =>
  sheetButtons().find((b) => b.textContent?.trim() === text)
const last = (type: string): Posted | undefined => [...posted].reverse().find((p) => p.type === type)

beforeEach(() => {
  vi.useFakeTimers()
  vi.setSystemTime(new Date(2026, 8, 23, 10, 0, 0))
  posted = []
  window.MoodiaryEditor = { postMessage: (raw: string) => posted.push(JSON.parse(raw) as Posted) }
})

afterEach(() => {
  cleanup()
  document.body.innerHTML = ''
  delete window.MoodiaryEditor
  vi.useRealTimers()
})

describe('meta header sheets', () => {
  it('date: opening drops the keyboard; a month grid starting on the configured weekday', () => {
    const w = mount()
    const typing = document.createElement('textarea')
    document.body.appendChild(typing)
    typing.focus()
    click(find(w, '.meta-date-anchor'))
    expect(document.activeElement).not.toBe(typing)
    expect(openSheet()).not.toBeNull()
    expect(last('overlay')?.payload).toBe(true)
    const days = sheetButtons().filter((b) => /^\d+$/.test(b.textContent!.trim()))
    expect(days).toHaveLength(30)
    expect(days.find((b) => b.textContent!.trim() === '14')?.getAttribute('aria-pressed')).toBe('true')
    expect(days.find((b) => b.textContent!.trim() === '24')?.disabled).toBe(true)
    const grid = openSheet()!.querySelector('.grid-cols-7')!
    expect(grid.children[7].tagName).toBe('SPAN')
    expect(grid.children[8].textContent!.trim()).toBe('1')

    click(days.find((b) => b.textContent!.trim() === '5'))
    expect(last('changeDate')?.payload).toEqual({ year: 2026, month: 9, day: 5 })
    expect(openSheet()).toBeNull()
  })

  it('date: the header switches to a year list that starts at the minimum year', () => {
    const w = mount()
    click(find(w, '.meta-date-anchor'))
    click(sheetButtons()[0])
    const years = sheetButtons().filter((b) => /^\d{4}$/.test(b.textContent!.trim()))
    expect(years[0].textContent!.trim()).toBe('1949')
    expect(years[years.length - 1].textContent!.trim()).toBe('2026')
    click(years[0])
    expect(openSheet()!.textContent).toContain('1949年10月')
    expect(openSheet()!.querySelector<HTMLButtonElement>('[aria-label="上个月"]')?.disabled).toBe(true)
  })

  it('time: confirm reads the wheel positions', () => {
    const tops: number[] = []
    Object.defineProperty(HTMLElement.prototype, 'scrollTop', {
      configurable: true,
      get(this: HTMLElement) {
        const i = Array.from(document.querySelectorAll('.moodiary-wheel__list')).indexOf(this)
        return i < 0 ? 0 : (tops[i] ?? 0)
      },
      set(this: HTMLElement, v: number) {
        const i = Array.from(document.querySelectorAll('.moodiary-wheel__list')).indexOf(this)
        if (i >= 0) tops[i] = v
      },
    })
    try {
      const w = mount()
      click(find(w, '.meta-date-sub'))
      expect(tops).toEqual([14 * 40, 32 * 40])
      tops[0] = 9 * 40
      tops[1] = 5 * 40 + 12
      click(sheetButton('确定'))
      expect(last('changeTime')?.payload).toEqual({ hour: 9, minute: 5 })
    } finally {
      delete (HTMLElement.prototype as { scrollTop?: number }).scrollTop
    }
  })

  it('category: picking posts the id, picking the current one posts nothing', () => {
    const w = mount()
    click(findAll(w, '.meta-fn-item')[0])
    click(sheetButton('工作'))
    expect(last('changeCategory')).toBeUndefined()
    click(findAll(w, '.meta-fn-item')[0])
    click(sheetButton('无分类'))
    expect(last('changeCategory')?.payload).toEqual({ id: null })
  })

  it('tags: typed inline, enter adds, duplicates are ignored, a tap on a tag offers delete', () => {
    const w = mount()
    const input = find(w, '.meta-tag-input') as HTMLInputElement
    fireEvent.input(input, { target: { value: '  读书 ' } })
    fireEvent.keyDown(input, { key: 'Enter' })
    expect(last('addTag')?.payload).toEqual({ name: '读书' })
    expect(input.value).toBe('')
    posted = []
    fireEvent.input(input, { target: { value: '旅行' } })
    fireEvent.keyDown(input, { key: 'Enter' })
    expect(last('addTag')).toBeUndefined()

    click(find(w, '.meta-tag'))
    click(sheetButtons()[0])
    expect(last('removeTag')?.payload).toEqual({ name: '旅行' })
    expect(openSheet()).toBeNull()
  })

  it('mood and weather post their choice and close', () => {
    const w = mount()
    click(find(w, '.meta-mood-chip'))
    click(sheetButtons().find((b) => b.textContent?.includes('开心')))
    expect(last('changeMood')?.payload).toEqual({ mood: 'happy' })
    expect(openSheet()).toBeNull()
    click(findAll(w, '.meta-fn-item')[1])
    click(sheetButtons().find((b) => b.textContent?.includes('晴')))
    expect(last('changeWeather')?.payload).toEqual({ code: '100' })
  })

  it('place: opening asks for a fix, new place hands off to Flutter', () => {
    const w = mount()
    click(findAll(w, '.meta-fn-item')[2])
    expect(last('locateForPlaces')).toBeDefined()
    click(sheetButtons().find((b) => b.textContent?.includes('新建地点')))
    expect(last('newPlace')).toBeDefined()
    expect(openSheet()).toBeNull()
  })

  it('read mode renders no sheets and ignores taps', () => {
    const w = mount(meta(), false)
    click(find(w, '.meta-date-anchor'))
    expect(openSheet()).toBeNull()
    expect(w.querySelector('.meta-tag-input')).toBeNull()
  })
})
