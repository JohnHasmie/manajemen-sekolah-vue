<!--
  ParentTutoringOverviewView — a parent's monitoring page for one child's
  bimbel: attendance rate, score progress, outstanding bills, upcoming
  sessions. The web mirror of the Flutter
  `tutoring_child_overview_screen.dart`.

  studentId comes from the route param; studentName from the query (so we
  don't refetch just to render the title).
-->
<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';
import { TutoringService } from '@/services/tutoring.service';
import { formatDateShort, formatRupiah } from '@/lib/format';
import type { TutoringBill, TutoringChildOverview } from '@/types/tutoring';

const route = useRoute();
const studentId = String(route.params.studentId ?? '');
const studentName = String(route.query.name ?? 'Anak');

const loading = ref(true);
const error = ref<string | null>(null);
const data = ref<TutoringChildOverview | null>(null);

async function load() {
  loading.value = true;
  error.value = null;
  try {
    data.value = await TutoringService.getChildOverview(studentId);
  } catch (e) {
    error.value = e instanceof Error ? e.message : 'Gagal memuat data bimbel.';
  } finally {
    loading.value = false;
  }
}

onMounted(load);

function unpaid(bills: TutoringBill[]): TutoringBill[] {
  return bills.filter((b) => b.status.toLowerCase() !== 'paid');
}

function billTotal(bills: TutoringBill[]): number {
  return unpaid(bills).reduce((sum, b) => sum + (b.amount ?? 0), 0);
}
</script>

<template>
  <div class="mx-auto max-w-3xl p-4">
    <header class="mb-4 flex items-center gap-2">
      <span class="rounded-full bg-violet-600 px-3 py-1 text-sm font-bold text-white">
        Bimbel
      </span>
      <h1 class="text-lg font-bold text-slate-800">{{ studentName }}</h1>
    </header>

    <div v-if="loading" class="py-16 text-center text-slate-500">Memuat…</div>

    <div v-else-if="error" class="rounded-xl border border-red-200 bg-red-50 p-6 text-center">
      <p class="text-red-700">{{ error }}</p>
      <button
        class="mt-3 rounded-lg bg-red-600 px-4 py-2 text-sm font-semibold text-white"
        @click="load"
      >
        Coba lagi
      </button>
    </div>

    <div v-else-if="data" class="space-y-4">
      <!-- Attendance -->
      <section class="rounded-2xl border border-slate-200 p-4">
        <h2 class="mb-3 font-bold text-slate-800">Kehadiran</h2>
        <p v-if="data.attendance.total_recorded === 0" class="text-slate-500">
          Belum ada sesi yang tercatat.
        </p>
        <div v-else class="flex items-center gap-4">
          <div class="rounded-xl bg-violet-100 px-4 py-2 text-center">
            <div class="text-xl font-extrabold text-violet-700">
              {{
                data.attendance.attendance_rate == null
                  ? '–'
                  : Math.round(data.attendance.attendance_rate) + '%'
              }}
            </div>
            <div class="text-[11px] text-slate-600">Hadir</div>
          </div>
          <p class="text-slate-600">
            {{ data.attendance.attended }} dari
            {{ data.attendance.total_recorded }} sesi hadir
          </p>
        </div>
      </section>

      <!-- Progress -->
      <section class="rounded-2xl border border-slate-200 p-4">
        <h2 class="mb-3 font-bold text-slate-800">Nilai &amp; Progress</h2>
        <p v-if="data.progress.timeline.length === 0" class="text-slate-500">
          Belum ada nilai try-out.
        </p>
        <div v-else>
          <div class="mb-2 flex items-center gap-4">
            <div class="rounded-xl bg-violet-100 px-4 py-2 text-center">
              <div class="text-xl font-extrabold text-violet-700">
                {{
                  data.progress.summary.overall.latest == null
                    ? '–'
                    : Math.round(data.progress.summary.overall.latest) + '%'
                }}
              </div>
              <div class="text-[11px] text-slate-600">Terakhir</div>
            </div>
            <p class="text-slate-600">
              Terbaik
              {{ Math.round(data.progress.summary.overall.best ?? 0) }}% ·
              Rata-rata
              {{ Math.round(data.progress.summary.overall.average ?? 0) }}%
            </p>
          </div>
          <ul class="divide-y divide-slate-100">
            <li
              v-for="e in data.progress.timeline.slice(0, 3)"
              :key="e.assessment_id"
              class="flex items-center justify-between py-1.5"
            >
              <span class="text-slate-700">{{ e.title }}</span>
              <span class="font-semibold text-slate-800">
                {{ e.percentage == null ? '–' : Math.round(e.percentage) + '%' }}
              </span>
            </li>
          </ul>
        </div>
      </section>

      <!-- Bills -->
      <section class="rounded-2xl border border-slate-200 p-4">
        <h2 class="mb-3 font-bold text-slate-800">Tagihan</h2>
        <p v-if="unpaid(data.bills).length === 0" class="text-slate-500">
          Tidak ada tagihan tertunggak. 🎉
        </p>
        <div v-else>
          <p class="mb-2 font-bold text-slate-800">
            Total tertunggak: {{ formatRupiah(billTotal(data.bills)) }}
          </p>
          <ul class="divide-y divide-slate-100">
            <li
              v-for="b in unpaid(data.bills)"
              :key="b.id"
              class="flex items-center justify-between py-1.5"
            >
              <span class="text-slate-700">
                {{ b.source_label ?? 'Tagihan' }}
                <template v-if="b.due_date">
                  · jatuh tempo {{ formatDateShort(b.due_date) }}
                </template>
              </span>
              <span class="text-slate-800">{{ formatRupiah(b.amount ?? 0) }}</span>
            </li>
          </ul>
        </div>
      </section>

      <!-- Schedule -->
      <section class="rounded-2xl border border-slate-200 p-4">
        <h2 class="mb-3 font-bold text-slate-800">Jadwal Mendatang</h2>
        <p v-if="data.upcomingSessions.length === 0" class="text-slate-500">
          Tidak ada sesi terjadwal.
        </p>
        <ul v-else class="space-y-2">
          <li
            v-for="s in data.upcomingSessions.slice(0, 5)"
            :key="s.id"
            class="flex gap-2"
          >
            <span class="mt-1.5 h-2 w-2 rounded-full bg-slate-300" />
            <div>
              <div class="font-semibold text-slate-800">
                {{ s.scheduled_at ? formatDateShort(s.scheduled_at) : '—' }}
              </div>
              <div class="text-xs text-slate-500">
                {{
                  [s.group?.program?.name, s.topic, s.room ? 'Ruang ' + s.room : null]
                    .filter(Boolean)
                    .join(' · ')
                }}
              </div>
            </div>
          </li>
        </ul>
      </section>
    </div>
  </div>
</template>
