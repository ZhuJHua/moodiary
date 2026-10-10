import { useRef, useState, type MouseEvent, type SyntheticEvent } from 'react'
import { ChevronDown, Cloud, Folder, MapPin, Plus, Trash2 } from 'lucide-react'
import { post } from '@/core/bridge/post'
import type { EditorMeta } from '@/core/state/meta'
import Popover, { type PopoverHandle } from '@/ui/overlay/Popover'
import MoodPicker from './MoodPicker'
import WeatherPicker from './WeatherPicker'
import PlacePicker from './PlacePicker'
import CategoryPicker from './CategoryPicker'
import DatePicker from './DatePicker'
import TimePicker from './TimePicker'
import type { PickerHandle } from './picker'
import { moodIcon, weatherGlyph } from './icons'
import { t } from '@/core/i18n'
import { keepFocus } from '@/lib/utils'

const anchorOf = (e: SyntheticEvent): HTMLElement => e.currentTarget as HTMLElement

export default function EditorMetaHeader({
  meta,
  editable,
  wordCount,
}: {
  meta: EditorMeta
  editable: boolean
  wordCount: number
}) {

  const subLine = editable
    ? meta.subText
    : `${meta.subText} · ${t('wordCount', { count: wordCount })}`

  const currentMood = meta.moods.find((m) => m.value === meta.mood) ?? meta.moods[0]
  const MoodIcon = moodIcon(currentMood?.icon)
  const weatherIcon = weatherGlyph(meta.weather?.icon)

  const moodPicker = useRef<PickerHandle>(null)
  const weatherPicker = useRef<PickerHandle>(null)
  const placePicker = useRef<PickerHandle>(null)
  const categoryPicker = useRef<PickerHandle>(null)
  const datePicker = useRef<PickerHandle>(null)
  const timePicker = useRef<PickerHandle>(null)
  const tagMenu = useRef<PopoverHandle>(null)
  const tagTarget = useRef('')
  const [tagDraft, setTagDraft] = useState('')

  function openTag(tag: string, e: MouseEvent<HTMLButtonElement>): void {
    tagTarget.current = tag
    tagMenu.current?.open(anchorOf(e))
  }

  function removeTag(): void {
    tagMenu.current?.close()
    post('removeTag', { name: tagTarget.current })
  }

  function onTagKeydown(e: React.KeyboardEvent<HTMLInputElement>): void {
    if (e.key !== 'Enter' || e.nativeEvent.isComposing) return
    e.preventDefault()
    const input = e.currentTarget
    const name = input.value.trim()
    input.value = ''
    setTagDraft('')
    if (name && !meta.tags.includes(name)) post('addTag', { name })
  }

  const showCategory = editable || meta.category
  const showWeather = editable || meta.weather
  const showPosition = editable || meta.position
  const showTagsRow = editable || meta.tags.length > 0

  return (
    <div className="meta-header">
      <div className="meta-date-row">
        <button
          type="button"
          className="meta-plain-btn meta-date-anchor"
          disabled={!editable}
          onMouseDown={keepFocus}
          onClick={(e) => datePicker.current?.open(anchorOf(e))}
        >
          {meta.dateText}
        </button>
        <button
          type="button"
          className="meta-plain-btn meta-date-sub"
          disabled={!editable}
          onMouseDown={keepFocus}
          onClick={(e) => timePicker.current?.open(anchorOf(e))}
        >
          {subLine}
        </button>
        {editable && <ChevronDown className="meta-date-chevron" />}
      </div>

      <div className="meta-fn-row">
        <button
          type="button"
          className="meta-plain-btn meta-fn-mood meta-mood-chip"
          style={{ color: currentMood?.color, background: `${currentMood?.color}26` }}
          disabled={!editable}
          onMouseDown={keepFocus}
          onClick={(e) => moodPicker.current?.open(anchorOf(e))}
        >
          <MoodIcon className="size-4" />
          <span className="meta-mood-label">{currentMood?.label}</span>
        </button>
        {showCategory && (
          <button
            type="button"
            className="meta-plain-btn meta-fn-item"
            disabled={!editable}
            onMouseDown={keepFocus}
            onClick={(e) => categoryPicker.current?.open(anchorOf(e))}
          >
            <Folder className={`meta-fn-icon${meta.category ? '' : ' meta-fn-icon--unset'}`} />
            {meta.category && <span className="meta-fn-label">{meta.category}</span>}
          </button>
        )}
        {showWeather && (
          <button
            type="button"
            className="meta-plain-btn meta-fn-item meta-fn-item--shrink"
            disabled={!editable}
            onMouseDown={keepFocus}
            onClick={(e) => weatherPicker.current?.open(anchorOf(e))}
          >
            {weatherIcon ? (
              <span className="meta-fn-icon meta-fn-qi">{weatherIcon}</span>
            ) : (
              <Cloud className={`meta-fn-icon${meta.weather ? '' : ' meta-fn-icon--unset'}`} />
            )}
            {meta.weather && <span className="meta-fn-label">{meta.weather.text}</span>}
          </button>
        )}
        {showPosition && (
          <button
            type="button"
            className="meta-plain-btn meta-fn-item meta-fn-item--shrink"
            disabled={!editable}
            onMouseDown={keepFocus}
            onClick={(e) => placePicker.current?.open(anchorOf(e))}
          >
            <MapPin className={`meta-fn-icon${meta.position ? '' : ' meta-fn-icon--unset'}`} />
            {meta.position && <span className="meta-fn-label">{meta.position}</span>}
          </button>
        )}
      </div>

      {showTagsRow && (
        <div className="meta-tags-row">
          {meta.tags.map((tag, i) => (
            <button
              key={`${i}-${tag}`}
              type="button"
              className="meta-plain-btn meta-tag"
              disabled={!editable}
              onMouseDown={keepFocus}
              onClick={(e) => openTag(tag, e)}
            >
              #{tag}
            </button>
          ))}
          {editable && (
            <label className={`meta-tag-new${tagDraft ? ' is-filled' : ''}`}>
              <Plus className="meta-tag-new-icon" />
              <input
                className="meta-tag-input"
                type="text"
                enterKeyHint="done"
                placeholder={t('meta.tagPlaceholder')}
                aria-label={t('meta.addTag')}
                onInput={(e) => setTagDraft(e.currentTarget.value)}
                onKeyDown={onTagKeydown}
              />
            </label>
          )}
        </div>
      )}

      {editable && (
        <>
          <DatePicker ref={datePicker} meta={meta} />
          <TimePicker ref={timePicker} meta={meta} />
          <MoodPicker ref={moodPicker} meta={meta} />
          <CategoryPicker ref={categoryPicker} meta={meta} />
          <WeatherPicker ref={weatherPicker} meta={meta} />
          <PlacePicker ref={placePicker} meta={meta} />
          <Popover ref={tagMenu} panelClass="min-w-42">
            <button type="button" className="moodiary-pop-item is-danger" onClick={removeTag}>
              <Trash2 />
              {t('meta.removeTag')}
            </button>
          </Popover>
        </>
      )}
    </div>
  )
}
