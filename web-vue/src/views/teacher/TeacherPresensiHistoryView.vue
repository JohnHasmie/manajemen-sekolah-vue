<!--
  TeacherPresensiHistoryView.vue — the teacher's own PRESENSI GURU log.

  Paginated list of the authenticated teacher's daily check-in/out
  records (GET /teacher-attendance/history) with a date-range filter.
  Each row shows the date, status (Tepat Waktu / Terlambat), masuk/pulang
  times, the geofence distance, and a thumbnail of the check-in selfie.

  Above the log sits a PERIOD SUMMARY header (X Hadir · Y Telat ·
  % Kehadiran) for the selected periode, from the teacher own-summary
  endpoint (GET /teacher-attendance/history/summary, backend MR !110).
  Status chips are DYNAMIC — driven by meta.statuses.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { TeacherAttendanceService } from '@/services/teacher-attendance.service';
import type {
  TeacherAttendanceListResult,
  TeacherAttendanceOwnSummary,
  TeacherAttendanceRecord,
} from '@/types/teacher-attendance';
import {
  teacherAttendanceStatusColumnLabel,
  teacherAttendanceStatusLabel,
} from '@/types/teacher-attendance';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Button from '@/components/ui/Button.vue';

const router = useRouter();

const startDate = ref('');
const endDate = ref('');
const page = ref(1);
const perPage = 20;

const result = ref<TeacherAttendanceListResult | null>(null);
const isLoading = ref(true);
const error = ref<string | null>(null);

const records = computed<TeacherAttendanceRecord[]>(
  () => result.value?.items ?? [],
);
const meta = computed(() => result.value?.meta ?? null);

const state = computed<AsyncState<TeacherAttendanceRecord[]>>(() => {
  if (isLoading.value && records.value.length === 0)
    return { status: 'loading' };
  if (error.value) return { status: 'error', error: error.value };
  if (records.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: records.value };
});

// ── Period summary header (history/summary) ─────────────────────────
const summary = ref<TeacherAttendanceOwnSummary | null>(null);
const summaryLoading = ref(false);

/** Status keys to render as chips (dynamic — from meta.statuses). */
const summaryStatuses = computed<string[]>(
  () => summary.value?.meta.statuses ?? ['present', 'late'],
);

/** Period label shown beside the chips, when the server echoes a range. */
const summaryRangeLabel = computed(() => {
  const m = summary.value?.meta;
  if (!m) return '';
  return `${fmtDate(m.start_date)} – ${fmtDate(m.end_date)}`;
});

/** Tailwind classes for a status chip — green leads, amber for late. */
function chipClass(status: string): string {
  if (status === 'present') return 'bg-emerald-100 text-emerald-700';
  if (status === 'late') return 'bg-amber-100 text-amber-700';
  return 'bg-slate-100 text-slate-600';
}

async function loadSummary() {
  summaryLoading.value = true;
  try {
    summary.value = await TeacherAttendanceService.historySummary({
      start_date: startDate.value || undefined,
      end_date: endDate.value || undefined,
    });
  } catch {
    // The summary is a non-critical header — keep the log usable even
    // if the rekap endpoint hiccups. Errors surface on the list itself.
    summary.value = null;
  } finally {
    summaryLoading.value = false;
  }
}

