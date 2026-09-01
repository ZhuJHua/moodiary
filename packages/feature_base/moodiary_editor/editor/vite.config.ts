import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import tailwindcss from '@tailwindcss/vite'
import Icons from 'unplugin-icons/vite'
import { compression, defineAlgorithm } from 'vite-plugin-compression2'
import license from 'rollup-plugin-license'

export default defineConfig({
  // 生产编辑器（moodiary-editor.css）与 dev harness（dev/harness.css）都 `@import 'tailwindcss'`，
  // 故 Tailwind v4 + daisyUI 进生产产物（编辑器外观）—— 仅 tree-shake 后用到的工具类/组件 + 自定义主题。
  // unplugin-icons：`import X from '~icons/lucide/...'` 按需把单个 lucide 图标编译成
  // 内联 SVG Vue 组件 —— 只打包用到的图标（天然 tree-shake）、离线、无运行时/CDN。图标数据来自
  // devDep @iconify-json/lucide（不进产物）。与 Dart 侧的 lucide_icons_flutter 同一套图标，
  // 不走官方 @lucide/vue：那个是运行时组件工厂（每个图标多一层组件 + computed），
  // 且 barrel 会把 vite 模块图从 458 撑到 2195。
  plugins: [
    vue(),
    Icons({ compiler: 'vue3' }),
    tailwindcss(),
    // 第三方署名：只统计**真正进了 bundle** 的模块（不是全部 prod 依赖），连同许可证全文
    // 写成 JSON 交给 `dart tool/task.dart licenses` 合并进 App 的开源许可页。
    // 输出落在 gitignore 的 build/ 里，不能进 outDir —— 那里的东西会被打包并由本地服务发出去。
    license({
      thirdParty: {
        includePrivate: false,
        output: {
          file: 'build/third-party-licenses.json',
          template: (dependencies) => JSON.stringify(dependencies, null, 2),
        },
      },
    }),
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
