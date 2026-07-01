/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_API_URL: string;
  readonly VITE_AI_API_URL: string;
  readonly VITE_GOOGLE_CLIENT_ID?: string;
  readonly VITE_WHATSAPP_SUPPORT?: string;
  /**
   * Midtrans Snap client key (sandbox or production, per environment).
   * Used by the /subscribe page to inject the Snap JS SDK on demand.
   * When empty, the page still works via the manual bank-transfer path.
   */
  readonly VITE_MIDTRANS_CLIENT_KEY?: string;
  // Laravel Reverb (realtime notifications). All optional: when
  // VITE_REVERB_APP_KEY is empty the Echo client stays inert and the
  // app falls back to polling only.
  readonly VITE_REVERB_APP_KEY?: string;
  readonly VITE_REVERB_HOST?: string;
  readonly VITE_REVERB_PORT?: string;
  readonly VITE_REVERB_SCHEME?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}

declare module '*.vue' {
  import type { DefineComponent } from 'vue';
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const component: DefineComponent<{}, {}, any>;
  export default component;
}
