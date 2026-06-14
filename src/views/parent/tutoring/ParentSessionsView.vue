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
import SessionsCalendar from '@/components/feature/tutoring/SessionsCalendar.vue';

const route = useRoute();
const { activeChildId } = useChildPicker();

const studentId = computed(() =>
  String(route.params.studentId || activeChildId.value || ''),
);

const loading = ref(true);
const sessions = ref<TutoringSession[]>([]);
const subjectFilter = ref<string>('all');
const view = ref<'list' | 'calendar'>('list');

function toggleView() {
  view.value = view.value === 'list' ? 'calendar' : 'list';
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

    <!-- CALENDAR VIEW — shared SessionsCalendar (same as admin + tutor) -->
    <SessionsCalendar v-else :sessions="visible" accent="wali" />
  </div>
</template>
