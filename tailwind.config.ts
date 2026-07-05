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
      // ADDITIVE sub-12px font-size scale.
      //
      // Placed under `theme.extend`, so these MERGE with Tailwind's
      // default fontSize scale — `xs` (12px), `sm` (14px), `base` (16px),
      // etc. are UNTOUCHED. Only the new, non-colliding keys below are
      // added. The web has thousands of arbitrary `text-[Npx]` values
      // below 12px with no scale; these name the most common exact sizes
      // so they can be migrated 1:1 (identical rendering).
      //
      // Naming continues Tailwind's ordinal convention downward from
      // `xs` (the smallest default, 12px):
      //   2xs → 11px   (~620 arbitrary uses)
      //   3xs → 10px   (~677 arbitrary uses)
      //   4xs →  9px   (~126 arbitrary uses)
      // The lineHeight is set to 1 (unitless) to match a bare
      // `text-[Npx]` utility, which sets font-size only and leaves
      // line-height inherited — Tailwind's arbitrary font-size values do
      // NOT inject a line-height, so we must not either. (A tuple
      // `[size, lineHeight]` would emit `line-height`, changing layout.)
      //
      // Fractional sizes still in the wild (10.5px ~147, 11.5px ~94,
      // 9.5px ~60, 12.5px ~121) are intentionally NOT tokenized here —
      // decimal Tailwind keys read poorly and those stay `text-[Npx]`.
      fontSize: {
        '2xs': '11px',
        '3xs': '10px',
        '4xs': '9px',
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
        // Tutoring surface tokens — mirror the mobile AdminPalette /
        // TutorPalette / ParentPalette and now resolve through CSS
        // variables. `--tutoring-*` defaults to DARK values in style.css
        // (preserves existing behavior); the `.tutoring-light` wrapper
        // class flips the surface tokens to a light palette without
        // touching the per-role `--tutoring-hero` / `--tutoring-accent` /
        // `--tutoring-accent-soft` vars (those stay brand-identity).
        //
        // Status colors (green / amber / red) stay constant — they
        // read on both light and dark surfaces and double as semantic
        // tone tokens shared with the mobile palette.
        tutoring: {
          bg: 'var(--tutoring-bg)',
          panel: 'var(--tutoring-panel)',
          'panel-navy': 'var(--tutoring-panel-navy)',
          border: 'var(--tutoring-border)',
          'border-soft': 'var(--tutoring-border-soft)',
          'text-hi': 'var(--tutoring-text-hi)',
          'text-mid': 'var(--tutoring-text-mid)',
          'text-lo': 'var(--tutoring-text-lo)',
          ring: 'var(--tutoring-ring)',
          hero: 'var(--tutoring-hero)',
          accent: 'var(--tutoring-accent)',
          'accent-soft': 'var(--tutoring-accent-soft)',
          'accent-dim': 'color-mix(in srgb, var(--tutoring-accent) 16%, transparent)',
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
        // Role hero gradients for BrandPageHeader (layout/BrandPageHeader.vue).
        // Each stop is the EXACT literal previously hardcoded in that
        // component's `palette`/`gradientStyle` computed props:
        //   dark stop  ← per-role `darkStop` switch
        //   mid/end    ← `getRoleColor(role).hex` (composables/useRoleColor.ts)
        // Angle 120deg + stop positions 0%/60%/100% are unchanged, so the
        // rendered gradient is pixel-identical to the old inline style.
        //
        //   role-admin-gradient   → admin              (dark #0A1F4D · navy   #143068)
        //   role-teacher-gradient → guru / wali_kelas  (dark #0F2A45 · cobalt #1B6FB8)
        //   role-parent-gradient  → wali (parent)      (dark #0B5677 · azure  #21AFE6)
        //   role-staff-gradient   → staff              (dark #5E2D04 · amber  #B45309)
        // NOTE: super_admin keeps the admin navy hex but the *default* dark
        // stop (#0F2A45), so it uses `role-superadmin-gradient` below — it is
        // NOT the same gradient as `role-admin-gradient`.
        'role-admin-gradient':
          'linear-gradient(120deg, #0A1F4D 0%, #143068 60%, #143068 100%)',
        'role-teacher-gradient':
          'linear-gradient(120deg, #0F2A45 0%, #1B6FB8 60%, #1B6FB8 100%)',
        'role-parent-gradient':
          'linear-gradient(120deg, #0B5677 0%, #21AFE6 60%, #21AFE6 100%)',
        'role-staff-gradient':
          'linear-gradient(120deg, #5E2D04 0%, #B45309 60%, #B45309 100%)',
        'role-superadmin-gradient':
          'linear-gradient(120deg, #0F2A45 0%, #143068 60%, #143068 100%)',
      },
    },
  },
  plugins: [],
};

export default config;
