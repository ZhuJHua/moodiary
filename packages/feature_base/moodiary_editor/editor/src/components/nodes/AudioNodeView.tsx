import { useEffect, useRef, useState } from 'react'
import { NodeViewWrapper, type NodeViewProps } from '@tiptap/react'
import { Pause, Play, Volume2, VolumeX } from 'lucide-react'
import BlockHandle from './BlockHandle'
import { blockMenu, openBlockMenu } from '../../editor/block-menu'
import { editable } from '../../editor/editable'
import { fetchMediaName, mediaUrl } from '../../editor/media'
import { formatTime, useMediaControls } from '../../editor/use-media'
import { useT } from '../../i18n'
import { useStore } from '../../lib/store'
import { Button } from '../ui/button'
import { Slider } from '../ui/slider'

export default function AudioNodeView({ node, selected, getPos }: NodeViewProps) {
  const t = useT()
  const [owner] = useState(() => Symbol('audio'))
  const menuOpen = useStore(blockMenu, (s) => s.owner === owner)
  const canEdit = useStore(editable)

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
  const hasDuration = duration > 0

  return (
    <NodeViewWrapper
      className={`moodiary-media moodiary-media--audio${selected ? ' is-selected' : ''}${menuOpen ? ' is-menu-open' : ''}`}
      contentEditable={false}
    >
      <div className="moodiary-block__body flex items-center gap-3 rounded-lg border border-border bg-muted px-3 py-2.5">
        <Button
          variant="default"
          size="icon"
          className="shrink-0 rounded-full"
          type="button"
          title={playing ? t('audio.pause') : t('audio.play')}
          onMouseDown={(e) => e.preventDefault()}
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
              onMouseDown={(e) => e.preventDefault()}
              onClick={toggleMute}
            >
              {muted ? <VolumeX className="size-4" /> : <Volume2 className="size-4" />}
            </Button>
            {canEdit && (
              <BlockHandle
                variant="inline"
                onOpen={(anchor) =>
                  openBlockMenu({ owner, kind: 'audio', anchor, getPos: () => getPos() })
                }
              />
            )}
          </div>
          <div className="flex items-center gap-2">
            <Slider
              className="flex-1"
              min={0}
              max={hasDuration ? duration : 1}
              step={0.01}
              value={[sliderValue]}
              disabled={!hasDuration}
              aria-label={t('audio.progressLabel')}
              onValueChange={([v]) => seekTo(v)}
              onValueCommit={([v]) => endSeek(v)}
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
