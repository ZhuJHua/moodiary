import { createApp } from 'vue'
import App from './App.vue'
import { readBoot } from './bridge/boot'
import { i18n, setLocale } from './i18n'
import './styles/moodiary-editor.css'

setLocale(readBoot().locale)
createApp(App).use(i18n).mount('#app')
