// 原生 HTMLMediaElement 播放控制（不引任何播放器库）。音频/视频节点视图共用：把 <audio>/<video>
// 的播放状态、进度、音量、缓冲映射成响应式 ref，并提供播放/拖拽定位/静音命令。控件 UI 由各节点
// 视图用 daisyUI（btn / range）自绘。Range 拖拽用 dragging 标志隔离 timeupdate,避免拖拽指与流值打架。
import { computed, onBeforeUnmount, onMounted, ref, type Ref } from 'vue'

export function useMediaControls(mediaRef: Ref<HTMLMediaElement | null>) {
  const playing = ref(false)
  const current = ref(0)
  const duration = ref(0)
  const muted = ref(false)
  const buffering = ref(false)

  // 拖拽进度条期间用本地值显示,松手前不被 timeupdate 覆盖。
  const dragging = ref(false)
  const dragValue = ref(0)
  const sliderValue = computed(() => (dragging.value ? dragValue.value : current.value))

  let el: HTMLMediaElement | null = null

  const onPlay = () => (playing.value = true)
  const onPause = () => (playing.value = false)
  const onTime = () => {
    if (el && !dragging.value) current.value = el.currentTime
  }
  const onMeta = () => {
    if (el) duration.value = Number.isFinite(el.duration) ? el.duration : 0
  }
  const onEnded = () => {
    playing.value = false
    current.value = 0
  }
  const onWaiting = () => (buffering.value = true)
  const onPlaying = () => (buffering.value = false)
  const onVolume = () => {
    if (el) muted.value = el.muted
  }

  const events: Array<[string, EventListener]> = [
    ['play', onPlay],
    ['pause', onPause],
    ['timeupdate', onTime],
    ['loadedmetadata', onMeta],
    ['durationchange', onMeta],
    ['ended', onEnded],
    ['waiting', onWaiting],
    ['playing', onPlaying],
    ['canplay', onPlaying],
    ['volumechange', onVolume],
  ]

  onMounted(() => {
    el = mediaRef.value
    if (!el) return
    for (const [name, fn] of events) el.addEventListener(name, fn)
    onMeta()
    onVolume()
  })

  onBeforeUnmount(() => {
    if (!el) return
    try {
      el.pause()
    } catch {
      /* no-op */
    }
    for (const [name, fn] of events) el.removeEventListener(name, fn)
    el = null
  })

  function toggle(): void {
    if (!el) return
    if (el.paused) el.play().catch(() => {})
    else el.pause()
  }
  function toggleMute(): void {
    if (el) el.muted = !el.muted
  }
  // 拖拽中实时定位（current 不变,显示走 dragValue,避免回弹）；松手提交并恢复跟随。
  function onSeekInput(e: Event): void {
    dragging.value = true
    dragValue.value = Number((e.target as HTMLInputElement).value)
    if (el) el.currentTime = dragValue.value
  }
  function onSeekChange(e: Event): void {
    const v = Number((e.target as HTMLInputElement).value)
    if (el) el.currentTime = v
    current.value = v
    dragging.value = false
  }

  return {
    playing,
    current,
    duration,
    muted,
    buffering,
    sliderValue,
    toggle,
    toggleMute,
    onSeekInput,
    onSeekChange,
  }
}

/** 秒 → m:ss（超过 1 小时则 h:mm:ss）。NaN/负数按 0 处理。 */
export function formatTime(seconds: number): string {
  const s = Number.isFinite(seconds) && seconds > 0 ? Math.floor(seconds) : 0
  const h = Math.floor(s / 3600)
  const m = Math.floor((s % 3600) / 60)
  const sec = s % 60
  const mm = h > 0 ? String(m).padStart(2, '0') : String(m)
  const ss = String(sec).padStart(2, '0')
  return h > 0 ? `${h}:${mm}:${ss}` : `${mm}:${ss}`
}
