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

const bar = (): HTMLElement | null => h.editor.view.dom.querySelector('.moodiary-video__bar')
const track = (): HTMLElement | null => h.editor.view.dom.querySelector('.moodiary-video__track')

/** jsdom 没有 PointerEvent，也不做布局。用 MouseEvent 顶替，再把轨道的矩形写死成 200px 宽。 */
const pointer = (type: string, clientX: number): Event => {
  const e = new MouseEvent(type, { bubbles: true, clientX })
  Object.defineProperty(e, 'pointerId', { value: 1 })
  return e
}
const layoutTrack = (width = 200): void => {
  const el = track()
  expect(el).not.toBeNull()
  el!.getBoundingClientRect = () =>
    ({ left: 0, top: 0, right: width, bottom: 28, width, height: 28, x: 0, y: 0 }) as DOMRect
}
/** jsdom 的 <video> 没有时长也不让写 currentTime，两样都得手工塞。 */
const fakeDuration = async (seconds: number): Promise<void> => {
  const el = videoEl()!
  Object.defineProperty(el, 'duration', { value: seconds, configurable: true })
  Object.defineProperty(el, 'currentTime', { value: 0, writable: true, configurable: true })
  el.dispatchEvent(new Event('durationchange'))
  await nextTick()
}

describe('control bar auto-hide', () => {
  const hidden = (): boolean => bar()?.classList.contains('is-hidden') ?? false

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
    await fakeDuration(100)
    await fire('play')
    await advance(2000)
    layoutTrack()

    track()!.dispatchEvent(pointer('pointerdown', 20))
    // 拖了 4 秒（超过隐藏延时）—— 每一下都续命，不能中途藏掉。
    for (let i = 0; i < 4; i += 1) {
      track()!.dispatchEvent(pointer('pointermove', 30 + i * 10))
      await advance(1000)
      expect(hidden()).toBe(false)
    }
    track()!.dispatchEvent(pointer('pointerup', 70))
  })
})

describe('seek track', () => {
  const time = (sel: string): string =>
    h.editor.view.dom.querySelector(`.moodiary-video__time-${sel}`)?.textContent?.trim() ?? ''
  const fillWidth = (): string =>
    (h.editor.view.dom.querySelector('.moodiary-video__fill') as HTMLElement | null)?.style.width ??
    ''

  it('自绘轨道而不是原生 range —— 原生的轨高和滑块不能随按压动画', () => {
    expect(track()).not.toBeNull()
    expect(bar()?.querySelector('input[type="range"]')).toBeNull()
  })

  it('按下即定位到落点，松手提交', async () => {
    await fakeDuration(100)
    layoutTrack()

    track()!.dispatchEvent(pointer('pointerdown', 50)) // 200px 宽的四分之一
    await nextTick()
    expect(videoEl()!.currentTime).toBeCloseTo(25, 3)
    expect(fillWidth()).toBe('25%')

    track()!.dispatchEvent(pointer('pointermove', 150))
    await nextTick()
    expect(videoEl()!.currentTime).toBeCloseTo(75, 3)

    track()!.dispatchEvent(pointer('pointerup', 150))
    await nextTick()
    expect(videoEl()!.currentTime).toBeCloseTo(75, 3)
  })

  it('落点夹在两端之间，划出轨道也不会算出负数或超过片长', async () => {
    await fakeDuration(100)
    layoutTrack()

    track()!.dispatchEvent(pointer('pointerdown', -80))
    await nextTick()
    expect(videoEl()!.currentTime).toBe(0)

    track()!.dispatchEvent(pointer('pointermove', 999))
    await nextTick()
    expect(videoEl()!.currentTime).toBe(100)
    track()!.dispatchEvent(pointer('pointerup', 999))
  })

  it('按下时轨加粗、时间码染色；松手复原', async () => {
    await fakeDuration(100)
    layoutTrack()

    expect(track()!.classList.contains('is-pressed')).toBe(false)
    track()!.dispatchEvent(pointer('pointerdown', 100))
    await nextTick()
    expect(track()!.classList.contains('is-pressed')).toBe(true)
    expect(bar()!.classList.contains('is-scrubbing')).toBe(true)

    track()!.dispatchEvent(pointer('pointerup', 100))
    await nextTick()
    expect(track()!.classList.contains('is-pressed')).toBe(false)
    expect(bar()!.classList.contains('is-scrubbing')).toBe(false)
  })

  it('时长未知时整条不可拖 —— 残缺 mp4 在 Android 上真的会给 DURATION_UNSET', async () => {
    layoutTrack()
    Object.defineProperty(videoEl()!, 'currentTime', {
      value: 0,
      writable: true,
      configurable: true,
    })

    track()!.dispatchEvent(pointer('pointerdown', 100))
    await nextTick()
    expect(videoEl()!.currentTime).toBe(0)
    expect(track()!.classList.contains('is-pressed')).toBe(false)
  })

  it('时间码分三段：已播 / 分隔 / 总长', async () => {
    await fakeDuration(95)
    expect(time('pos')).toBe('0:00')
    expect(time('sep')).toBe('/')
    expect(time('dur')).toBe('1:35')
  })
})
