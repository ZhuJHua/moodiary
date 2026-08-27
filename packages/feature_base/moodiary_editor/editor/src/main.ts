import { createApp } from 'vue'
import App from './App.vue'
// 编辑器样式（Tailwind v4 + daisyUI 外观 + TipTap/ProseMirror 正文 + --app-* 配色映射，内联进单文件壳）。
import './styles/moodiary-editor.css'

createApp(App).mount('#app')
