import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { nextTick } from 'vue'
import { setupEditor } from '../../test/harness'
import type { EditorHarness } from '../../test/harness'
import { setMediaPrefix } from '../../editor/media'

let h: EditorHarness

beforeEach(() => {
  vi.useFakeTimers()
  setMediaPrefix('http://127.0.0.1:5321/tok/media/')
  h = setupEditor()
  h.api.insertVideo('video-1.mp4')
})

afterEach(() => {
  h.destroy()
  vi.useRealTimers()
})

const frame = (): HTMLElement | null => h.editor.view.dom.querySelector('.moodiary-video__frame')
const backdrop = (): HTMLElement | null =>
  h.editor.view.dom.querySelector('.moodiary-video__backdrop')
const videoEl = (): HTMLVideoElement | null =>
  h.editor.view.dom.querySelector('.moodiary-video__el')

/** 容器比例经 CSS 变量注入（CSS 侧同时用它算限高换算的宽度，比例不会被压扁）。 */
const frameRatio = (): number => Number(frame()?.style.getPropertyValue('--video-ratio'))

/** jsdom 不解码视频，videoWidth/videoHeight 恒 0 —— 手工塞进去再发 loadedmetadata。 */
const fakeMetadata = async (w: number, hgt: number): Promise<void> => {
  const el = videoEl()
  expect(el).not.toBeNull()
  Object.defineProperty(el, 'videoWidth', { value: w, configurable: true })
  Object.defineProperty(el, 'videoHeight', { value: hgt, configurable: true })
  el!.dispatchEvent(new Event('loadedmetadata'))
  await nextTick()
}

describe('video player box', () => {
  it('renders a ratio-driven frame instead of a full-width bare <video>', () => {
    expect(frame()?.classList.contains('moodiary-video__frame--boxed')).toBe(true)
    expect(videoEl()).not.toBeNull()
  })

  it('never paints the letterbox black', () => {
    expect(frame()?.className).not.toContain('bg-black')
  })

  it('defaults to 16:9 before the ratio is known', () => {
    expect(frameRatio()).toBeCloseTo(16 / 9, 3)
    // 比例未知时也铺着模糊层：此时看不见，但不能因为「不知道」就漏掉竖拍。
    expect(backdrop()).not.toBeNull()
  })
})

describe('frame ratio is clamped, not fixed', () => {
  it('clamps a 9:16 portrait video to 4:5 so the picture is not squeezed to a stamp', async () => {
    await fakeMetadata(1080, 1920)
    // 恒 16:9 的话画面只有 203×9/16 ≈ 114px 宽；夹到 4:5 后是 450×9/16 ≈ 253px。
    expect(frameRatio()).toBeCloseTo(4 / 5, 3)
    const el = backdrop()
    expect(el).not.toBeNull()
    expect(el?.style.backgroundImage).toContain('video-1.mp4?poster=1')
  })

  it('clamps an ultra-wide video down to 16:9', async () => {
    await fakeMetadata(2350, 1000)
    expect(frameRatio()).toBeCloseTo(16 / 9, 3)
    expect(backdrop()).not.toBeNull()
  })

  it('uses the video ratio verbatim inside the range, with no blur layer needed', async () => {
    await fakeMetadata(1440, 1080) // 4:3
    expect(frameRatio()).toBeCloseTo(4 / 3, 3)
    // 画面正好铺满容器 → 模糊层是纯浪费的合成层。
    expect(backdrop()).toBeNull()
  })

  it('skips the blur layer for exactly 16:9', async () => {
    await fakeMetadata(1920, 1080)
    expect(frameRatio()).toBeCloseTo(16 / 9, 3)
    expect(backdrop()).toBeNull()
  })
})

describe('control bar auto-hide', () => {
  const bar = (): HTMLElement | null => h.editor.view.dom.querySelector('.moodiary-video__bar')
  const hidden = (): boolean => bar()?.classList.contains('is-hidden') ?? false
  const seekSlider = (): HTMLInputElement | null =>
    h.editor.view.dom.querySelector('.moodiary-video__bar input[type="range"]')

  // jsdom 没实现 play()/pause()，直接派发事件驱动 useMediaControls 的状态。
  const fire = async (type: 'play' | 'pause'): Promise<void> => {
    videoEl()!.dispatchEvent(new Event(type))
    await nextTick()
  }
  const advance = async (ms: number): Promise<void> => {
    await vi.advanceTimersByTimeAsync(ms)
    await nextTick()
  }

  it('starts visible and stays visible while not playing', async () => {
    expect(hidden()).toBe(false)
    await advance(5000)
    expect(hidden()).toBe(false)
  })

  it('fades out a few seconds into playback', async () => {
    await fire('play')
    expect(hidden()).toBe(false)
    await advance(3000)
    expect(hidden()).toBe(true)
  })

  it('comes back when the picture is tapped, and hides again on a second tap', async () => {
    await fire('play')
    await advance(3000)
    expect(hidden()).toBe(true)

    videoEl()!.click()
    await nextTick()
    expect(hidden()).toBe(false)

    videoEl()!.click()
    await nextTick()
    expect(hidden()).toBe(true)
  })

  it('reappears and stays put on pause — a paused frame with no controls is a dead end', async () => {
    await fire('play')
    await advance(3000)
    expect(hidden()).toBe(true)

    await fire('pause')
    expect(hidden()).toBe(false)
    await advance(5000)
    expect(hidden()).toBe(false)
  })

  it('does not hide mid-drag on the seek bar', async () => {
    await fire('play')
    await advance(2000)

    // 拖了 4 秒（超过隐藏延时）——每次 input 都续命，不能中途藏掉。
    for (let i = 0; i < 4; i += 1) {
      const el = seekSlider()
      expect(el).not.toBeNull()
      el!.dispatchEvent(new Event('input'))
      await advance(1000)
      expect(hidden()).toBe(false)
    }
  })
})
