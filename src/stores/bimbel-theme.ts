/**
 * Bimbel (tutoring) appearance store — controls light/dark/auto for
 * every tutor surface in the BIMBEL tenant.
 *
 * Mirrors the Flutter mobile store at
 * `lib/features/tutoring/presentation/theme/tutoring_theme_mode.dart`,
 * adapted to Pinia. Three modes:
 *
 *   - `auto`  : flip based on local time-of-day (default — new users
 *               get the time-aware switch out of the box).
 *   - `light` : force `bimbel-light` always.
 *   - `dark`  : force `bimbel-dark` always.
 *
 * `auto` consumes the configured light/dark start times (defaults
 * 06:00 / 18:30) against the local clock. A 60s tick in
 * `startAutoTick()` re-evaluates `_now` so the flip happens within a
 * minute of crossing the boundary while the tab is foregrounded.
 *
 * The whole point is `rootClass`: it returns `'bimbel-dark'` or
 * `'bimbel-light'` and is what AppShell (and any future page root)
 * applies to swap the surface CSS variables defined in `style.css`.
 */
import { defineStore } from 'pinia';

export type BimbelThemeMode = 'auto' | 'light' | 'dark';

const STORAGE_KEY = 'bimbel.theme.mode';
const LIGHT_HOUR_KEY = 'bimbel.theme.lightStartHour';
const DARK_HOUR_KEY = 'bimbel.theme.darkStartHour';
const DARK_MINUTE_KEY = 'bimbel.theme.darkStartMinute';

function readMode(): BimbelThemeMode {
  const raw = typeof localStorage !== 'undefined'
    ? localStorage.getItem(STORAGE_KEY)
    : null;
  return raw === 'light' || raw === 'dark' || raw === 'auto' ? raw : 'auto';
}

function readInt(key: string, fallback: number): number {
  if (typeof localStorage === 'undefined') return fallback;
  const raw = localStorage.getItem(key);
  if (raw == null) return fallback;
  const n = Number.parseInt(raw, 10);
  return Number.isFinite(n) ? n : fallback;
}

interface BimbelThemeState {
  mode: BimbelThemeMode;
  /** Minutes-of-hour 0–23 when light kicks in (default 06:00). */
  lightStartHour: number;
  /** Hour when dark kicks in (default 18). */
  darkStartHour: number;
  /** Minute component for darkStart (default 30 → 18:30). */
  darkStartMinute: number;
  /** Re-read so the `isDark` getter recomputes on the 60s tick. */
  _now: number;
  /** setInterval id when auto-tick is active (window.setInterval). */
  _tickId: number | null;
}

export const useBimbelThemeStore = defineStore('bimbelTheme', {
  state: (): BimbelThemeState => ({
    mode: readMode(),
    lightStartHour: readInt(LIGHT_HOUR_KEY, 6),
    darkStartHour: readInt(DARK_HOUR_KEY, 18),
    darkStartMinute: readInt(DARK_MINUTE_KEY, 30),
    _now: Date.now(),
    _tickId: null,
  }),
  getters: {
    /** True when the surface should render in dark mode right now. */
    isDark(state): boolean {
      if (state.mode === 'dark') return true;
      if (state.mode === 'light') return false;
      // auto: clock-based — `_now` is in state so this getter is
      // properly reactive to the 60s tick.
      const d = new Date(state._now);
      const cur = d.getHours() * 60 + d.getMinutes();
      const lightStart = state.lightStartHour * 60;
      const darkStart = state.darkStartHour * 60 + state.darkStartMinute;
      // Two windows: [lightStart, darkStart) is light; everything else
      // is dark. Handles inverted configs (e.g. someone sets darkStart
      // earlier than lightStart) by treating the light window as the
      // contiguous range wrapping past midnight.
      if (lightStart < darkStart) {
        return cur < lightStart || cur >= darkStart;
      }
      return cur < lightStart && cur >= darkStart;
    },
    isLight(): boolean {
      return !this.isDark;
    },
    /** Class name to apply on the page / shell root. Always one of two. */
    rootClass(): string {
      return this.isDark ? 'bimbel-dark' : 'bimbel-light';
    },
    /**
     * Human label for the auto-mode hint chip, e.g.
     * "Sekarang terang · ganti otomatis ke gelap jam 18:30".
     * Returns null when not in auto mode.
     */
    autoHint(state): string | null {
      if (state.mode !== 'auto') return null;
      const dark = this.isDark;
      const now = dark ? 'gelap' : 'terang';
      const next = dark ? 'terang' : 'gelap';
      const h = dark
        ? state.lightStartHour
        : state.darkStartHour;
      const m = dark ? 0 : state.darkStartMinute;
      const hh = String(h).padStart(2, '0');
      const mm = String(m).padStart(2, '0');
      return `Sekarang ${now} · ganti otomatis ke ${next} jam ${hh}:${mm}`;
    },
  },
  actions: {
    setMode(m: BimbelThemeMode) {
      this.mode = m;
      try { localStorage.setItem(STORAGE_KEY, m); } catch {/* private mode */}
      // Re-read the clock immediately so the surface flips on the same
      // frame the user taps the tile, instead of waiting for the tick.
      this._now = Date.now();
    },
    setLightStartHour(h: number) {
      const v = Math.max(0, Math.min(23, Math.round(h)));
      this.lightStartHour = v;
      try { localStorage.setItem(LIGHT_HOUR_KEY, String(v)); } catch {/* */}
      this._now = Date.now();
    },
    setDarkStart(hour: number, minute: number) {
      const h = Math.max(0, Math.min(23, Math.round(hour)));
      const mm = Math.max(0, Math.min(59, Math.round(minute)));
      this.darkStartHour = h;
      this.darkStartMinute = mm;
      try {
        localStorage.setItem(DARK_HOUR_KEY, String(h));
        localStorage.setItem(DARK_MINUTE_KEY, String(mm));
      } catch {/* */}
      this._now = Date.now();
    },
    /**
     * Schedule a 60s tick so `auto` mode flips within a minute of
     * crossing the cutoff. Safe to call multiple times — only one
     * interval is ever installed. Call from `App.vue` onMounted.
     */
    startAutoTick() {
      if (this._tickId !== null) return;
      if (typeof window === 'undefined') return;
      this._tickId = window.setInterval(() => {
        this._now = Date.now();
      }, 60_000);
    },
    stopAutoTick() {
      if (this._tickId !== null && typeof window !== 'undefined') {
        window.clearInterval(this._tickId);
      }
      this._tickId = null;
    },
  },
});
