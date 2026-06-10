<!--
  TutorRecurringSessionsView — bulk-create sessions on a weekday
  template. Same flow as the Flutter screen.

  Server-side action wraps everything in a transaction and skips
  exact (group, scheduled_at) duplicates so re-runs are safe.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import type { TutoringGroup } from '@/types/tutoring';

import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();
const router = useRouter();
const toast = useToast();

const groups = ref<TutoringGroup[]>([]);
const groupId = ref('');
const weekdays = ref<Set<number>>(new Set([1, 3])); // Mon + Wed default
const startDate = ref<string>(isoToday(1));
const endDate = ref<string>(isoToday(60));
const time = ref<string>('16:00');
const duration = ref<number>(90);
const room = ref('');
const meetingUrl = ref('');
const topic = ref('');

const saving = ref(false);
const result = ref<{ created: number; skipped: number } | null>(null);

function isoToday(offset: number): string {
  const d = new Date();
  d.setDate(d.getDate() + offset);
  const yyyy = d.getFullYear();
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const dd = String(d.getDate()).padStart(2, '0');
  return `${yyyy}-${mm}-${dd}`;
}

onMounted(async () => {
  try {
    groups.value = await TutoringService.getAllGroups();
    if (groups.value[0]) groupId.value = groups.value[0].id;
  } catch {/* non-fatal */}
});

function toggleDay(d: number) {
  if (weekdays.value.has(d)) weekdays.value.delete(d);
  else weekdays.value.add(d);
  // Trigger reactivity (Set mutation).
  weekdays.value = new Set(weekdays.value);
}

// Naive client-side preview (server may skip duplicates).
const previewCount = computed(() => {
  if (weekdays.value.size === 0) return 0;
  const start = new Date(startDate.value);
  const end = new Date(endDate.value);
  if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) return 0;
  let n = 0;
  const cursor = new Date(start);
  while (cursor <= end) {
    // ISO weekday: Mon=1..Sun=7 (cursor.getDay() is Sun=0..Sat=6).
    const iso = ((cursor.getDay() + 6) % 7) + 1;
    if (weekdays.value.has(iso)) n++;
    cursor.setDate(cursor.getDate() + 1);
  }
  return n;
});

async function submit() {
  if (!groupId.value) {
    toast.error('Pilih kelompok dulu.');
    return;
  }
  if (weekdays.value.size === 0) {
    toast.error('Pilih minimal satu hari.');
    return;
  }
  saving.value = true;
  result.value = null;
  try {
    const res = await TutoringService.generateRecurringSessions({
      group_id: groupId.value,
      weekdays: [...weekdays.value].sort(),
      start_date: startDate.value,
      end_date: endDate.value,
      time: time.value,
      duration_minutes: duration.value,
      room: room.value.trim() || undefined,
      meeting_url: meetingUrl.value.trim() || undefined,
      topic: topic.value.trim() || undefined,
    });
    result.value = res;
    toast.success(`${res.created} sesi dibuat.`);
  } catch (e) {
    toast.error(e instanceof Error ? e.message : 'Gagal generate sesi.');
  } finally {
    saving.value = false;
  }
}

const DAYS: { iso: number; label: string }[] = [
  { iso: 1, label: 'Sen' },
  { iso: 2, label: 'Sel' },
  { iso: 3, label: 'Rab' },
  { iso: 4, label: 'Kam' },
  { iso: 5, label: 'Jum' },
  { iso: 6, label: 'Sab' },
  { iso: 7, label: 'Min' },
];
</script>

