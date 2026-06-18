// @ts-check
import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';
import tailwindcss from '@tailwindcss/vite';

// https://astro.build/config
export default defineConfig({
  // Used for canonical URLs and the generated sitemap.
  site: 'https://minimatod.com',
  integrations: [sitemap()],
  vite: {
    // Cast avoids a harmless type clash between the Vite versions resolved by
    // @tailwindcss/vite and Astro. Runtime/build are unaffected.
    plugins: [/** @type {any} */ (tailwindcss())],
  },
});
