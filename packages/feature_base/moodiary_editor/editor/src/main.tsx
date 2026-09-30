import { createRoot } from 'react-dom/client'
import App from './App'
import { readBoot } from './bridge/boot'
import { setLocale } from './i18n'
import './styles/moodiary-editor.css'

setLocale(readBoot().locale)
createRoot(document.getElementById('app')!).render(<App />)
