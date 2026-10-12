import { fileURLToPath } from 'node:url'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import license from 'rollup-plugin-license'
import { viteSingleFile } from 'vite-plugin-singlefile'

export default defineConfig({
  plugins: [
    react(),
    tailwindcss(),
    license({
      thirdParty: {
        includePrivate: false,
        output: {
          file: 'build/third-party-licenses.json',
          template: (dependencies) => JSON.stringify(dependencies, null, 2),
        },
      },
    }),
    // file:// 页面加载外链 module 会被当作跨域拒掉，所以 JS、CSS、字体全内联进 index.html
    viteSingleFile(),
  ],
  resolve: {
    alias: { '@': fileURLToPath(new URL('./src', import.meta.url)) },
  },
  build: {
    outDir: '../assets/editor',
    emptyOutDir: true,
    target: 'es2022',
    modulePreload: { polyfill: false },
    reportCompressedSize: false,
  },
})
