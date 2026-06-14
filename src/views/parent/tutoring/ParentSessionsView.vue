<!--
  ParentSessionsView — wali Jadwal sesi list. Redesign: hero + subject
  filter chips + grouped-by-day session list (no search, no extra
  inner card chrome).
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { TutoringService } from '@/services/tutoring.service';
import { useChildPicker } from '@/composables/useChildPicker';
import type { TutoringSession } from '@/types/tutoring';

import ParentBerandaHero from '@/components/feature/tutoring/ParentBerandaHero.vue';
import ParentChildPickerChip from '@/components/feature/tutoring/ParentChildPickerChip.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const route = useRoute();
const { activeChildId } = useChildPicker();

const studentId = computed(() =>
  String(route.params.studentId || activeChildId.value || ''),
);

const loading = ref(true);
const sessions = ref<TutoringSession[]>([]);
const subjectFilter = ref<string>('all');
const view = ref<'list' | 'calendar'>('list');
// Month being browsed in calendar view; selected day to render the
// sessions list underneath the grid. Both default to today on first
// switch into calendar view.
const calMonth = ref<Date>(new Date());
const calSelected = ref<Date>(new Date());

function toggleView() {
  view.value = view.value === 'list' ? 'calendar' : 'list';
  if (view.value === 'calendar') {
    calMonth.value = new Date();
    calSelected.value = new Date();
  }
}

function shiftMonth(delta: number) {
  const d = new Date(calMonth.value);
  d.setDate(1);
  d.setMonth(d.getMonth() + delta);
  calMonth.value = d;
}

async function load() {
  const sid = studentId.value;
  if (!sid) { loading.value = false; return; }
  loading.value = true;
  const now = new Date();
  const from = new Date(now.getTime() - 30 * 86_400_000);
  const to = new Date(now.getTime() + 60 * 86_400_000);
  try {
    sessions.value = await TutoringService.getSchedule(sid, from, to);
  } catch {/* non-fatal */}
  finally { loading.value = false; }
}
onMounted(load);
watch(studentId, load);

// ── Helpers ─────────────────────────────────────────────────────
type WithMeta = TutoringSession & {
  subject?: string | null;
  group_code?: string | null;
  tutor_name?: string | null;
  attended?: boolean | null;
};

function sessionSubject(s: TutoringSession): string {
  const m = s as WithMeta;
  return m.subject ?? s.group?.program?.name ?? s.group?.name ?? '';
}

function timeOnly(iso?: string | null): string {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.valueOf())) return '—';
  return d.toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' });
}

function statusLabel(s: TutoringSession): string {
  const at = s.scheduled_at ? new Date(s.scheduled_at).valueOf() : 0;
  const isPast = at && at < Date.now();
  const attended = (s as WithMeta).attended;
  if (s.status === 'DONE' || (isPast && attended === true)) return 'Hadir';
  if (s.status === 'CANCELLED') return 'Batal';
  if (isPast && attended === false) return 'Tidak hadir';
  if (isPast) return s.status_label ?? 'Selesai';
  return 'Akan datang';
}

function statusPillCls(s: TutoringSession): string {
  const base = 'flex-shrink-0 rounded-full px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide';
  const at = s.scheduled_at ? new Date(s.scheduled_at).valueOf() : 0;
  const isPast = at && at < Date.now();
  const attended = (s as WithMeta).attended;
  if (s.status === 'DONE' || (isPast && attended === true)) return `${base} bg-bimbel-green-dim text-green-700`;
  if (s.status === 'CANCELLED' || (isPast && attended === false)) return `${base} bg-bimbel-red-dim text-red-700`;
  return `${base} bg-bimbel-accent-dim text-bimbel-hero`;
}

// ── Counts ──────────────────────────────────────────────────────
const weekCount = computed(() => {
  const now = new Date();
  const start = new Date(now);
  start.setDate(now.getDate() - now.getDay());
  start.setHours(0, 0, 0, 0);
  const end = new Date(start);
  end.setDate(start.getDate() + 7);
  return sessions.value.filter((s) => {
    if (!s.scheduled_at) return false;
    const d = new Date(s.scheduled_at);
    return d >= start && d < end;
  }).length;
});

