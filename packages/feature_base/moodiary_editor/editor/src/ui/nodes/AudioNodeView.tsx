import { useRef } from 'react'
import { NodeViewWrapper, type NodeViewProps } from '@tiptap/react'
import { Pause, Play } from 'lucide-react'
import { t } from '@/core/i18n'
import { useMediaSrc } from '@/ui/hooks/use-media-src'
import { formatTime, useMediaControls } from '@/ui/hooks/use-media'

export default function AudioNodeView({ node, selected }: NodeViewProps) {
  const src = useMediaSrc((node.attrs.src as string | null) ?? '')
  const name = (node.attrs.name as string | null) || t('audio.defaultName')

  const audioRef = useRef<HTMLAudioElement>(null)
  const { playing, duration, sliderValue, toggle, seekTo, endSeek } = useMediaControls(audioRef)
  const progress = duration > 0 ? Math.min(100, (sliderValue / duration) * 100) : 0

  return (
    <NodeViewWrapper
      className={`md-block md-audio${selected ? ' is-selected' : ''}`}
      data-block-node=""
      contentEditable={false}
    >
      <div className="md-block__body md-audio__card">
        <button
          type="button"
          className="md-audio__play"
          aria-label={playing ? t('audio.pause') : t('audio.play')}
          onClick={toggle}
        >
          {playing ? <Pause /> : <Play />}
        </button>
        <div className="md-audio__main">
          <span className="md-audio__name">{name}</span>
          <div className="md-audio__row">
            <input
              className="md-range"
              style={{ '--progress': `${progress}%` } as React.CSSProperties}
              type="range"
              min={0}
              max={duration || 0}
              step="any"
              value={sliderValue}
              aria-label={t('audio.progressLabel')}
              onChange={(e) => seekTo(Number(e.currentTarget.value))}
              onPointerUp={(e) => endSeek(Number(e.currentTarget.value))}
              onPointerCancel={(e) => endSeek(Number(e.currentTarget.value))}
              onKeyUp={(e) => endSeek(Number(e.currentTarget.value))}
            />
            <span className="md-audio__time">
              {formatTime(sliderValue)} / {formatTime(duration)}
            </span>
          </div>
        </div>
      </div>
      <audio ref={audioRef} src={src} preload="metadata" />
    </NodeViewWrapper>
  )
}
