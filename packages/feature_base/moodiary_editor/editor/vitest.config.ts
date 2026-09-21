import { fileURLToPath } from 'node:url'
import vue from '@vitejs/plugin-vue'
import VueI18nPlugin from '@intlify/unplugin-vue-i18n/vite'
import Icons from 'unplugin-icons/vite'
import { defineConfig } from 'vitest/config'

export default defineConfig({
  plugins: [vue(), VueI18nPlugin({ include: fileURLToPath(new URL('../../../../i18n/web/**', import.meta.url)) }), Icons({ compiler: 'vue3' })],
  test: {
    environment: 'jsdom',
    setupFiles: ['src/test/setup.ts'],
  },
})