const monthCount = computed(() => {
  const now = new Date();
  return sessions.value.filter((s) => {
    if (!s.scheduled_at) return false;
    const d = new Date(s.scheduled_at);
    return d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth();
  }).length;
});

// ── Subject chips ───────────────────────────────────────────────
const subjectChips = computed(() => {
  const seen = new Set<string>();
  const out: { id: string; label: string }[] = [{ id: 'all', label: 'Semua' }];
  for (const s of sessions.value) {
    const name = sessionSubject(s);
    if (name && !seen.has(name)) {
      seen.add(name);
      out.push({ id: name, label: name });
    }
  }
  return out;
});

// ── Filter + sort ───────────────────────────────────────────────
const visible = computed(() => {
  let list = [...sessions.value];
  if (subjectFilter.value !== 'all') {
    list = list.filter((s) => sessionSubject(s) === subjectFilter.value);
  }
  return list.sort((a, b) => {
    const ta = a.scheduled_at ? new Date(a.scheduled_at).valueOf() : 0;
    const tb = b.scheduled_at ? new Date(b.scheduled_at).valueOf() : 0;
    return ta - tb;
  });
});

// ── Group by day ────────────────────────────────────────────────
function dayLabel(d: Date): string {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const tomorrow = new Date(today);
  tomorrow.setDate(today.getDate() + 1);
  const dayStart = new Date(d);
  dayStart.setHours(0, 0, 0, 0);
  const dateLabel = d.toLocaleDateString('id-ID', {
    weekday: 'long',
    day: 'numeric',
    month: 'short',
  }).toUpperCase();
  if (dayStart.valueOf() === today.valueOf()) return `HARI INI · ${dateLabel}`;
  if (dayStart.valueOf() === tomorrow.valueOf()) return `BESOK · ${dateLabel}`;
  return dateLabel;
}

const grouped = computed(() => {
  const map = new Map<string, { label: string; items: TutoringSession[] }>();
  for (const s of visible.value) {
    if (!s.scheduled_at) continue;
    const d = new Date(s.scheduled_at);
    const key = `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`;
    let g = map.get(key);
    if (!g) {
      g = { label: dayLabel(d), items: [] };
      map.set(key, g);
    }
    g.items.push(s);
  }
  return Array.from(map.values());
});

// ── Calendar view helpers ───────────────────────────────────────
const MONTH_NAMES = ['Januari','Februari','Maret','April','Mei','Juni','Juli','Agustus','September','Oktober','November','Desember'];
const DOW_SHORT = ['Sen','Sel','Rab','Kam','Jum','Sab','Min'];

function dayKey(d: Date): string {
  return `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`;
}

// Sessions bucketed by dayKey for fast lookups in the calendar grid.
const sessionsByDay = computed(() => {
  const map = new Map<string, TutoringSession[]>();
  for (const s of visible.value) {
    if (!s.scheduled_at) continue;
    const d = new Date(s.scheduled_at);
    const k = dayKey(d);
    const list = map.get(k);
    if (list) list.push(s);
    else map.set(k, [s]);
  }
  return map;
});

const calMonthLabel = computed(() => {
  const d = calMonth.value;
  return `${MONTH_NAMES[d.getMonth()]} ${d.getFullYear()}`;
});

// Build a 6×7 grid (42 cells) starting from the Monday on/before the
// 1st of calMonth. Each cell knows its date + whether it's in the
// current month + how many sessions land that day.
const calCells = computed(() => {
  const first = new Date(calMonth.value.getFullYear(), calMonth.value.getMonth(), 1);
  // JS getDay: Sun=0..Sat=6 → we want Mon=0..Sun=6.
  const lead = (first.getDay() + 6) % 7;
  const start = new Date(first);
  start.setDate(first.getDate() - lead);
  const cells: { date: Date; inMonth: boolean; count: number; isToday: boolean; isSelected: boolean }[] = [];
  const today = new Date();
  const todayKey = dayKey(today);
  for (let i = 0; i < 42; i++) {
    const d = new Date(start);
    d.setDate(start.getDate() + i);
    cells.push({
      date: d,
      inMonth: d.getMonth() === calMonth.value.getMonth(),
      count: sessionsByDay.value.get(dayKey(d))?.length ?? 0,
      isToday: dayKey(d) === todayKey,
      isSelected: dayKey(d) === dayKey(calSelected.value),
    });
  }
  return cells;
});

