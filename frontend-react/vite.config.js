import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  // Vitest's own esbuild pre-transform doesn't always pick up the React plugin's JSX
  // handling, so without this it falls back to the classic runtime (expects a global
  // `React` in scope) and every .jsx file under test fails with "React is not defined".
  esbuild: {
    jsx: 'automatic',
  },
  test: {
    environment: 'jsdom',
    setupFiles: './src/test/setup.js',
    globals: true,
  },
})
