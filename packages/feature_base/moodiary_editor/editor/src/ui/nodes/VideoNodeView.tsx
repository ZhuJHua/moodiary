import { useEffect, useRef, useState, type CSSProperties, type PointerEvent } from 'react'
import { NodeViewWrapper, type NodeViewProps } from '@tiptap/react'
import { Maximize, Pause, Play, Volume2, VolumeX } from 'lucide-react'
import { post } from '@/core/bridge/post'
import { t } from '@/core/i18n'
import { formatTime, useMediaControls } from '@/ui/hooks/use-media'
import { useMediaSrc } from '@/ui/hooks/use-media-src'

const MIN_FRAME_RATIO = 4 / 5
const MAX_FRAME_RATIO = 16 / 9
const CONTROLS_HIDE_DELAY = 3000

export default function VideoNodeView({ node, selected }: NodeViewProps) {
  const name = (node.attrs.src as string | null) ?? ''
  const src = useMediaSrc(name)
  const poster = useMediaSrc(name, true) ?? ''
  const width = typeof node.attrs.widthPercent === 'number' ? node.attrs.widthPercent : null

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
    if (!el || !name) return
    el.pause()
    keepControls()
    post('videoFullscreen', { name, position: el.currentTime })
  }

  const trackRef = useRef<HTMLDivElement>(null)
  const progressPercent = duration > 0 ? Math.min(100, Math.max(0, (sliderValue / duration) * 100)) : 0

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
    trackRef.current?.setPointerCapture(e.pointerId)
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
      className={`md-block md-video${selected ? ' is-selected' : ''}`}
      style={width ? { width: `${width}%` } : undefined}
      data-block-node=""
      contentEditable={false}
    >
      <div
        className="md-block__body md-video__frame"
        style={{ '--video-ratio': String(frameRatio) } as CSSProperties}
      >
        {showBackdrop && <div className="md-video__backdrop" style={{ backgroundImage: `url(${poster})` }} />}
        {/* iOS WKWebView 需要 playsinline 才能内联播放，否则弹系统全屏播放器 */}
        <video
          ref={videoRef}
          className="md-video__el"
          src={src}
          poster={poster}
          preload="metadata"
          playsInline
          webkit-playsinline=""
          onLoadedMetadata={onLoadedMetadata}
          onPlay={() => keepControls(true)}
          onPause={() => keepControls(false)}
          onEnded={() => keepControls(false)}
          onClick={onPictureTap}
        />
        <div
          className={`md-video__bar${controlsVisible ? '' : ' is-hidden'}`}
          onPointerDown={() => keepControls()}
        >
          <button
            className="md-video__key"
            type="button"
            aria-label={playing ? t('video.pause') : t('video.play')}
            onClick={toggle}
          >
            {playing ? <Pause /> : <Play />}
          </button>
          <div
            ref={trackRef}
            className={`md-video__track${dragging ? ' is-pressed' : ''}`}
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
            <span className="md-video__rail" />
            <span className="md-video__fill" style={{ width: `${progressPercent}%` }} />
            <span className="md-video__thumb" style={{ left: `${progressPercent}%` }} />
          </div>
          <span className="md-video__time">
            <span className="md-video__time-pos">{formatTime(sliderValue)}</span>
            <span className="md-video__time-sep">/</span>
            <span className="md-video__time-dur">{formatTime(duration)}</span>
          </span>
          <button
            className="md-video__key"
            type="button"
            aria-label={muted ? t('video.unmute') : t('video.mute')}
            onClick={toggleMute}
          >
            {muted ? <VolumeX /> : <Volume2 />}
          </button>
          <button className="md-video__key" type="button" aria-label={t('video.fullscreen')} onClick={handOffToNative}>
            <Maximize />
          </button>
        </div>
      </div>
    </NodeViewWrapper>
  )
}
