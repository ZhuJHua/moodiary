import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { fireEvent } from '@testing-library/react'
import { setMediaPrefix } from '@/core/editor/media'
import { flush, renderEditor, type EditorFixture } from '@/test/editor'

let h: EditorFixture

beforeEach(async () => {
  vi.useFakeTimers()
  setMediaPrefix('http://127.0.0.1:5321/tok/media/')
  h = renderEditor()
  h.api.insertVideo('video-1.mp4')
  await flush()
})

afterEach(() => {
  h.destroy()
  vi.useRealTimers()
})

const query = <T extends HTMLElement>(selector: string): T => h.editor.view.dom.querySelector<T>(selector)!
const video = (): HTMLVideoElement => query('.moodiary-video__el')
const frameRatio = (): number => Number(query('.moodiary-video__frame').style.getPropertyValue('--video-ratio'))
const hasBackdrop = (): boolean => h.editor.view.dom.querySelector('.moodiary-video__backdrop') !== null
const controlsHidden = (): boolean => query('.moodiary-video__bar').classList.contains('is-hidden')

// jsdom 不解码媒体，尺寸与时长只能直接写到元素上再发事件
const loadMetadata = async (width: number, height: number): Promise<void> => {
  Object.defineProperty(video(), 'videoWidth', { value: width, configurable: true })
  Object.defineProperty(video(), 'videoHeight', { value: height, configurable: true })
  fireEvent(video(), new Event('loadedmetadata'))
  await flush()
}
const setDuration = async (seconds: number): Promise<void> => {
  Object.defineProperty(video(), 'duration', { value: seconds, configurable: true })
  Object.defineProperty(video(), 'currentTime', { value: 0, writable: true, configurable: true })
  fireEvent(video(), new Event('durationchange'))
  await flush()
}
const advance = async (ms: number): Promise<void> => {
  await vi.advanceTimersByTimeAsync(ms)
  await flush()
}
const layoutTrack = (): HTMLElement => {
  const track = query('.moodiary-video__track')
  track.getBoundingClientRect = () => ({ left: 0, width: 200 }) as DOMRect
  return track
}

describe('frame ratio', () => {
  it('defaults to 16:9 with a blurred backdrop until the ratio is known', () => {
    expect(frameRatio()).toBeCloseTo(16 / 9, 3)
    expect(hasBackdrop()).toBe(true)
  })

  it('clamps portrait to 4:5 and ultra-wide to 16:9, keeping the backdrop', async () => {
    await loadMetadata(1080, 1920)
    expect(frameRatio()).toBeCloseTo(4 / 5, 3)
    expect(hasBackdrop()).toBe(true)
    await loadMetadata(2350, 1000)
    expect(frameRatio()).toBeCloseTo(16 / 9, 3)
    expect(hasBackdrop()).toBe(true)
  })

  it('uses an in-range ratio verbatim and drops the backdrop', async () => {
    await loadMetadata(1440, 1080)
    expect(frameRatio()).toBeCloseTo(4 / 3, 3)
    expect(hasBackdrop()).toBe(false)
  })
})

describe('control bar auto-hide', () => {
  it('stays visible while paused', async () => {
    await advance(5000)
    expect(controlsHidden()).toBe(false)
  })

  it('fades out during playback and comes back on tap or pause', async () => {
    fireEvent(video(), new Event('play'))
    await advance(3000)
    expect(controlsHidden()).toBe(true)

    fireEvent.click(video())
    await flush()
    expect(controlsHidden()).toBe(false)
    fireEvent.click(video())
    await flush()
    expect(controlsHidden()).toBe(true)

    fireEvent(video(), new Event('pause'))
    await advance(5000)
    expect(controlsHidden()).toBe(false)
  })
})

describe('seek track', () => {
  it('seeks on press, follows the drag and clamps to the track', async () => {
    await setDuration(100)
    const track = layoutTrack()

    fireEvent.pointerDown(track, { clientX: 50, pointerId: 1 })
    await flush()
    expect(video().currentTime).toBeCloseTo(25, 3)
    expect(track.classList.contains('is-pressed')).toBe(true)

    fireEvent.pointerMove(track, { clientX: 999, pointerId: 1 })
    await flush()
    expect(video().currentTime).toBe(100)

    fireEvent.pointerUp(track, { clientX: 999, pointerId: 1 })
    await flush()
    expect(track.classList.contains('is-pressed')).toBe(false)
  })

  it('is inert while the duration is unknown', async () => {
    const track = layoutTrack()
    Object.defineProperty(video(), 'currentTime', { value: 0, writable: true, configurable: true })
    fireEvent.pointerDown(track, { clientX: 100, pointerId: 1 })
    await flush()
    expect(video().currentTime).toBe(0)
    expect(track.classList.contains('is-pressed')).toBe(false)
  })

  it('shows elapsed / total time', async () => {
    await setDuration(95)
    expect(query('.moodiary-video__time-pos').textContent).toBe('0:00')
    expect(query('.moodiary-video__time-dur').textContent).toBe('1:35')
  })
})
