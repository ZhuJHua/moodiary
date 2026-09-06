import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import tailwindcss from '@tailwindcss/vite'
import Icons from 'unplugin-icons/vite'
import { compression, defineAlgorithm } from 'vite-plugin-compression2'
import license from 'rollup-plugin-license'

export default defineConfig({
  plugins: [
    vue(),
    Icons({ compiler: 'vue3' }),
    tailwindcss(),
    // build/ 不能改到 outDir —— 那里的东西会被打包并由本地服务发出去
    license({
      thirdParty: {
        includePrivate: false,
        output: {
          file: 'build/third-party-licenses.json',
          template: (dependencies) => JSON.stringify(dependencies, null, 2),
        },
      },
    }),
    // 运行时 EditorLocalServer 解压后发明文
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
      // Flutter assets: 目录非递归，子目录不会被打包（→404），故需平铺、不带 hash
      output: {
        entryFileNames: '[name].js',
        chunkFileNames: '[name].js',
        assetFileNames: '[name][extname]',
      },
    },
  },
})
