// Subject colour-coding for the Kelas hub (web) — mirrors the Flutter
// `class_hub_theme.dart` so a subject reads as the SAME colour on the list card
// and the hub header, and (bonus) the same hue on both platforms.
//
// The colour is a DETERMINISTIC hash of the subject key (name) mapped onto the
// hue wheel: a subject is always the same colour (list ↔ detail continuity from
// a single card, no full-list dependency), and different subjects get different
// hues (360 of them, so collisions are rare for a realistic subject count).

/** Deep-navy overview accent for a general (all-subjects) card / hub. */
export const CLASS_HUB_GENERAL_ACCENT = '#1e4a8c';

// Matches Dart's `(h * 31 + code) & 0x7fffffff`. `% 0x80000000` keeps the low
// 31 bits as a JS double (values stay < 2^53), so we avoid JS's 32-bit `&`
// truncation and reproduce the Flutter hash exactly.
function stableHash(s: string): number {
  let h = 0;
  for (let i = 0; i < s.length; i++) {
    h = (h * 31 + s.charCodeAt(i)) % 0x80000000;
  }
  return h;
}

function hslToRgb(h: number, s: number, l: number): [number, number, number] {
  const c = (1 - Math.abs(2 * l - 1)) * s;
  const hp = h / 60;
  const x = c * (1 - Math.abs((hp % 2) - 1));
  let r = 0;
  let g = 0;
  let b = 0;
  if (hp < 1) [r, g, b] = [c, x, 0];
  else if (hp < 2) [r, g, b] = [x, c, 0];
  else if (hp < 3) [r, g, b] = [0, c, x];
  else if (hp < 4) [r, g, b] = [0, x, c];
  else if (hp < 5) [r, g, b] = [x, 0, c];
  else [r, g, b] = [c, 0, x];
  const m = l - c / 2;
  return [
    Math.round((r + m) * 255),
    Math.round((g + m) * 255),
    Math.round((b + m) * 255),
  ];
}

function toHex([r, g, b]: [number, number, number]): string {
  const h = (n: number) => n.toString(16).padStart(2, '0');
  return `#${h(r)}${h(g)}${h(b)}`;
}

function hexToRgb(hex: string): [number, number, number] {
  return [
    parseInt(hex.slice(1, 3), 16),
    parseInt(hex.slice(3, 5), 16),
    parseInt(hex.slice(5, 7), 16),
  ];
}

function lerp(a: number, b: number, t: number): number {
  return Math.round(a + (b - a) * t);
}

/** Deterministic vivid accent hex for a subject (by name/key). */
export function subjectAccentColor(key: string): string {
  const hue = stableHash(key) % 360;
  return toHex(hslToRgb(hue, 0.62, 0.46));
}

/** Accent hex for a class card / hub — null key = general navy overview. */
export function classHubAccent(subjectKey: string | null): string {
  return subjectKey ? subjectAccentColor(subjectKey) : CLASS_HUB_GENERAL_ACCENT;
}

/**
 * Diagonal hero-gradient CSS for a class card / hub. The dark stop is the base
 * lerped 52% toward deep navy (0B1A2E), matching the Flutter `heroGradient`.
 */
export function classHubGradientCss(subjectKey: string | null): string {
  const base = classHubAccent(subjectKey);
  const [r, g, b] = hexToRgb(base);
  const dark = toHex([
    lerp(r, 0x0b, 0.52),
    lerp(g, 0x1a, 0.52),
    lerp(b, 0x2e, 0.52),
  ]);
  return `linear-gradient(135deg, ${dark} 0%, ${base} 100%)`;
}
