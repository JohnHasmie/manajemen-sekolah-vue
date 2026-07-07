import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';
import { fileURLToPath, URL } from 'node:url';

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
  server: {
    port: 5173,
    host: true,
  },
  build: {
    // Round-9 audit: explicit for clarity. Vite defaults to false in
    // prod anyway, but a future contributor who flips this to true for
    // debugging would ship the original TS source (with API contracts,
    // route names, business-rule constants) to any browser user. Keep
    // it locked off; flip via a dedicated debug build if truly needed.
    sourcemap: false,
  },
});
