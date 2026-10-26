import { useRef, useState, type CSSProperties, type MouseEvent, type ReactNode } from 'react'
import { Cloud, Folder, Hash, LocateFixed, MapPin, Plus, RefreshCw, Settings, Trash2, X } from 'lucide-react'
import { post } from '@/core/bridge/post'
import { t } from '@/core/i18n'
import type { EditorMeta } from '@/core/state/meta'
import MoodGlyph from './MoodGlyph'
import Popover, { type PopoverHandle } from '@/ui/overlay/Popover'
import { placeIcon, weatherGlyph } from './icons'

interface MetaButtonProps {
  className: string
  editable: boolean
  ariaLabel?: string
  style?: CSSProperties
  onPress?: (anchor: HTMLElement) => void
  children: ReactNode
}

function MetaButton({ className, editable, ariaLabel, style, onPress, children }: MetaButtonProps) {
  return (
    <button
      type="button"
      className={className}
      style={style}
      disabled={!editable}
      aria-label={ariaLabel}
      onMouseDown={(e) => e.preventDefault()}
      onClick={(e: MouseEvent<HTMLButtonElement>) => onPress?.(e.currentTarget)}
    >
      {children}
    </button>
  )
}

interface FactProps {
  icon: ReactNode
  value?: string | null
  placeholder: string
  editable: boolean
  onPress: (anchor: HTMLElement) => void
}

function Fact({ icon, value, placeholder, editable, onPress }: FactProps) {
  if (!editable && !value) return null
  return (
    <MetaButton
      className={`md-fact${value ? '' : ' is-unset'}`}
      editable={editable}
      ariaLabel={value ? `${placeholder} ${value}` : placeholder}
      onPress={onPress}
    >
      {icon}
      <span className="md-fact__label">{value ?? placeholder}</span>
    </MetaButton>
  )
}

