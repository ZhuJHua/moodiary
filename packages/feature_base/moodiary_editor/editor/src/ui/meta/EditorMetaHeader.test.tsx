import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { setLocale } from '@/core/i18n'
import { installBridge, resetBridgeForTest } from '@/core/bridge'
import { metaStore, type EditorMeta } from '@/core/state/meta'
import EditorMetaHeader from './EditorMetaHeader'

const meta: EditorMeta = {
  dateText: '2026-10-25', subText: '12:00', mood: null,
  moods: [
    { value: 'awful', label: 'Awful', color: '#B71C1C', onColor: '#FFFFFF' },
    { value: 'bad', label: 'Bad', color: '#EE7F59', onColor: '#161616' },
    { value: 'okay', label: 'Okay', color: '#D8D5CD', onColor: '#161616' },
    { value: 'good', label: 'Good', color: '#79C26A', onColor: '#161616' },
    { value: 'great', label: 'Great', color: '#1E7B45', onColor: '#FFFFFF' },
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

  it('repaints pill and picker from updated palette colors without icon names', async () => {
    setLocale('en')
    const view = render(<EditorMetaHeader meta={{ ...meta, mood: 'awful' }} editable wordCount={0} />)
    const pill = screen.getByRole('button', { name: 'Mood Awful' })
    expect(pill.querySelector('svg')?.getAttribute('width')).toBe('18')
    expect(pill.querySelector('circle')?.getAttribute('fill')).toBe('#B71C1C')
    expect(pill.querySelector('g')?.getAttribute('stroke')).toBe('#FFFFFF')
    const updated = { ...meta, mood: 'awful', moods: meta.moods.map((m) => (
      m.value === 'awful' ? { ...m, color: '#5F84DE', onColor: '#161616' } : m
    )) }
    view.rerender(<EditorMetaHeader meta={updated} editable wordCount={0} />)
    expect(pill.querySelector('circle')?.getAttribute('fill')).toBe('#5F84DE')
    expect(pill.querySelector('g')?.getAttribute('stroke')).toBe('#161616')
    fireEvent.click(pill)
    const cell = await screen.findByRole('button', { name: 'Awful' })
    expect(cell.getAttribute('aria-pressed')).toBe('true')
    expect(cell.querySelector('svg')?.getAttribute('width')).toBe('30')
    expect(cell.querySelector('circle')?.getAttribute('fill')).toBe('#5F84DE')
    expect(cell.querySelector('g')?.getAttribute('stroke')).toBe('#161616')
    const clear = screen.getByRole('button', { name: "Don't record" })
    expect(clear.querySelector('circle')?.getAttribute('stroke-dasharray')).toBe('2.6 2.2')
  })

  it('also renders unset metadata in read-only mode', () => {
    setLocale('zh')
    render(<EditorMetaHeader meta={meta} editable={false} wordCount={0} />)
    expect(screen.getByText('未记录')).toBeTruthy()
  })
})
