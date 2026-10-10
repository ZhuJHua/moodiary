import { useEffect, useRef, useState, type CSSProperties, type PointerEvent } from 'react'
import { NodeViewWrapper, type NodeViewProps } from '@tiptap/react'
import { Maximize, Pause, Play, Volume2, VolumeX } from 'lucide-react'
import BlockHandle from './BlockHandle'
import { post } from '@/core/bridge/post'
import { blockMenu, openBlockMenu } from '@/core/state/block-menu'
import { editable } from '@/core/state/editable'
import { mediaUrl } from '@/core/editor/media'
import { formatTime, useMediaControls } from '@/ui/hooks/use-media'
import { useT } from '@/core/i18n'
import { useStore } from '@/lib/store'

const MIN_FRAME_RATIO = 4 / 5
const MAX_FRAME_RATIO = 16 / 9
const CONTROLS_HIDE_DELAY = 3000

export default function VideoNodeView({ node, selected, getPos }: NodeViewProps) {
  const t = useT()
  const [owner] = useState(() => Symbol('video'))
  const menuOpen = useStore(blockMenu, (s) => s.owner === owner)
  const previewWidth = useStore(blockMenu, (s) => (s.owner === owner ? s.previewWidth : null))
  const canEdit = useStore(editable)

  const filename = (node.attrs.filename as string | null) ?? ''
  const src = filename ? mediaUrl(filename) : undefined
  const poster = filename ? mediaUrl(filename, { poster: true }) : ''

  const v = node.attrs.widthPercent
  const widthPercent = typeof v === 'number' ? v : null
  const shown = previewWidth ?? widthPercent

  const videoRef = useRef<HTMLVideoElement>(null)
  const { playing, duration, muted, sliderValue, dragging, toggle, toggleMute, seekTo, endSeek } =
    useMediaControls(videoRef)

  const [ratio, setRatio] = useState<number | null>(null)
  const frameRatio =
    ratio === null ? MAX_FRAME_RATIO : Math.min(MAX_FRAME_RATIO, Math.max(MIN_FRAME_RATIO, ratio))
  const showBackdrop = poster !== '' && (ratio === null || Math.abs(ratio - frameRatio) > 0.02)

  function onLoadedMetadata(): void {
    const el = videoRef.current
    if (el && el.videoWidth > 0 && el.videoHeight > 0) setRatio(el.videoWidth / el.videoHeight)
  }

  const [controlsVisible, setControlsVisible] = useState(true)
  const hideTimer = useRef<ReturnType<typeof setTimeout>>(undefined)

  function clearHideTimer(): void {
    if (hideTimer.current !== undefined) {
      clearTimeout(hideTimer.current)
      hideTimer.current = undefined
    }
  }
  // play/pause 事件回调里 playing 还是上一帧的值，由调用方显式传入
  function keepControls(isPlaying = playing): void {
    setControlsVisible(true)
    clearHideTimer()
    if (isPlaying) {
      hideTimer.current = setTimeout(() => setControlsVisible(false), CONTROLS_HIDE_DELAY)
    }
  }
  function onPictureTap(): void {
    if (controlsVisible) {
      if (playing) {
        setControlsVisible(false)
        clearHideTimer()
      }
      return
    }
    keepControls()
  }
  useEffect(() => clearHideTimer, [])

  function handOffToNative(): void {
    const el = videoRef.current
    if (!el || !filename) return
    try {
      el.pause()
    } catch {
    }
    keepControls()
    post('videoFullscreen', { name: filename, position: el.currentTime })
  }

  const trackRef = useRef<HTMLDivElement>(null)
  const progressPercent =
    duration > 0 ? Math.min(100, Math.max(0, (sliderValue / duration) * 100)) : 0

  function timeAtPointer(e: PointerEvent): number | null {
    const el = trackRef.current
    if (!el || !(duration > 0)) return null
    const rect = el.getBoundingClientRect()
    if (rect.width <= 0) return null
    const fraction = Math.min(1, Math.max(0, (e.clientX - rect.left) / rect.width))
    return fraction * duration
  }
  function onTrackDown(e: PointerEvent): void {
    const at = timeAtPointer(e)
    if (at === null) return
    // 老 WebView / jsdom 可能没有 setPointerCapture
    try {
      trackRef.current?.setPointerCapture?.(e.pointerId)
    } catch {
    }
    seekTo(at)
    keepControls()
  }
  function onTrackMove(e: PointerEvent): void {
    if (!dragging) return
    const at = timeAtPointer(e)
    if (at === null) return
    seekTo(at)
    keepControls()
  }
  function onTrackUp(e: PointerEvent): void {
    if (!dragging) return
    endSeek(timeAtPointer(e) ?? sliderValue)
    keepControls()
  }

  return (
    <NodeViewWrapper
      className={`moodiary-media moodiary-media--video${selected ? ' is-selected' : ''}${menuOpen ? ' is-menu-open' : ''}`}
      style={shown === null ? undefined : { maxWidth: `${shown}%` }}
      contentEditable={false}
    >
      <div
        className="moodiary-video__frame moodiary-video__frame--boxed moodiary-block__body overflow-hidden rounded-lg"
        style={{ '--video-ratio': String(frameRatio) } as CSSProperties}
      >
        {showBackdrop && (
          <div className="moodiary-video__backdrop" style={{ backgroundImage: `url(${poster})` }} />
        )}

        {/* iOS WKWebView 需要 playsinline 才能内联播放，否则弹系统全屏播放器 */}
        <video
          ref={videoRef}
          className="moodiary-video__el"
          src={src}
          poster={poster}
          preload="metadata"
          playsInline
          webkit-playsinline=""
          onLoadedMetadata={onLoadedMetadata}
          onPlay={() => keepControls(true)}
          onPause={() => keepControls(false)}
          onEnded={() => keepControls(false)}
          onMouseDown={(e) => e.preventDefault()}
          onClick={onPictureTap}
        />

        <div
          className={`moodiary-video__bar absolute inset-x-0 bottom-0 flex items-center gap-1${controlsVisible ? '' : ' is-hidden'}${dragging ? ' is-scrubbing' : ''}`}
          onMouseDown={(e) => e.preventDefault()}
          onPointerDown={() => keepControls()}
        >
          <button
            className="moodiary-video__key"
            type="button"
            title={playing ? t('video.pause') : t('video.play')}
            onClick={toggle}
          >
            {playing ? <Pause className="size-5" /> : <Play className="size-5" />}
          </button>

          <div
            ref={trackRef}
            className={`moodiary-video__track${dragging ? ' is-pressed' : ''}`}
            role="slider"
            aria-label={t('video.progressLabel')}
            aria-valuemin={0}
            aria-valuemax={Math.round(duration)}
            aria-valuenow={Math.round(sliderValue)}
            aria-valuetext={`${formatTime(sliderValue)} / ${formatTime(duration)}`}
            onPointerDown={onTrackDown}
            onPointerMove={onTrackMove}
            onPointerUp={onTrackUp}
            onPointerCancel={onTrackUp}
          >
            <span className="moodiary-video__rail" />
            <span className="moodiary-video__fill" style={{ width: `${progressPercent}%` }} />
            <span className="moodiary-video__thumb" style={{ left: `${progressPercent}%` }} />
          </div>

          <span className="moodiary-video__time">
            <span className="moodiary-video__time-pos">{formatTime(sliderValue)}</span>
            <span className="moodiary-video__time-sep">/</span>
            <span className="moodiary-video__time-dur">{formatTime(duration)}</span>
          </span>

          <button
            className="moodiary-video__key"
            type="button"
            title={muted ? t('video.unmute') : t('video.mute')}
            onClick={toggleMute}
          >
            {muted ? <VolumeX className="size-5" /> : <Volume2 className="size-5" />}
          </button>
          <button
            className="moodiary-video__key"
            type="button"
            title={t('video.fullscreen')}
            onClick={handOffToNative}
          >
            <Maximize className="size-5" />
          </button>
        </div>

        {canEdit && (
          <BlockHandle
            variant="corner"
            onOpen={(anchor) =>
              openBlockMenu({ owner, kind: 'video', anchor, getPos: () => getPos() })
            }
          />
        )}
      </div>
    </NodeViewWrapper>
  )
}
