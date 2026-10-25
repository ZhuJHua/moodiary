import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { setLocale } from '@/core/i18n'
import { installBridge, resetBridgeForTest } from '@/core/bridge'
import { metaStore, type EditorMeta } from '@/core/state/meta'
import EditorMetaHeader from './EditorMetaHeader'

const meta: EditorMeta = {
  dateText: '2026-10-25', subText: '12:00', mood: null,
  moods: [
    { value: 'awful', label: 'Awful', color: '#B71C1C', icon: 'frown' },
    { value: 'bad', label: 'Bad', color: '#EE7F59', icon: 'annoyed' },
    { value: 'okay', label: 'Okay', color: '#D8D5CD', icon: 'meh' },
    { value: 'good', label: 'Good', color: '#79C26A', icon: 'smile' },
    { value: 'great', label: 'Great', color: '#1E7B45', icon: 'laugh' },
  ],
  category: null, weather: null, weatherOptions: [], weatherAutoLabel: null,
  weatherClearLabel: '', position: null, positionId: null, places: [],
  positionAutoLabel: null, positionNewPlaceLabel: '', positionManageLabel: '',
  positionClearLabel: '', tags: [], deleteLabel: '',
}

afterEach(() => {
  cleanup()
  resetBridgeForTest()
  metaStore.setState({ meta: null })
  setLocale('zh')
})

describe('mood metadata bridge', () => {
  it.each([null, ''])('renders an unset pill for %s and posts choices and clear', async (mood) => {
    setLocale('en')
    const postMessage = vi.fn()
    window.MoodiaryEditor = { postMessage }
    installBridge()
    window.MoodiaryBridge.setMeta(JSON.stringify({ ...meta, mood }))
    const current = metaStore.getState().meta!
    const view = render(<EditorMetaHeader meta={current} editable wordCount={0} />)
    fireEvent.click(screen.getByRole('button', { name: 'Mood Not recorded' }))
    await screen.findByRole('button', { name: 'Awful' })
    for (const label of ['Awful', 'Bad', 'Okay', 'Good', 'Great']) {
      expect(screen.getByRole('button', { name: label })).toBeTruthy()
    }
    fireEvent.click(screen.getByRole('button', { name: 'Good' }))
    expect(postMessage.mock.calls.map(([raw]) => JSON.parse(raw))).toContainEqual({ type: 'changeMood', payload: { mood: 'good' } })
    view.rerender(<EditorMetaHeader meta={{ ...current, mood: 'good' }} editable wordCount={0} />)
    fireEvent.click(screen.getByRole('button', { name: 'Mood Good' }))
    fireEvent.click(await screen.findByRole('button', { name: "Don't record" }))
    expect(postMessage.mock.calls.map(([raw]) => JSON.parse(raw))).toContainEqual({ type: 'changeMood', payload: { mood: '' } })
  })

  it('also renders unset metadata in read-only mode', () => {
    setLocale('zh')
    render(<EditorMetaHeader meta={meta} editable={false} wordCount={0} />)
    expect(screen.getByText('未记录')).toBeTruthy()
  })
})
