import { createRoot } from 'react-dom/client'
import App from '@/shell/EditorShell'
import { readBoot } from '@/core/bridge/boot'
import { setLocale } from '@/core/i18n'
import '@/styles/moodiary-editor.css'

setLocale(readBoot().locale)
createRoot(document.getElementById('app')!).render(<App />)