const calSelectedLabel = computed(() => {
  const d = calSelected.value;
  return d.toLocaleDateString('id-ID', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' });
});

const calSelectedSessions = computed(() =>
  (sessionsByDay.value.get(dayKey(calSelected.value)) ?? []).sort((a, b) => {
    const ta = a.scheduled_at ? new Date(a.scheduled_at).valueOf() : 0;
    const tb = b.scheduled_at ? new Date(b.scheduled_at).valueOf() : 0;
    return ta - tb;
  }),
);

function selectDay(d: Date) {
  calSelected.value = new Date(d);
}
</script>

<template>
  <div class="space-y-3 pb-12">
    <ParentBerandaHero
      kicker="BIMBEL · JADWAL"
      title="Sesi mendatang"
      :subtitle="`${weekCount} sesi minggu ini · ${monthCount} bulan ini`"
      :stats="[]"
    >
      <template #actions>
        <ParentChildPickerChip />
        <button
          type="button"
          class="hidden sm:inline-flex items-center gap-1.5 rounded-lg bg-white text-bimbel-hero px-3 py-1.5 text-[13px] font-bold hover:bg-white/95"
          @click="toggleView"
        >
          <NavIcon :name="view === 'list' ? 'calendar' : 'list'" :size="13" />
          {{ view === 'list' ? 'Kalender' : 'List' }}
        </button>
      </template>
    </ParentBerandaHero>

    <!-- Subject filter chips (both views) -->
    <div class="flex gap-1.5 flex-wrap">
      <button
        v-for="opt in subjectChips"
        :key="opt.id"
        type="button"
        class="rounded-full px-2.5 py-1 text-[11px] transition-colors"
        :class="
          subjectFilter === opt.id
            ? 'bg-bimbel-accent-dim text-bimbel-hero font-bold'
            : 'bg-bimbel-bg text-bimbel-text-mid'
        "
        @click="subjectFilter = opt.id"
      >{{ opt.label }}</button>
    </div>

    <!-- LIST VIEW -->
    <template v-if="view === 'list'">
      <div
        v-if="!grouped.length"
        class="rounded-xl bg-bimbel-panel border border-bimbel-border-soft p-8 text-center text-[13px] text-bimbel-text-mid"
      >Tidak ada sesi mendatang.</div>

      <template v-for="g in grouped" :key="g.label">
        <p class="text-[10px] tracking-[0.1em] text-bimbel-text-lo font-bold uppercase pt-2.5 pb-1">
          {{ g.label }}
        </p>
        <div
          v-for="s in g.items"
          :key="s.id"
          class="rounded-lg bg-bimbel-bg p-2.5 flex items-center gap-2.5"
        >
          <div class="w-16 flex-shrink-0">
            <p class="text-[13px] font-bold text-bimbel-text-hi">{{ timeOnly(s.scheduled_at) }}</p>
            <p class="text-[11px] text-bimbel-text-mid">{{ s.duration_minutes ?? 60 }} menit</p>
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-[12px] font-bold text-bimbel-text-hi">
              {{ (s as any).subject || s.group?.program?.name || '—' }}
              <span class="text-bimbel-text-mid font-normal">
                · {{ (s as any).group_code || s.group?.name || '' }}
              </span>
            </p>
            <p class="text-[11px] text-bimbel-text-mid">
              {{ [(s as any).tutor_name ?? s.tutor?.name, s.room, s.topic].filter(Boolean).join(' · ') || '—' }}
            </p>
          </div>
          <span :class="statusPillCls(s)">{{ statusLabel(s) }}</span>
        </div>
      </template>
    </template>

    <!-- CALENDAR VIEW -->
    <template v-else>
      <div class="rounded-xl bg-bimbel-panel border border-bimbel-border-soft p-3.5">
        <!-- Month nav -->
        <div class="flex items-center justify-between mb-3">
          <button
            type="button"
            class="rounded-md p-1.5 text-bimbel-text-mid hover:bg-bimbel-bg"
            aria-label="Bulan sebelumnya"
            @click="shiftMonth(-1)"
          ><NavIcon name="chevron-left" :size="16" /></button>
          <p class="text-[14px] font-bold text-bimbel-text-hi">{{ calMonthLabel }}</p>
          <button
            type="button"
            class="rounded-md p-1.5 text-bimbel-text-mid hover:bg-bimbel-bg"
            aria-label="Bulan berikutnya"
            @click="shiftMonth(1)"
          ><NavIcon name="chevron-right" :size="16" /></button>
        </div>

        <!-- Day-of-week header -->
        <div class="grid grid-cols-7 gap-1 mb-1">
          <p
            v-for="d in DOW_SHORT"
            :key="d"
            class="text-center text-[10px] font-bold uppercase tracking-wider text-bimbel-text-lo py-1"
          >{{ d }}</p>
        </div>

        <!-- Date grid 6 × 7 -->
        <div class="grid grid-cols-7 gap-1">
          <button
            v-for="(cell, i) in calCells"
            :key="i"
            type="button"
            class="aspect-square rounded-md flex flex-col items-center justify-center gap-0.5 text-[12px] transition-colors relative"
            :class="[
              cell.isSelected
                ? 'bg-bimbel-hero text-white font-bold'
                : cell.isToday
                  ? 'bg-bimbel-accent-dim text-bimbel-hero font-bold ring-1 ring-bimbel-hero'
                  : cell.inMonth
                    ? 'text-bimbel-text-hi hover:bg-bimbel-bg'
                    : 'text-bimbel-text-lo hover:bg-bimbel-bg',
            ]"
            @click="selectDay(cell.date)"
          >
            <span>{{ cell.date.getDate() }}</span>
            <span v-if="cell.count > 0" class="flex gap-0.5">
              <span
                v-for="n in Math.min(cell.count, 3)"
                :key="n"
                class="w-1 h-1 rounded-full"
                :class="cell.isSelected ? 'bg-white' : 'bg-bimbel-hero'"
              ></span>
              <span
                v-if="cell.count > 3"
                class="text-[8px] leading-none"
                :class="cell.isSelected ? 'text-white' : 'text-bimbel-hero'"
              >+{{ cell.count - 3 }}</span>
            </span>
          </button>
        </div>
      </div>

      <!-- Selected-day session list -->
      <p class="text-[10px] tracking-[0.1em] text-bimbel-text-lo font-bold uppercase pt-2.5 pb-1">
        {{ calSelectedLabel }}
      </p>
      <div
        v-if="!calSelectedSessions.length"
        class="rounded-xl bg-bimbel-panel border border-bimbel-border-soft p-6 text-center text-[12px] text-bimbel-text-mid"
      >Tidak ada sesi di tanggal ini.</div>
      <div
        v-for="s in calSelectedSessions"
        :key="s.id"
        class="rounded-lg bg-bimbel-bg p-2.5 flex items-center gap-2.5"
      >
        <div class="w-16 flex-shrink-0">
          <p class="text-[13px] font-bold text-bimbel-text-hi">{{ timeOnly(s.scheduled_at) }}</p>
          <p class="text-[11px] text-bimbel-text-mid">{{ s.duration_minutes ?? 60 }} menit</p>
        </div>
        <div class="flex-1 min-w-0">
          <p class="text-[12px] font-bold text-bimbel-text-hi">
            {{ (s as any).subject || s.group?.program?.name || '—' }}
            <span class="text-bimbel-text-mid font-normal">
              · {{ (s as any).group_code || s.group?.name || '' }}
            </span>
          </p>
          <p class="text-[11px] text-bimbel-text-mid">
            {{ [(s as any).tutor_name ?? s.tutor?.name, s.room, s.topic].filter(Boolean).join(' · ') || '—' }}
          </p>
        </div>
        <span :class="statusPillCls(s)">{{ statusLabel(s) }}</span>
      </div>
    </template>
  </div>
</template>
