import { defineConfig } from 'vite';

// The page and Porter share an origin, as they will once deployed (ADR 0005).
export default defineConfig({
  server: { proxy: { '/porter': { target: 'http://localhost:3000', ws: true } } },
});
