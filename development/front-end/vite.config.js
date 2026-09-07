import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    // WHY this proxy exists:
    // The React dev server runs on :5173, FastAPI on :8000. Different ports =
    // different ORIGINS, so the browser would block the call (CORS).
    // This proxy makes the dev server itself forward any request starting with
    // /api to :8000. From the browser's point of view everything comes from
    // :5173, so there is no cross-origin request at all.
    //
    // The bonus: our React code only ever writes fetch('/api/products') with no
    // hostname. In production nginx does the same forwarding. Same code, no
    // environment-specific URLs anywhere.
    proxy: {
      '/api': { target: 'http://localhost:8000', changeOrigin: true },
      '/health': { target: 'http://localhost:8000', changeOrigin: true },
    },
  },
})
