import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import tailwindcss from '@tailwindcss/vite'
import Icons from 'unplugin-icons/vite'
import { viteSingleFile } from 'vite-plugin-singlefile'

export default defineConfig({
  // 生产编辑器（moodiary-editor.css）与 dev harness（dev/harness.css）都 `@import 'tailwindcss'`，
  // 故 Tailwind v4 + daisyUI 进生产产物（编辑器外观）—— 仅 tree-shake 后用到的工具类/组件 + 自定义主题。
  // unplugin-icons：`import X from '~icons/material-symbols/...'` 按需把单个 Material Symbols 图标编译成
  // 内联 SVG Vue 组件 —— 只打包用到的图标（天然 tree-shake）、离线、无运行时/CDN。图标数据来自
  // devDep @iconify-json/material-symbols（不进产物）。
  plugins: [vue(), Icons({ compiler: 'vue3' }), tailwindcss(), viteSingleFile()],
  base: './',
  build: {
    // 整个编辑器（TipTap + 样式）内联进单个 index.html。不再有 Vditor 运行时同级资源：
    // TipTap 无 WASM 解析器，markdown 走 tiptap-markdown，全部打进 bundle，零额外静态文件。
    outDir: '../assets/editor',
    emptyOutDir: true,
    target: 'es2019',
    assetsDir: '.',
    cssCodeSplit: false,
    assetsInlineLimit: 100 * 1024 * 1024,
    chunkSizeWarningLimit: 8000,
    reportCompressedSize: false,
  },
})