async function reload() {
  isLoading.value = true;
  error.value = null;
  // Refresh the header alongside the log so both reflect the same periode.
  loadSummary();
  try {
    result.value = await TeacherAttendanceService.history({
      start_date: startDate.value || undefined,
      end_date: endDate.value || undefined,
      per_page: perPage,
      page: page.value,
    });
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

function applyFilters() {
  page.value = 1;
  reload();
}

function clearFilters() {
  startDate.value = '';
  endDate.value = '';
  page.value = 1;
  reload();
}

function goPage(n: number) {
  if (!meta.value) return;
  if (n < 1 || n > meta.value.last_page || n === meta.value.current_page)
    return;
  page.value = n;
  reload();
}

function fmtDate(d: string): string {
  if (!d) return '-';
  return new Date(d).toLocaleDateString('id-ID', {
    weekday: 'short',
    day: 'numeric',
    month: 'short',
    year: 'numeric',
  });
}

function fmtTime(iso?: string | null): string {
  if (!iso) return '-';
  return new Date(iso).toLocaleTimeString('id-ID', {
    hour: '2-digit',
    minute: '2-digit',
  });
}

onMounted(reload);
</script>

<template>
  <div class="space-y-md">
    <BrandPageHeader
      role="guru"
      kicker="Presensi Guru · Riwayat"
      title="Riwayat Presensi"
      :meta="meta ? `${meta.total} catatan` : 'Catatan presensi harian Anda'"
    >
      <Button
        variant="secondary"
        size="sm"
        @click="router.push('/teacher/my-attendance')"
      >
        <NavIcon name="arrow-left" :size="13" />Kembali
      </Button>
    </BrandPageHeader>

    <!-- Filter toolbar -->
    <section
      class="bg-white border border-slate-200 rounded-2xl p-3 flex flex-wrap items-end gap-3"
    >
      <div>
        <label
          class="text-[10px] font-bold text-slate-400 uppercase tracking-widest block mb-1"
        >
          Dari tanggal
        </label>
        <input
          v-model="startDate"
          type="date"
          class="rounded-lg border border-slate-200 px-2.5 py-1.5 text-[12.5px] text-slate-800 focus:outline-none focus:ring-2 focus:ring-brand-cobalt/30"
        />
      </div>
      <div>
        <label
          class="text-[10px] font-bold text-slate-400 uppercase tracking-widest block mb-1"
        >
          Sampai tanggal
        </label>
        <input
          v-model="endDate"
          type="date"
          class="rounded-lg border border-slate-200 px-2.5 py-1.5 text-[12.5px] text-slate-800 focus:outline-none focus:ring-2 focus:ring-brand-cobalt/30"
        />
      </div>
      <Button variant="primary" size="sm" @click="applyFilters">
        <NavIcon name="filter" :size="13" />Terapkan
      </Button>
      <Button
        v-if="startDate || endDate"
        variant="ghost"
        size="sm"
        @click="clearFilters"
      >
        Reset
      </Button>
    </section>

    <!-- Period summary header (Hadir · Telat · % Kehadiran) -->
    <section
      v-if="summary"
      class="bg-white border border-slate-200 rounded-2xl p-4"
    >
      <div
        class="flex items-center justify-between gap-3 flex-wrap mb-3"
      >
        <h3 class="text-[13px] font-black text-slate-900">Ringkasan Periode</h3>
        <span v-if="summaryRangeLabel" class="text-[11px] text-slate-500">
          {{ summaryRangeLabel }}
        </span>
      </div>
      <div class="grid grid-cols-2 sm:grid-cols-4 gap-3">
        <div
          v-for="s in summaryStatuses"
          :key="s"
          class="rounded-xl px-3 py-2.5"
          :class="chipClass(s)"
        >
          <p class="text-[10px] font-bold uppercase tracking-widest opacity-80">
            {{ teacherAttendanceStatusColumnLabel(s) }}
          </p>
          <p class="text-[20px] font-black leading-tight tabular-nums">
            {{ summary.summary[s] ?? 0 }}
          </p>
        </div>
        <div class="rounded-xl px-3 py-2.5 bg-brand-cobalt/10 text-brand-cobalt">
          <p class="text-[10px] font-bold uppercase tracking-widest opacity-80">
            % Kehadiran
          </p>
          <p class="text-[20px] font-black leading-tight tabular-nums">
            {{ summary.summary.present_pct }}%
          </p>
          <p class="text-[10px] opacity-70 tabular-nums">
            {{ summary.summary.total }} hari tercatat
          </p>
        </div>
      </div>
    </section>

    <!-- List -->
    <AsyncView
      :state="state"
      empty-title="Belum ada riwayat presensi"
      empty-description="Catatan presensi harian Anda akan muncul di sini."
      @retry="reload"
    >
      <template #default>
        <ul class="space-y-2">
          <li
            v-for="r in records"
            :key="r.id"
            class="bg-white border border-slate-200 rounded-2xl p-3 flex items-center gap-3"
          >
            <!-- Selfie thumbnail -->
            <div
              class="w-12 h-12 rounded-xl overflow-hidden bg-slate-100 flex-shrink-0 grid place-items-center"
            >
              <img
                v-if="r.check_in_photo_url"
                :src="r.check_in_photo_url"
                alt="Foto presensi"
                class="w-full h-full object-cover"
              />
              <NavIcon v-else name="camera" :size="16" class="text-slate-300" />
            </div>

            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2">
                <p class="text-[13px] font-bold text-slate-900">
                  {{ fmtDate(r.date) }}
                </p>
                <span
                  class="text-[10px] font-bold px-1.5 py-0.5 rounded-full"
                  :class="
                    r.status === 'late'
                      ? 'bg-amber-100 text-amber-700'
                      : 'bg-emerald-100 text-emerald-700'
                  "
                >
                  {{ teacherAttendanceStatusLabel(r.status) }}
                </span>
              </div>
              <p class="text-[11.5px] text-slate-500 mt-0.5">
                Masuk
                <span class="font-bold text-slate-700">{{
                  fmtTime(r.check_in_at)
                }}</span>
                <template v-if="r.check_out_at">
                  · Pulang
                  <span class="font-bold text-slate-700">{{
                    fmtTime(r.check_out_at)
                  }}</span>
                </template>
              </p>
              <p
                v-if="
                  r.check_in_outside_geofence || r.check_in_distance_m != null
                "
                class="text-[10.5px] mt-0.5"
                :class="
                  r.check_in_outside_geofence
                    ? 'text-red-600 font-bold'
                    : 'text-slate-400'
                "
              >
                <NavIcon
                  name="map-pin"
                  :size="10"
                  class="inline-block -mt-0.5"
                />
                <template v-if="r.check_in_outside_geofence"
                  >Di luar area sekolah</template
                >
                <template v-else
                  >{{ r.check_in_distance_m }} m dari sekolah</template
                >
              </p>
            </div>
          </li>
        </ul>

        <!-- Pagination -->
        <div
          v-if="meta && meta.last_page > 1"
          class="flex items-center justify-center gap-2 pt-3"
        >
          <Button
            variant="secondary"
            size="sm"
            :disabled="meta.current_page <= 1"
            @click="goPage(meta.current_page - 1)"
          >
            <NavIcon name="chevron-left" :size="13" />
          </Button>
          <span class="text-[12px] text-slate-500 font-bold px-2">
            Hal {{ meta.current_page }} / {{ meta.last_page }}
          </span>
          <Button
            variant="secondary"
            size="sm"
            :disabled="meta.current_page >= meta.last_page"
            @click="goPage(meta.current_page + 1)"
          >
            <NavIcon name="chevron-right" :size="13" />
          </Button>
        </div>
      </template>
    </AsyncView>
  </div>
</template>
