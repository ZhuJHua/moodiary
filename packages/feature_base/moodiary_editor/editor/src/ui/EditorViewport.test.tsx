import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { act, cleanup, render, screen } from '@testing-library/react'
import { Editor } from '@tiptap/react'
import { bindApi, installBridge, resetBridgeForTest } from '@/core/bridge'
import { cancelChange } from '@/core/bridge/change'
import { createEditorKit } from '@/core/editor/kit'
import { modeStore } from '@/core/state/editable'
import { metaStore, type EditorMeta } from '@/core/state/meta'
import { titleStore } from '@/core/state/title'
import { doc, p } from '@/test/editor'
import { nodeViews } from './nodes'
import EditorViewport from './EditorViewport'

const meta: EditorMeta = {
  dateText: '2026-10-25', subText: '12:00', mood: null, moods: [],
  category: 'Travel', weather: null, weatherOptions: [], weatherAutoLabel: null,
  weatherClearLabel: '', position: 'Home', positionId: 'p', places: [],
  positionAutoLabel: null, positionNewPlaceLabel: '', positionManageLabel: '',
  positionClearLabel: '', tags: [], deleteLabel: '',
}

let editor: Editor
let page: HTMLElement

beforeEach(() => {
  metaStore.setState({ meta: undefined, links: null })
  modeStore.setState({ editable: true, panelMode: false })
  titleStore.setState({ title: '' })
  const kit = createEditorKit({ editable: true, placeholder: '', nodeViews, isPanelMode: () => false })
  editor = new Editor(kit.options)
  kit.attach(editor)
  installBridge()
  bindApi(kit.api)
  const view = render(<EditorViewport editor={editor} />)
  page = view.container.querySelector<HTMLElement>('.md-page')!
  act(() => {
    window.MoodiaryBridge.setContent(JSON.stringify(doc([p('Diary body')])))
    window.MoodiaryBridge.setTitle('Diary title')
    window.MoodiaryBridge.setEditable(false)
  })
})

afterEach(() => {
  cancelChange()
  cleanup()
  editor.destroy()
  resetBridgeForTest()
  metaStore.setState({ meta: undefined, links: null })
  modeStore.setState({ editable: true, panelMode: false })
  titleStore.setState({ title: '' })
})

describe('initial metadata reveal', () => {
  it('keeps the mounted title and body hidden before the first setMeta', () => {
    expect(metaStore.getState().meta).toBeUndefined()
    expect(getComputedStyle(page).visibility).toBe('hidden')
    expect(getComputedStyle(page).display).not.toBe('none')
    expect(page.querySelector<HTMLTextAreaElement>('.md-title')!.value).toBe('Diary title')
    expect(page.querySelector('.md-editor')!.textContent).toContain('Diary body')
  })

  it('reveals hosts without a header after setMeta(\'\')', () => {
    act(() => window.MoodiaryBridge.setMeta(''))
    expect(metaStore.getState().meta).toBeNull()
    expect(getComputedStyle(page).visibility).toBe('visible')
    expect(page.querySelector('.md-meta')).toBeNull()
    expect(screen.getByText('Diary body')).toBeTruthy()
  })

  it('reveals the complete header with the page and keeps applying later metadata', () => {
    act(() => window.MoodiaryBridge.setMeta(JSON.stringify(meta)))
    expect(getComputedStyle(page).visibility).toBe('visible')
    expect(screen.getByText(meta.dateText)).toBeTruthy()
    expect(screen.getByText('Travel')).toBeTruthy()
    expect(screen.getByText('Home')).toBeTruthy()
    expect(screen.getByText('Diary body')).toBeTruthy()
    expect(page.querySelector<HTMLTextAreaElement>('.md-title')!.value).toBe('Diary title')

    act(() => window.MoodiaryBridge.setMeta(JSON.stringify({ ...meta, category: 'Trips', position: 'Park' })))
    expect(getComputedStyle(page).visibility).toBe('visible')
    expect(screen.getByText('Trips')).toBeTruthy()
    expect(screen.getByText('Park')).toBeTruthy()
    expect(screen.queryByText('Travel')).toBeNull()
  })
})
