import { useEffect, useRef, useState } from 'react'
import { NodeViewWrapper, type NodeViewProps } from '@tiptap/react'
import { Pause, Play, Volume2, VolumeX } from 'lucide-react'
import { cn } from 'cn'
import BlockHandle from './BlockHandle'
import { fetchMediaName, mediaUrl } from '@/core/editor/media'
import { formatTime, useMediaControls } from '@/ui/hooks/use-media'
import { t } from '@/core/i18n'
import { useBlockMenu } from '@/ui/hooks/use-block-menu'
import { rangeClass } from '@/lib/range'
import { Button } from '@/ui/primitives/button'
import { keepFocus } from '@/lib/utils'

export default function AudioNodeView({ node, selected, getPos }: NodeViewProps) {
  const { canEdit, wrapperClass, openMenu } = useBlockMenu('audio', getPos, selected)

  const filename = (node.attrs.filename as string | null) ?? ''
  const src = filename ? mediaUrl(filename) : undefined

  const [fetchedName, setFetchedName] = useState<string | null>(null)
  useEffect(() => {
    if (!filename) return
    let alive = true
    void fetchMediaName(filename).then((name) => {
      if (alive && name) setFetchedName(name)
    })
    return () => {
      alive = false
    }
  }, [filename])
  const displayName = fetchedName ?? t('audio.defaultName')

  const audioRef = useRef<HTMLAudioElement>(null)
  const { playing, duration, muted, sliderValue, toggle, toggleMute, seekTo, endSeek } =
    useMediaControls(audioRef)

  return (
    <NodeViewWrapper
      className={wrapperClass('moodiary-media moodiary-media--audio')}
      contentEditable={false}
    >
      <div className="moodiary-block__body flex items-center gap-3 rounded-lg border border-border bg-muted px-3 py-2.5">
        <Button
          variant="default"
          size="icon"
          className="shrink-0 rounded-full"
          type="button"
          title={playing ? t('audio.pause') : t('audio.play')}
          onMouseDown={keepFocus}
          onClick={toggle}
        >
          {playing ? <Pause className="size-5" /> : <Play className="size-5" />}
        </Button>
        <div className="flex min-w-0 flex-1 flex-col gap-1">
          <div className="flex items-center gap-2">
            <span className="min-w-0 flex-1 truncate text-sm font-medium">{displayName}</span>
            <Button
              variant="ghost"
              size="icon-xs"
              className="shrink-0 rounded-full"
              type="button"
              title={muted ? t('audio.unmute') : t('audio.mute')}
              onMouseDown={keepFocus}
              onClick={toggleMute}
            >
              {muted ? <VolumeX className="size-4" /> : <Volume2 className="size-4" />}
            </Button>
            {canEdit && (
              <BlockHandle variant="inline" onOpen={openMenu} />
            )}
          </div>
          <div className="flex items-center gap-2">
            <input
              className={cn(rangeClass, 'h-1.5 flex-1')}
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
            <span className="shrink-0 text-xs text-muted-foreground tabular-nums">
              {formatTime(sliderValue)} / {formatTime(duration)}
            </span>
          </div>
        </div>
      </div>
      <audio ref={audioRef} src={src} preload="metadata" />
    </NodeViewWrapper>
  )
}
