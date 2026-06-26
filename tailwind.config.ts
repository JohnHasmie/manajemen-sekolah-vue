import type { Config } from 'tailwindcss';

// Color palette mirrors lib/core/utils/color_utils.dart.
//
// Role colors:
//   admin   → navy   (#1E3A8A)
//   teacher → teal   (#0D9488)
//   parent  → violet (#7C3AED)
//   staff   → amber  (#B45309)
//
// Brand primary (indigo) matches ColorUtils.primaryColor (#4F46E5).
// Slate scale matches Tailwind's slate-50…slate-900 (the Flutter app
// already aligns to this scale per the README).

const config: Config = {
  content: ['./index.html', './src/**/*.{vue,ts,tsx}'],
  // Drive Tailwind's `dark:` variant from the same `.tutoring-dark`
  // wrapper class that useTutoringThemeStore applies to AppShell. The
  // default (`media`) hard-binds to the OS theme, which made
  // `dark:text-emerald-300` & friends activate at night even when the
  // user explicitly picked "Terang" — light mode looked broken. With
  // the selector tied to .tutoring-dark, every `dark:` in the project
  // now follows the in-app picker.
  darkMode: ['selector', '.tutoring-dark'],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Poppins', 'ui-sans-serif', 'system-ui', 'sans-serif'],
      },
      colors: {
        brand: {
          DEFAULT: '#4F46E5', // indigo-600 — ColorUtils.primaryColor
          50: '#EEF2FF',
          100: '#E0E7FF',
          500: '#6366F1',
          600: '#4F46E5',
          700: '#4338CA',
          // official brand palette from lib/core/utils/color_utils.dart
          'dark-blue': '#143068',
          'cobalt': '#1B6FB8',
          'azure': '#21AFE6',
          'azure-deep': '#1A8FBE',
        },
        role: {
          admin: '#143068', // Brand Dark Blue
          'admin-soft': '#E8EEF7',
          teacher: '#1B6FB8', // Brand Cobalt
          'teacher-soft': '#E6F7FD',
          parent: '#21AFE6', // Brand Azure
          'parent-soft': '#F0F9FF',
          wali: '#21AFE6', // Alias of parent — Flutter uses the `wali` role key.
          'wali-soft': '#F0F9FF',
          staff: '#B45309',
          'staff-soft': '#FEF3C7',
        },
        status: {
          success: '#10B981',
          'success-soft': '#D1FAE5',
          warning: '#F59E0B',
          'warning-soft': '#FEF3C7',
          danger: '#EF4444',
          'danger-soft': '#FEE2E2',
          info: '#06B6D4',
          'info-soft': '#CFFAFE',
        },
        // Bimbel surface tokens — mirror the mobile AdminPalette /
        // TutorPalette / ParentPalette and now resolve through CSS
        // variables. `--bimbel-*` defaults to DARK values in style.css
        // (preserves existing behavior); the `.bimbel-light` wrapper
        // class flips the surface tokens to a light palette without
        // touching the per-role `--bimbel-hero` / `--bimbel-accent` /
        // `--bimbel-accent-soft` vars (those stay brand-identity).
        //
        // Status colors (green / amber / red) stay constant — they
        // read on both light and dark surfaces and double as semantic
        // tone tokens shared with the mobile palette.
        bimbel: {
          bg: 'var(--bimbel-bg)',
          panel: 'var(--bimbel-panel)',
          'panel-navy': 'var(--bimbel-panel-navy)',
          border: 'var(--bimbel-border)',
          'border-soft': 'var(--bimbel-border-soft)',
          'text-hi': 'var(--bimbel-text-hi)',
          'text-mid': 'var(--bimbel-text-mid)',
          'text-lo': 'var(--bimbel-text-lo)',
          ring: 'var(--bimbel-ring)',
          hero: 'var(--bimbel-hero)',
          accent: 'var(--bimbel-accent)',
          'accent-soft': 'var(--bimbel-accent-soft)',
          'accent-dim': 'color-mix(in srgb, var(--bimbel-accent) 16%, transparent)',
          green: '#4ADE80',
          amber: '#FBBF24',
          red: '#F87171',
          'green-dim': 'color-mix(in srgb, #4ADE80 16%, transparent)',
          'amber-dim': 'color-mix(in srgb, #FBBF24 16%, transparent)',
          'red-dim': 'color-mix(in srgb, #F87171 14%, transparent)',
          'grey-dim': 'color-mix(in srgb, #64748B 20%, transparent)',
        },
      },
      spacing: {
        // AppSpacing.xs/sm/md/lg/xl → tailwind tokens
        'xs': '4px',
        'sm': '8px',
        'md': '16px',
        'lg': '24px',
        'xl': '32px',
      },
      boxShadow: {
        card: '0 1px 2px 0 rgb(0 0 0 / 0.04), 0 4px 16px -2px rgb(0 0 0 / 0.06)',
        sheet: '0 -8px 24px -4px rgb(0 0 0 / 0.08)',
        'lifted-logo': '0 12px 24px 0 rgb(15 23 42 / 0.18), 0 2px 6px 0 rgb(15 23 42 / 0.10)',
      },
      borderRadius: {
        card: '16px',
        sheet: '20px',
        'form-card': '22px',
        'logo-card': '28%', // matches size * 0.28
      },
      backgroundImage: {
        'brand-gradient':
          'linear-gradient(135deg, #143068 0%, #1B6FB8 60%, #21AFE6 110%)',
      },
    },
  },
  plugins: [],
};

export default config;
