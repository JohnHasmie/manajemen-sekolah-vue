<!--
  AdminAnnouncementCalendarView.vue — admin Kalender Acara.

  Mirrors Flutter's `admin_announcement_calendar_screen.dart`. Month
  grid of every announcement carrying an event_at, with dots per day
  (colored by tipe / severity) and a list section below filtered by
  the selected day.

  Endpoint: GET /announcements?has_event=1&event_from&event_to
  (via AnnouncementService.fetchEventsForCalendar).
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { AnnouncementService } from '@/services/announcements.service';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import Spinner from '@/components/ui/Spinner.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const router = useRouter();

const today = new Date();
const viewedMonth = ref(new Date(today.getFullYear(), today.getMonth(), 1));
const selectedDate = ref(new Date(today.getFullYear(), today.getMonth(), today.getDate()));
const items = ref<Array<Record<string, unknown>>>([]);
const isLoading = ref(false);

async function loadMonth() {
  isLoading.value = true;
  const from = new Date(viewedMonth.value.getFullYear(), viewedMonth.value.getMonth(), 1);
  const to = new Date(viewedMonth.value.getFullYear(), viewedMonth.value.getMonth() + 1, 0);
  // Make the range inclusive of the full last day.
  to.setHours(23, 59, 59, 999);
  try {
    items.value = await AnnouncementService.fetchEventsForCalendar({ from, to });
  } finally {
    isLoading.value = false;
  }
}

onMounted(loadMonth);

function shiftMonth(delta: number) {
  const next = new Date(viewedMonth.value.getFullYear(), viewedMonth.value.getMonth() + delta, 1);
  viewedMonth.value = next;
  // Snap selection — if we're back on the current month, jump to today;
  // otherwise pick the 1st so the day list isn't empty.
  if (
    next.getFullYear() === today.getFullYear() &&
    next.getMonth() === today.getMonth()
  ) {
    selectedDate.value = new Date(today.getFullYear(), today.getMonth(), today.getDate());
  } else {
    selectedDate.value = new Date(next.getFullYear(), next.getMonth(), 1);
  }
}
watch(viewedMonth, loadMonth);

// ── Month label ────────────────────────────────────────────────────
const MONTH_NAMES_ID = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];
const monthLabel = computed(
  () =>
    `${MONTH_NAMES_ID[viewedMonth.value.getMonth()]} ${viewedMonth.value.getFullYear()}`,
);

// ── Day-of-month → items lookup ────────────────────────────────────
const itemsByDay = computed(() => {
  const out = new Map<number, Array<Record<string, unknown>>>();
  const m = viewedMonth.value.getMonth();
  const y = viewedMonth.value.getFullYear();
  for (const it of items.value) {
    const raw = it.event_at;
    if (!raw) continue;
    const d = new Date(String(raw));
    if (Number.isNaN(d.getTime())) continue;
    if (d.getFullYear() !== y || d.getMonth() !== m) continue;
    const day = d.getDate();
    if (!out.has(day)) out.set(day, []);
    out.get(day)!.push(it);
  }
  return out;
});

const selectedDayItems = computed(
  () => itemsByDay.value.get(selectedDate.value.getDate()) ?? [],
);

// ── Month grid cells ───────────────────────────────────────────────
interface DayCell {
  day: number | null;
  isToday: boolean;
  isSelected: boolean;
  count: number;
  severity: 'event' | 'penting' | 'darurat' | null;
}

function severityForItems(its: Array<Record<string, unknown>>): DayCell['severity'] {
  // Mobile color rules: blue (announcement/general) / amber (high/penting) /
  // red (urgent/darurat). Pick the highest severity present on this day.
  // Reads both the new English canonical values and the legacy Indonesian
  // synonyms so the calendar still colour-codes events from older rows.
  let hasPenting = false;
  let hasDarurat = false;
  for (const it of its) {
    const blob = String(it.priority ?? it.category ?? it.type ?? '').toLowerCase();
    if (blob.includes('urgent') || blob.includes('darurat')) hasDarurat = true;
    if (blob.includes('high') || blob.includes('penting') || blob.includes('peringatan'))
      hasPenting = true;
  }
  if (hasDarurat) return 'darurat';
  if (hasPenting) return 'penting';
  return 'event';
}

