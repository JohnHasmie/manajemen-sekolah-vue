/**
 * Format helpers — Indonesian-locale formatting.
 *
 * Mirrors `lib/utils/currency_formatter.dart` + `lib/utils/date_utils.dart`
 * from the Flutter app.
 */

const RUPIAH = new Intl.NumberFormat('id-ID', {
  style: 'currency',
  currency: 'IDR',
  minimumFractionDigits: 0,
  maximumFractionDigits: 0,
});

const NUMBER = new Intl.NumberFormat('id-ID');

const DATE_LONG = new Intl.DateTimeFormat('id-ID', {
  weekday: 'long',
  year: 'numeric',
  month: 'long',
  day: 'numeric',
});

const DATE_SHORT = new Intl.DateTimeFormat('id-ID', {
  year: 'numeric',
  month: 'short',
  day: 'numeric',
});

const DATE_TIME = new Intl.DateTimeFormat('id-ID', {
  year: 'numeric',
  month: 'short',
  day: 'numeric',
  hour: '2-digit',
  minute: '2-digit',
});

const TIME_ONLY = new Intl.DateTimeFormat('id-ID', {
  hour: '2-digit',
  minute: '2-digit',
});

export function formatRupiah(value: number | string | null | undefined): string {
  if (value === null || value === undefined || value === '') return 'Rp 0';
  const n = typeof value === 'string' ? Number(value) : value;
  if (Number.isNaN(n)) return 'Rp 0';
  return RUPIAH.format(n);
}

export function formatNumber(value: number | null | undefined): string {
  if (value === null || value === undefined) return '0';
  return NUMBER.format(value);
}

export function formatDateLong(value: Date | string | null | undefined): string {
  if (!value) return '';
  const d = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(d.getTime())) return '';
  return DATE_LONG.format(d);
}

export function formatDateShort(value: Date | string | null | undefined): string {
  if (!value) return '';
  const d = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(d.getTime())) return '';
  return DATE_SHORT.format(d);
}

export function formatDateTime(value: Date | string | null | undefined): string {
  if (!value) return '';
  const d = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(d.getTime())) return '';
  return DATE_TIME.format(d);
}

export function formatTime(value: Date | string | null | undefined): string {
  if (!value) return '';
  const d = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(d.getTime())) return '';
  return TIME_ONLY.format(d);
}

/** Relative time: "2 jam lalu", "kemarin", "5 hari lalu". */
export function formatRelative(value: Date | string | null | undefined): string {
  if (!value) return '';
  const d = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(d.getTime())) return '';

  const diffMs = Date.now() - d.getTime();
  const min = Math.round(diffMs / 60_000);
  const hr = Math.round(diffMs / 3_600_000);
  const day = Math.round(diffMs / 86_400_000);

  if (Math.abs(min) < 1) return 'Baru saja';
  if (Math.abs(min) < 60) return `${min} menit lalu`;
  if (Math.abs(hr) < 24) return `${hr} jam lalu`;
  if (day === 1) return 'Kemarin';
  if (day < 7) return `${day} hari lalu`;
  return formatDateShort(d);
}