<template>
  <div class="space-y-md pb-12">
    <BrandPageHeader
      role="guru"
      kicker="Bimbel · Sesi · Bulk"
      title="Generate Sesi Berulang"
      meta="Senin & Rabu jam 16:00 selama 2 bulan → satu kali submit"
    />

    <div class="space-y-3 bg-white border border-slate-100 rounded-2xl p-4 sm:p-5">
      <label class="block">
        <span class="text-[10.5px] font-bold text-slate-500 uppercase tracking-wider">
          Kelompok
        </span>
        <select
          v-model="groupId"
          class="mt-1.5 w-full rounded-lg border border-slate-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-teacher/20 focus:border-role-teacher"
        >
          <option value="" disabled>Pilih kelompok</option>
          <option v-for="g in groups" :key="g.id" :value="g.id">{{ g.name }}</option>
        </select>
      </label>

      <div>
        <p class="text-[10.5px] font-bold text-slate-500 uppercase tracking-wider mb-2">
          Hari
        </p>
        <div class="flex flex-wrap gap-1.5">
          <button
            v-for="d in DAYS"
            :key="d.iso"
            type="button"
            class="rounded-lg px-3.5 py-1.5 text-xs font-bold border transition"
            :class="weekdays.has(d.iso)
              ? 'bg-role-teacher border-role-teacher text-white'
              : 'bg-white border-slate-200 text-slate-700 hover:border-slate-300'"
            @click="toggleDay(d.iso)"
          >
            {{ d.label }}
          </button>
        </div>
      </div>

      <div class="grid grid-cols-2 gap-2">
        <label class="block">
          <span class="text-[10.5px] font-bold text-slate-500 uppercase tracking-wider">
            Mulai
          </span>
          <input
            v-model="startDate"
            type="date"
            class="mt-1.5 w-full rounded-lg border border-slate-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-teacher/20 focus:border-role-teacher"
          />
        </label>
        <label class="block">
          <span class="text-[10.5px] font-bold text-slate-500 uppercase tracking-wider">
            Sampai
          </span>
          <input
            v-model="endDate"
            type="date"
            :min="startDate"
            class="mt-1.5 w-full rounded-lg border border-slate-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-teacher/20 focus:border-role-teacher"
          />
        </label>
      </div>

      <div class="grid grid-cols-2 gap-2">
        <label class="block">
          <span class="text-[10.5px] font-bold text-slate-500 uppercase tracking-wider">
            Jam
          </span>
          <input
            v-model="time"
            type="time"
            class="mt-1.5 w-full rounded-lg border border-slate-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-teacher/20 focus:border-role-teacher"
          />
        </label>
        <label class="block">
          <span class="text-[10.5px] font-bold text-slate-500 uppercase tracking-wider">
            Durasi
          </span>
          <select
            v-model.number="duration"
            class="mt-1.5 w-full rounded-lg border border-slate-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-teacher/20 focus:border-role-teacher"
          >
            <option :value="60">60 menit</option>
            <option :value="90">90 menit</option>
            <option :value="120">120 menit</option>
            <option :value="150">150 menit</option>
          </select>
        </label>
      </div>

      <label class="block">
        <span class="text-[10.5px] font-bold text-slate-500 uppercase tracking-wider">
          Ruang (opsional)
        </span>
        <input
          v-model="room"
          class="mt-1.5 w-full rounded-lg border border-slate-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-teacher/20 focus:border-role-teacher"
        />
      </label>

      <label class="block">
        <span class="text-[10.5px] font-bold text-slate-500 uppercase tracking-wider">
          Link meeting (opsional)
        </span>
        <input
          v-model="meetingUrl"
          type="url"
          placeholder="https://zoom.us/j/…"
          class="mt-1.5 w-full rounded-lg border border-slate-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-teacher/20 focus:border-role-teacher"
        />
      </label>

      <label class="block">
        <span class="text-[10.5px] font-bold text-slate-500 uppercase tracking-wider">
          Topik (opsional)
        </span>
        <input
          v-model="topic"
          class="mt-1.5 w-full rounded-lg border border-slate-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-teacher/20 focus:border-role-teacher"
        />
      </label>

      <div
        v-if="result"
        class="rounded-xl bg-status-success-soft border border-status-success/30 p-3 text-sm font-bold text-status-success flex items-center gap-2"
      >
        <NavIcon name="check-circle" :size="16" />
        {{ result.created }} sesi dibuat<span v-if="result.skipped > 0">, {{ result.skipped }} dilewati (sudah ada)</span>.
      </div>

      <div class="flex items-center gap-2 justify-end pt-2">
        <button
          type="button"
          class="rounded-lg px-3 py-2 text-sm font-semibold text-slate-700 hover:bg-slate-100"
          @click="router.back"
        >
          {{ t('tutoring.common.close') }}
        </button>
        <button
          type="button"
          :disabled="saving"
          class="rounded-lg bg-role-teacher hover:bg-role-teacher/90 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50"
          @click="submit"
        >
          {{ saving ? t('tutoring.common.saving') : `Buat ${previewCount} sesi` }}
        </button>
      </div>
    </div>
  </div>
</template>
