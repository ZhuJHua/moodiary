import { computed, onBeforeUnmount, onMounted, ref, type Ref } from 'vue'

export function useMediaControls(mediaRef: Ref<HTMLMediaElement | null>) {
  const playing = ref(false)
  const current = ref(0)
  const duration = ref(0)
  const muted = ref(false)
  const buffering = ref(false)

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
  function seekTo(seconds: number): void {
    dragging.value = true
    dragValue.value = seconds
    if (el) el.currentTime = seconds
  }
  function endSeek(seconds: number): void {
    if (el) el.currentTime = seconds
    current.value = seconds
    dragging.value = false
  }

  function onSeekInput(e: Event): void {
    seekTo(Number((e.target as HTMLInputElement).value))
  }
  function onSeekChange(e: Event): void {
    endSeek(Number((e.target as HTMLInputElement).value))
  }

  return {
    playing,
    current,
    duration,
    muted,
    buffering,
    sliderValue,
    dragging,
    toggle,
    toggleMute,
    seekTo,
    endSeek,
    onSeekInput,
    onSeekChange,
  }
}

export function formatTime(seconds: number): string {
  const s = Number.isFinite(seconds) && seconds > 0 ? Math.floor(seconds) : 0
  const h = Math.floor(s / 3600)
  const m = Math.floor((s % 3600) / 60)
  const sec = s % 60
  const mm = h > 0 ? String(m).padStart(2, '0') : String(m)
  const ss = String(sec).padStart(2, '0')
  return h > 0 ? `${h}:${mm}:${ss}` : `${mm}:${ss}`
}
