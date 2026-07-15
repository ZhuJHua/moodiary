import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import tailwindcss from '@tailwindcss/vite'
import Icons from 'unplugin-icons/vite'
import { compression, defineAlgorithm } from 'vite-plugin-compression2'

export default defineConfig({
  // 生产编辑器（moodiary-editor.css）与 dev harness（dev/harness.css）都 `@import 'tailwindcss'`，
  // 故 Tailwind v4 + daisyUI 进生产产物（编辑器外观）—— 仅 tree-shake 后用到的工具类/组件 + 自定义主题。
  // unplugin-icons：`import X from '~icons/material-symbols/...'` 按需把单个 Material Symbols 图标编译成
  // 内联 SVG Vue 组件 —— 只打包用到的图标（天然 tree-shake）、离线、无运行时/CDN。图标数据来自
  // devDep @iconify-json/material-symbols（不进产物）。
  plugins: [
    vue(),
    Icons({ compiler: 'vue3' }),
    tailwindcss(),
    // 每个资源 gzip 预压缩为 .gz 并删原文件；运行时 EditorLocalServer 解压后发明文。
    compression({
      algorithms: [defineAlgorithm('gzip', { level: 9 })],
      deleteOriginalAssets: true,
    }),
  ],
  base: './',
  build: {
    outDir: '../assets/editor',
    emptyOutDir: true,
    target: 'es2019',
    cssCodeSplit: false,
    reportCompressedSize: false,
    rollupOptions: {
      // 平铺到 outDir 根、文件名不带 hash：Flutter `assets:` 目录非递归，子目录不会被打包（→404）。
      output: {
        entryFileNames: '[name].js',
        chunkFileNames: '[name].js',
        assetFileNames: '[name][extname]',
      },
    },
  },
})