const monthCells = computed<DayCell[]>(() => {
  const y = viewedMonth.value.getFullYear();
  const m = viewedMonth.value.getMonth();
  const firstDay = new Date(y, m, 1);
  const daysInMonth = new Date(y, m + 1, 0).getDate();
  // Indo convention: Senin = 0 col, Minggu = 6 col.
  // JS getDay(): Sun=0, Mon=1, ... Sat=6 → shift to Mon=0..Sun=6.
  const leading = (firstDay.getDay() + 6) % 7;
  const totalCells = Math.ceil((leading + daysInMonth) / 7) * 7;
  const cells: DayCell[] = [];
  for (let i = 0; i < totalCells; i++) {
    const dayNum = i - leading + 1;
    if (dayNum < 1 || dayNum > daysInMonth) {
      cells.push({ day: null, isToday: false, isSelected: false, count: 0, severity: null });
      continue;
    }
    const its = itemsByDay.value.get(dayNum) ?? [];
    const isToday =
      y === today.getFullYear() && m === today.getMonth() && dayNum === today.getDate();
    const isSelected =
      y === selectedDate.value.getFullYear() &&
      m === selectedDate.value.getMonth() &&
      dayNum === selectedDate.value.getDate();
    cells.push({
      day: dayNum,
      isToday,
      isSelected,
      count: its.length,
      severity: its.length > 0 ? severityForItems(its) : null,
    });
  }
  return cells;
});

const DOW_LABELS = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

function pickDay(cell: DayCell) {
  if (cell.day == null) return;
  selectedDate.value = new Date(
    viewedMonth.value.getFullYear(),
    viewedMonth.value.getMonth(),
    cell.day,
  );
}

function selectedDayLabel(): string {
  return selectedDate.value.toLocaleDateString('id-ID', {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  });
}

function dotClass(sev: DayCell['severity']): string {
  if (sev === 'darurat') return 'bg-red-500';
  if (sev === 'penting') return 'bg-amber-500';
  if (sev === 'event') return 'bg-brand-cobalt';
  return 'bg-transparent';
}

function eventTimeLabel(raw: unknown): string {
  if (!raw) return '';
  const d = new Date(String(raw));
  if (Number.isNaN(d.getTime())) return '';
  return d.toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' });
}

function eventCategoryLabel(it: Record<string, unknown>): string {
  const blob = String(it.priority ?? it.category ?? it.type ?? '').toLowerCase();
  if (blob.includes('urgent') || blob.includes('darurat')) return 'DARURAT';
  if (blob.includes('high') || blob.includes('penting') || blob.includes('peringatan'))
    return 'PENTING';
  return 'PENGUMUMAN';
}

function categoryChipCls(it: Record<string, unknown>): string {
  const c = eventCategoryLabel(it);
  if (c === 'DARURAT') return 'bg-red-100 text-red-700';
  if (c === 'PENTING') return 'bg-amber-100 text-amber-700';
  return 'bg-blue-100 text-blue-700';
}

function openDetail(it: Record<string, unknown>) {
  const id = it.id;
  if (id) {
    router.push({
      name: 'admin.announcements',
      query: { open: String(id) },
    });
  } else {
    router.push({ name: 'admin.announcements' });
  }
}

function goBack() {
  router.push({ name: 'admin.announcements' });
}
</script>

