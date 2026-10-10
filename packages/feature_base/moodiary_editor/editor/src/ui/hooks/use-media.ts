import { useEffect, useRef, useState, type RefObject } from 'react'

export interface MediaControls {
  playing: boolean
  duration: number
  muted: boolean
  dragging: boolean
  sliderValue: number
  toggle(): void
  toggleMute(): void
  seekTo(seconds: number): void
  endSeek(seconds: number): void
}

export function useMediaControls(mediaRef: RefObject<HTMLMediaElement | null>): MediaControls {
  const [playing, setPlaying] = useState(false)
  const [current, setCurrent] = useState(0)
  const [duration, setDuration] = useState(0)
  const [muted, setMuted] = useState(false)
  const [dragging, setDragging] = useState(false)
  const [dragValue, setDragValue] = useState(0)
  const draggingRef = useRef(false)

  useEffect(() => {
    const el = mediaRef.current
    if (!el) return
    const onPlay = (): void => setPlaying(true)
    const onPause = (): void => setPlaying(false)
    const onTime = (): void => {
      if (!draggingRef.current) setCurrent(el.currentTime)
    }
    const onMeta = (): void => setDuration(Number.isFinite(el.duration) ? el.duration : 0)
    const onEnded = (): void => {
      setPlaying(false)
      setCurrent(0)
    }
    const onVolume = (): void => setMuted(el.muted)
    const events: Array<[string, EventListener]> = [
      ['play', onPlay],
      ['pause', onPause],
      ['timeupdate', onTime],
      ['loadedmetadata', onMeta],
      ['durationchange', onMeta],
      ['ended', onEnded],
      ['volumechange', onVolume],
    ]
    for (const [name, fn] of events) el.addEventListener(name, fn)
    onMeta()
    onVolume()
    return () => {
      el.pause()
      for (const [name, fn] of events) el.removeEventListener(name, fn)
    }
  }, [mediaRef])

  const toggle = (): void => {
    const el = mediaRef.current
    if (!el) return
    if (el.paused) el.play().catch(() => {})
    else el.pause()
  }
  const toggleMute = (): void => {
    const el = mediaRef.current
    if (el) el.muted = !el.muted
  }
  const seekTo = (seconds: number): void => {
    draggingRef.current = true
    setDragging(true)
    setDragValue(seconds)
    const el = mediaRef.current
    if (el) el.currentTime = seconds
  }
  const endSeek = (seconds: number): void => {
    const el = mediaRef.current
    if (el) el.currentTime = seconds
    setCurrent(seconds)
    draggingRef.current = false
    setDragging(false)
  }

  return {
    playing,
    duration,
    muted,
    dragging,
    sliderValue: dragging ? dragValue : current,
    toggle,
    toggleMute,
    seekTo,
    endSeek,
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