export default function EditorMetaHeader({
  meta,
  editable,
  wordCount,
}: {
  meta: EditorMeta
  editable: boolean
  wordCount: number
}) {
  const moodPop = useRef<PopoverHandle>(null)
  const weatherPop = useRef<PopoverHandle>(null)
  const placePop = useRef<PopoverHandle>(null)
  const tagPop = useRef<PopoverHandle>(null)
  const [tagIndex, setTagIndex] = useState(-1)

  const currentMood = meta.moods.find((m) => m.value === meta.mood)
  const glyph = weatherGlyph(meta.weather?.icon)

  const act = (pop: PopoverHandle | null, type: string, payload?: unknown): void => {
    pop?.close()
    post(type, payload)
  }

  const timeText = editable ? meta.subText : `${meta.subText} · ${t('wordCount', { count: wordCount })}`

  const hasFacts = editable || meta.weather || meta.position || meta.category
  const hasTags = editable || meta.tags.length > 0

  return (
    <div className="md-meta">
      <div className="md-meta__head">
        <div className="md-meta__when">
          <MetaButton className="md-meta__date" editable={editable} onPress={() => post('pickDate')}>
            {meta.dateText}
          </MetaButton>
          <MetaButton className="md-meta__time" editable={editable} onPress={() => post('pickTime')}>
            {timeText}
          </MetaButton>
        </div>
        <MetaButton
          className={`md-mood${currentMood ? '' : ' is-unset'}`}
          editable={editable}
          ariaLabel={`${t('meta.mood')} ${currentMood?.label ?? t('meta.moodUnset')}`}
          style={{ '--mood': currentMood?.color } as CSSProperties}
          onPress={(anchor) => moodPop.current?.open(anchor)}
        >
          <MoodGlyph level={currentMood?.value} color={currentMood?.color} onColor={currentMood?.onColor} size={18} />
          <span>{currentMood?.label ?? t('meta.moodUnset')}</span>
        </MetaButton>
      </div>

      {hasFacts && (
        <div className="md-meta__facts">
          <Fact
            editable={editable}
            icon={glyph ? <span className="md-qi">{glyph}</span> : <Cloud />}
            value={meta.weather?.text}
            placeholder={t('meta.weather')}
            onPress={(anchor) => weatherPop.current?.open(anchor)}
          />
          <Fact
            editable={editable}
            icon={<MapPin />}
            value={meta.position}
            placeholder={t('meta.place')}
            onPress={(anchor) => {
              placePop.current?.open(anchor)
              post('locateForPlaces')
            }}
          />
          <Fact
            editable={editable}
            icon={<Folder />}
            value={meta.category}
            placeholder={t('meta.category')}
            onPress={() => post('pickCategory')}
          />
        </div>
      )}

      {hasTags && (
        <div className="md-meta__tags">
          {meta.tags.map((tag, i) => (
            <MetaButton
              key={`${i}-${tag}`}
              className="md-tag"
              editable={editable}
              onPress={(anchor) => {
                setTagIndex(i)
                tagPop.current?.open(anchor)
              }}
            >
              #{tag}
            </MetaButton>
          ))}
          {editable && (
            <MetaButton
              className="md-tag md-tag--add"
              editable
              ariaLabel={t('meta.addTag')}
              onPress={() => post('addTag')}
            >
              <Hash />
              {meta.tags.length === 0 && <span>{t('meta.tag')}</span>}
            </MetaButton>
          )}
        </div>
      )}

      {editable && (
        <>
          <Popover ref={moodPop} label={t('meta.mood')} className="md-popover--mood">
            <div className="md-pop-grid">
              {meta.moods.map((m) => {
                const active = m.value === meta.mood
                return (
                  <button
                    key={m.value}
                    type="button"
                    className={`md-pop-cell${active ? ' is-active' : ''}`}
                    aria-pressed={active}
                    onClick={() => act(moodPop.current, 'changeMood', { mood: m.value })}
                  >
                    <MoodGlyph level={m.value} color={m.color} onColor={m.onColor} size={30} />
                    <span>{m.label}</span>
                  </button>
                )
              })}
            </div>
            <div className="md-pop-divider" />
            <button type="button" className="md-pop-item is-dim"
              aria-pressed={!currentMood}
              onClick={() => act(moodPop.current, 'changeMood', { mood: '' })}>
              <MoodGlyph size={18} />{t('meta.moodClear')}
            </button>
          </Popover>

          <Popover ref={weatherPop} label={t('meta.weather')} className="md-popover--grid">
            <div className="md-pop-grid">
              {meta.weatherOptions.map((w) => {
                const active = w.code === meta.weather?.icon
                return (
                  <button
                    key={w.code}
                    type="button"
                    className={`md-pop-cell${active ? ' is-active' : ''}`}
                    aria-pressed={active}
                    onClick={() => act(weatherPop.current, 'changeWeather', { code: w.code })}
                  >
                    <span className="md-qi">{weatherGlyph(w.code)}</span>
                    <span>{w.label}</span>
                  </button>
                )
              })}
            </div>
            {(meta.weatherAutoLabel || meta.weather) && <div className="md-pop-divider" />}
            {meta.weatherAutoLabel && (
              <button type="button" className="md-pop-item" onClick={() => act(weatherPop.current, 'fetchWeather')}>
                <RefreshCw />
                {meta.weatherAutoLabel}
              </button>
            )}
            {meta.weather && (
              <button
                type="button"
                className="md-pop-item is-dim"
                onClick={() => act(weatherPop.current, 'clearWeather')}
              >
                <X />
                {meta.weatherClearLabel}
              </button>
            )}
          </Popover>

          <Popover ref={placePop} label={t('meta.place')} className="md-popover--list">
            {meta.positionAutoLabel && (
              <button type="button" className="md-pop-item" onClick={() => act(placePop.current, 'fetchPosition')}>
                <LocateFixed />
                {meta.positionAutoLabel}
              </button>
            )}
            {meta.places.length > 0 && (
              <>
                {meta.positionAutoLabel && <div className="md-pop-divider" />}
                <div className="md-pop-scroll">
                  {meta.places.map((place) => {
                    const Icon = placeIcon(place.icon)
                    return (
                      <button
                        key={place.id}
                        type="button"
                        className={`md-pop-item${place.id === meta.positionId ? ' is-active' : ''}`}
                        onClick={() => act(placePop.current, 'pickPlace', { id: place.id })}
                      >
                        <Icon />
                        <span className="md-pop-item__grow">{place.name}</span>
                        {place.distance && <span className="md-pop-item__trail">{place.distance}</span>}
                      </button>
                    )
                  })}
                </div>
              </>
            )}
            {(meta.positionAutoLabel || meta.places.length > 0) && <div className="md-pop-divider" />}
            <button type="button" className="md-pop-item" onClick={() => act(placePop.current, 'newPlace')}>
              <Plus />
              {meta.positionNewPlaceLabel}
            </button>
            <button type="button" className="md-pop-item is-dim" onClick={() => act(placePop.current, 'managePlaces')}>
              <Settings />
              {meta.positionManageLabel}
            </button>
            {meta.position && (
              <button
                type="button"
                className="md-pop-item is-dim"
                onClick={() => act(placePop.current, 'clearPosition')}
              >
                <X />
                {meta.positionClearLabel}
              </button>
            )}
          </Popover>

          <Popover ref={tagPop} label={t('meta.removeTag')} className="md-popover--list">
            <button
              type="button"
              className="md-pop-item is-danger"
              onClick={() => act(tagPop.current, 'removeTag', { index: tagIndex })}
            >
              <Trash2 />
              {meta.deleteLabel}
            </button>
          </Popover>
        </>
      )}
    </div>
  )
}