<template>
  <div class="space-y-md pb-12">
    <button
      type="button"
      class="inline-flex items-center gap-1.5 text-[12px] font-bold text-slate-600 hover:text-role-admin"
      @click="goBack"
    >
      <NavIcon name="chevron-left" :size="14" />
      Pengumuman
    </button>

    <BrandPageHeader
      role="admin"
      kicker="KALENDER ACARA"
      :title="monthLabel"
      :live-dot="false"
    >
      <div class="flex items-center gap-1">
        <button
          type="button"
          class="w-7 h-7 rounded-full flex items-center justify-center bg-white/15 hover:bg-white/25 text-white transition-colors"
          @click="shiftMonth(-1)"
        >
          <NavIcon name="chevron-left" :size="14" />
        </button>
        <button
          type="button"
          class="w-7 h-7 rounded-full flex items-center justify-center bg-white/15 hover:bg-white/25 text-white transition-colors"
          @click="shiftMonth(1)"
        >
          <NavIcon name="chevron-right" :size="14" />
        </button>
      </div>
    </BrandPageHeader>

    <!-- Month grid -->
    <section class="bg-white border border-slate-200 rounded-2xl p-3 shadow-sm">
      <div class="grid grid-cols-7 mb-2">
        <p
          v-for="d in DOW_LABELS"
          :key="d"
          class="text-center text-[10px] font-bold text-slate-400 uppercase tracking-widest py-1"
        >
          {{ d }}
        </p>
      </div>
      <div class="grid grid-cols-7 gap-1">
        <button
          v-for="(cell, idx) in monthCells"
          :key="idx"
          type="button"
          :disabled="cell.day === null"
          class="relative aspect-square rounded-lg flex flex-col items-center justify-center transition-colors text-[12px] font-bold disabled:cursor-default"
          :class="[
            cell.day === null
              ? ''
              : cell.isSelected
                ? 'bg-role-admin text-white shadow-md'
                : cell.isToday
                  ? 'bg-role-admin/10 text-role-admin'
                  : cell.count > 0
                    ? 'bg-slate-50 text-slate-900 hover:bg-slate-100'
                    : 'text-slate-700 hover:bg-slate-50',
          ]"
          @click="pickDay(cell)"
        >
          <span v-if="cell.day !== null">{{ cell.day }}</span>
          <span
            v-if="cell.day !== null && cell.count > 0"
            class="absolute bottom-1 w-1.5 h-1.5 rounded-full"
            :class="cell.isSelected ? 'bg-white' : dotClass(cell.severity)"
          />
        </button>
      </div>
    </section>

    <!-- Selected-day list -->
    <section class="bg-white border border-slate-200 rounded-2xl p-4 shadow-sm space-y-md">
      <header class="border-b border-slate-100 pb-2">
        <p class="text-[10px] font-black text-slate-400 uppercase tracking-widest">
          {{ selectedDayItems.length }} acara
        </p>
        <p class="text-[14px] font-extrabold text-slate-900 mt-0.5">
          {{ selectedDayLabel() }}
        </p>
      </header>

      <div v-if="isLoading" class="py-6 flex items-center justify-center">
        <Spinner size="md" />
      </div>
      <div
        v-else-if="selectedDayItems.length === 0"
        class="py-8 text-center text-[12px] text-slate-400"
      >
        Tidak ada acara pada hari ini.
      </div>
      <ul v-else class="space-y-2">
        <li v-for="(it, i) in selectedDayItems" :key="String(it.id ?? i)">
          <button
            type="button"
            class="w-full text-left rounded-xl border border-slate-200 p-3 hover:bg-slate-50 transition-colors flex items-start gap-3"
            @click="openDetail(it)"
          >
            <div
              class="w-1 self-stretch rounded-full flex-shrink-0"
              :class="dotClass(severityForItems([it]))"
            />
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2 flex-wrap">
                <span
                  class="px-2 py-0.5 rounded-md text-[9px] font-black tracking-widest"
                  :class="categoryChipCls(it)"
                >
                  {{ eventCategoryLabel(it) }}
                </span>
                <span class="text-[10px] font-bold text-slate-500 tabular-nums">
                  {{ eventTimeLabel(it.event_at) }}
                </span>
              </div>
              <p class="text-[13.5px] font-bold text-slate-900 mt-1 leading-snug">
                {{ String(it.title ?? '—') }}
              </p>
              <p
                v-if="it.body"
                class="text-[11px] text-slate-600 mt-0.5 leading-snug line-clamp-2"
              >
                {{ String(it.body ?? '') }}
              </p>
            </div>
            <NavIcon name="chevron-right" :size="14" class="text-slate-300 mt-1" />
          </button>
        </li>
      </ul>
    </section>
  </div>
</template>
