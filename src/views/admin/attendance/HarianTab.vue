<script setup lang="ts">
/**
 * Kehadiran Siswa · Harian (mockup §02) — per-student per-day view fed
 * by the new `GET /attendance/students/daily` endpoint. Reads the
 * reconciled `student_daily_attendances` row (written by gate self-check-in
 * or admin manual entry), so every student in the school shows up as
 * exactly one row: hadir / terlambat / izin / sakit / alfa / belum-absen,
 * with the check-in time + method (QR_GATE / QR_CARD / SELFIE / MANUAL).
 *
 * Right rail shows the QR-gate live card, the method mix bars, the
 * live check-in feed, and the "belum absen" list with the WA
 * "Ingatkan wali" CTA (gated on `attendance.student.remind`).
 */
import { computed, onMounted, ref, watch } from 'vue';
import { AttendanceDailyService } from '@/services/attendance-daily.service';
import { AttendanceQrService } from '@/services/attendance-qr.service';
import type {
  DailyRosterResponse,
  DailyStatus,
  DailyRosterRow,
} from '@/types/attendance-daily';
import { STATUS_LABEL, STATUS_TONE, METHOD_LABEL } from '@/types/attendance-daily';
import type { GateQrTokenInfo } from '@/types/attendance-qr';
import { useMeStore } from '@/stores/me';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';
import { useToast } from '@/composables/useToast';

import NavIcon from '@/components/feature/NavIcon.vue';
import SegmentedControl from '@/components/filters/SegmentedControl.vue';

const me = useMeStore();
const toast = useToast();

const date = ref<string>(new Date().toISOString().slice(0, 10));
const search = ref('');
const statusFilter = ref<'all' | 'recorded' | 'unrecorded'>('all');
const tingkat = ref<'all' | number>('all');

const loading = ref(false);
const errorMsg = ref<string | null>(null);
const roster = ref<DailyRosterResponse | null>(null);

const gateQr = ref<GateQrTokenInfo | null>(null);
const gateQrLoading = ref(false);

const canRemind = computed(() => me.can('attendance.student.remind'));

const filteredRows = computed<DailyRosterRow[]>(() => {
  const all = roster.value?.data ?? [];
  const q = search.value.trim().toLowerCase();
  return all.filter((r) => {
    if (statusFilter.value === 'recorded' && r.status === 'not_recorded') return false;
    if (statusFilter.value === 'unrecorded' && r.status !== 'not_recorded') return false;
    if (!q) return true;
    return (
      r.student_name.toLowerCase().includes(q) ||
      r.student_number.toLowerCase().includes(q) ||
      r.class_name.toLowerCase().includes(q)
    );
  });
});

const belumAbsen = computed<DailyRosterRow[]>(
  () => (roster.value?.data ?? []).filter((r) => r.status === 'not_recorded'),
);

const kpi = computed(() => roster.value?.kpi);
const mix = computed(() => roster.value?.method_mix);
const feed = computed(() => roster.value?.recent_check_ins ?? []);
const totalRecorded = computed(() => {
  const k = kpi.value;
  if (!k) return 0;
  return k.hadir + k.terlambat + k.izin + k.sakit + k.alfa;
});
const presencePct = computed(() => {
  const k = kpi.value;
  if (!k || k.total === 0) return 0;
  return Math.round(((k.hadir + k.terlambat) / k.total) * 1000) / 10;
});

const mixMax = computed(() => {
  const m = mix.value;
  if (!m) return 1;
  return Math.max(1, m.QR_GATE, m.QR_CARD, m.SELFIE, m.MANUAL);
});

async function load() {
  loading.value = true;
  errorMsg.value = null;
  try {
    roster.value = await AttendanceDailyService.getDailyRoster({
      date: date.value,
      tingkat: tingkat.value === 'all' ? undefined : tingkat.value,
    });
  } catch (e) {
    errorMsg.value = (e as Error)?.message ?? 'Gagal memuat data harian.';
  } finally {
    loading.value = false;
  }
}

async function loadGate() {
  if (!me.can('attendance.gate_qr.manage')) return;
  gateQrLoading.value = true;
  try {
    gateQr.value = await AttendanceQrService.getCurrentGateQrToken();
  } catch {
    /* silent — right rail hides if unavailable */
  } finally {
    gateQrLoading.value = false;
  }
}

async function rotateGate() {
  if (!me.can('attendance.gate_qr.manage')) return;
  gateQrLoading.value = true;
  try {
    gateQr.value = await AttendanceQrService.rotateGateQrToken();
    toast.success('QR Gerbang diputar.');
  } catch {
    toast.error('Gagal memutar QR gerbang.');
  } finally {
    gateQrLoading.value = false;
  }
}

async function remindAll() {
  const ids = belumAbsen.value.map((r) => r.student_id);
  if (ids.length === 0) return;
  if (!canRemind.value) return;
  const res = await AttendanceDailyService.remindGuardians({ student_ids: ids });
  if (res.status === 'rate_limited') {
    toast.info(
      `Batas 1 pengingat per jam. Coba lagi dalam ${Math.round((res.retry_after ?? 0) / 60)} mnt.`,
    );
    return;
  }
  toast.success(
    `Pengingat dijadwalkan untuk ${res.queued} wali (${res.skipped_no_phone ?? 0} tanpa nomor).`,
  );
}

function stepDate(delta: number) {
  const d = new Date(date.value);
  d.setDate(d.getDate() + delta);
  date.value = d.toISOString().slice(0, 10);
}

function fmtDate(iso: string): string {
  const d = new Date(iso);
  return d.toLocaleDateString('id-ID', {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  });
}

function statusPillClass(status: DailyStatus): string {
  const tone = STATUS_TONE[status];
  return {
    emerald: 'bg-emerald-100 text-emerald-700',
    amber: 'bg-amber-100 text-amber-700',
    sky: 'bg-sky-100 text-sky-700',
    red: 'bg-red-100 text-red-700',
    slate: 'bg-slate-100 text-slate-500',
  }[tone];
}

function dotClass(status: DailyStatus): string {
  const tone = STATUS_TONE[status];
  return {
    emerald: 'bg-emerald-500',
    amber: 'bg-amber-500',
    sky: 'bg-sky-500',
    red: 'bg-red-500',
    slate: 'bg-slate-400',
  }[tone];
}

function methodIcon(method: string | null): string {
  if (!method || method === 'MANUAL') return 'edit';
  if (method === 'SELFIE') return 'camera';
  if (method === 'QR_CARD') return 'id-card';
  return 'qr-code';
}

function avatarInitials(name: string): string {
  return name
    .split(' ')
    .filter(Boolean)
    .slice(0, 2)
    .map((w) => w[0]?.toUpperCase() ?? '')
    .join('');
}

function avatarColor(id: string): { bg: string; fg: string } {
  const palettes = [
    { bg: '#d1fae5', fg: '#047857' },
    { bg: '#dbeafe', fg: '#1d4ed8' },
    { bg: '#fef3c7', fg: '#b45309' },
    { bg: '#e0e7ff', fg: '#4338ca' },
    { bg: '#fce7f3', fg: '#be185d' },
    { bg: '#e0f2fe', fg: '#0369a1' },
    { bg: '#ede9fe', fg: '#6d28d9' },
  ];
  let h = 0;
  for (let i = 0; i < id.length; i++) h = (h * 31 + id.charCodeAt(i)) >>> 0;
  return palettes[h % palettes.length]!;
}

onMounted(() => {
  void load();
  void loadGate();
});
watch(date, () => void load());
watch(tingkat, () => void load());
useAcademicYearWatcher(() => {
  void load();
});
</script>

<template>
  <div class="space-y-md pb-12">
    <!-- Toolbar: date stepper + tingkat + search + status filter -->
    <div class="flex flex-wrap items-center gap-2">
      <div class="inline-flex rounded-lg border border-slate-200 bg-white overflow-hidden">
        <button
          type="button"
          class="px-2 py-2 text-slate-500 hover:bg-slate-50"
          @click="stepDate(-1)"
          aria-label="Sebelumnya"
        >
          <NavIcon name="chevron-left" :size="14" />
        </button>
        <input
          v-model="date"
          type="date"
          class="border-l border-r border-slate-200 px-3 py-2 text-[12px] font-semibold text-slate-900 focus:outline-none tabular-nums"
        />
        <button
          type="button"
          class="px-2 py-2 text-slate-500 hover:bg-slate-50"
          @click="stepDate(1)"
          aria-label="Berikutnya"
        >
          <NavIcon name="chevron-right" :size="14" />
        </button>
      </div>

      <SegmentedControl
        v-model="tingkat as unknown as string"
        :options="[
          { key: 'all', label: 'Semua tingkat' },
          { key: '7', label: 'VII' },
          { key: '8', label: 'VIII' },
          { key: '9', label: 'IX' },
        ]"
      />

      <label class="flex-1 min-w-[200px] flex items-center gap-2 rounded-lg border border-slate-200 bg-white px-3 py-2 text-[12px] text-slate-500">
        <NavIcon name="search" :size="14" />
        <input
          v-model="search"
          type="text"
          placeholder="Cari nama / NIS / kelas…"
          class="flex-1 border-0 outline-none bg-transparent text-slate-900 placeholder:text-slate-400"
        />
      </label>

      <SegmentedControl
        v-model="statusFilter as unknown as string"
        :options="[
          { key: 'all', label: 'Semua' },
          { key: 'recorded', label: 'Sudah absen' },
          { key: 'unrecorded', label: 'Belum absen' },
        ]"
      />
    </div>

    <!-- KPI strip: wide progress + 4 chips (mockup §02) -->
    <div class="grid grid-cols-2 md:grid-cols-5 gap-3">
      <div class="col-span-2 md:col-span-2 rounded-2xl border border-slate-200 bg-white p-4 shadow-card">
        <div class="text-[10px] font-bold uppercase tracking-[.08em] text-slate-400">
          Sudah presensi hari ini
        </div>
        <div class="mt-1 flex items-baseline gap-2">
          <span class="text-[24px] font-bold text-slate-900 tabular-nums">
            {{ kpi?.total ? totalRecorded : '—' }}
          </span>
          <span class="text-[12px] text-slate-500 tabular-nums">
            / {{ kpi?.total ?? 0 }} siswa · {{ presencePct.toFixed(1) }}%
          </span>
        </div>
        <div class="mt-2 h-2.5 rounded-md bg-slate-100 overflow-hidden flex" role="progressbar">
          <span :style="{ width: `${((kpi?.hadir ?? 0) / (kpi?.total || 1)) * 100}%` }" class="bg-emerald-500" />
          <span :style="{ width: `${((kpi?.terlambat ?? 0) / (kpi?.total || 1)) * 100}%` }" class="bg-amber-500" />
          <span :style="{ width: `${(((kpi?.izin ?? 0) + (kpi?.sakit ?? 0)) / (kpi?.total || 1)) * 100}%` }" class="bg-sky-500" />
          <span :style="{ width: `${((kpi?.alfa ?? 0) / (kpi?.total || 1)) * 100}%` }" class="bg-red-500" />
        </div>
        <div class="mt-2 flex flex-wrap gap-3 text-[10.5px] font-semibold text-slate-500">
          <span><b class="text-slate-900">{{ kpi?.hadir ?? 0 }}</b> Hadir</span>
          <span><b class="text-slate-900">{{ kpi?.terlambat ?? 0 }}</b> Terlambat</span>
          <span><b class="text-slate-900">{{ (kpi?.izin ?? 0) + (kpi?.sakit ?? 0) }}</b> Izin/Sakit</span>
          <span><b class="text-slate-900">{{ kpi?.alfa ?? 0 }}</b> Alfa</span>
        </div>
      </div>
      <div class="rounded-2xl border border-slate-200 bg-white p-4 shadow-card">
        <div class="text-[10px] font-bold uppercase tracking-[.08em] text-slate-400 flex items-center gap-1.5">
          <span class="inline-block w-2 h-2 rounded-sm bg-emerald-500" />Hadir
        </div>
        <div class="text-[24px] font-bold text-emerald-700 tabular-nums">{{ kpi?.hadir ?? '—' }}</div>
      </div>
      <div class="rounded-2xl border border-slate-200 bg-white p-4 shadow-card">
        <div class="text-[10px] font-bold uppercase tracking-[.08em] text-slate-400 flex items-center gap-1.5">
          <span class="inline-block w-2 h-2 rounded-sm bg-amber-500" />Terlambat
        </div>
        <div class="text-[24px] font-bold text-amber-700 tabular-nums">{{ kpi?.terlambat ?? '—' }}</div>
      </div>
      <div class="rounded-2xl border border-slate-200 bg-white p-4 shadow-card">
        <div class="text-[10px] font-bold uppercase tracking-[.08em] text-slate-400 flex items-center gap-1.5">
          <span class="inline-block w-2 h-2 rounded-sm bg-sky-500" />Izin · Sakit
        </div>
        <div class="text-[24px] font-bold text-sky-700 tabular-nums">
          {{ (kpi?.izin ?? 0) + (kpi?.sakit ?? 0) }}
        </div>
        <div class="text-[11px] text-slate-500 mt-0.5">
          {{ kpi?.izin ?? 0 }} izin · {{ kpi?.sakit ?? 0 }} sakit
        </div>
      </div>
    </div>

    <!-- Body: roster + right rail -->
    <div class="grid grid-cols-1 lg:grid-cols-[1fr_336px] gap-4">
      <!-- Roster card -->
      <div class="rounded-2xl border border-slate-200 bg-white shadow-card overflow-hidden">
        <div class="flex items-center gap-2 px-4 py-3.5 border-b border-slate-100">
          <h4 class="text-[13.5px] font-bold text-slate-900">Presensi siswa · {{ fmtDate(date) }}</h4>
          <span class="text-[11px] text-slate-400 font-semibold">
            {{ filteredRows.length }} / {{ kpi?.total ?? 0 }} siswa
          </span>
        </div>

        <div v-if="loading" class="p-10 text-center text-slate-400 text-sm">Memuat data…</div>
        <div v-else-if="errorMsg" class="p-6 text-sm text-red-600 border-l-4 border-red-500 bg-red-50 m-4 rounded">
          {{ errorMsg }}
        </div>
        <div v-else-if="filteredRows.length === 0" class="p-10 text-center text-slate-400 text-sm">
          Tidak ada siswa cocok dengan filter.
        </div>
        <template v-else>
          <div class="hidden md:grid grid-cols-[1fr_88px_92px_130px_120px_36px] gap-2.5 px-4 py-2 text-[10px] font-bold uppercase tracking-[.08em] text-slate-400 bg-slate-50 border-b border-slate-100">
            <span>Siswa</span>
            <span>Kelas</span>
            <span>Waktu</span>
            <span>Metode</span>
            <span>Status</span>
            <span />
          </div>
          <div>
            <div
              v-for="row in filteredRows"
              :key="row.student_id"
              class="grid grid-cols-[1fr_88px_92px_130px_120px_36px] gap-2.5 items-center px-4 py-2.5 border-b border-slate-100 text-[12.5px]"
              :class="{ 'bg-[repeating-linear-gradient(135deg,rgba(148,163,184,.06)_0_8px,transparent_8px_16px)]': row.status === 'not_recorded' }"
            >
              <div class="flex items-center gap-3 min-w-0">
                <span
                  class="w-8.5 h-8.5 rounded-[10px] grid place-items-center font-bold text-[12px] shrink-0"
                  :style="{ background: avatarColor(row.student_id).bg, color: avatarColor(row.student_id).fg, width: '34px', height: '34px' }"
                >{{ avatarInitials(row.student_name) }}</span>
                <div class="min-w-0">
                  <div class="font-semibold text-slate-900 truncate">{{ row.student_name }}</div>
                  <div class="text-[10.5px] text-slate-400 font-medium">
                    NIS {{ row.student_number || '—' }}<span v-if="row.note"> · {{ row.note }}</span>
                  </div>
                </div>
              </div>
              <div class="font-semibold text-slate-600">{{ row.class_name }}</div>
              <div class="font-semibold text-slate-900 tabular-nums" :class="{ 'text-slate-400 font-medium': !row.check_in_time }">
                {{ row.check_in_time ?? '—' }}
              </div>
              <div>
                <span
                  v-if="row.check_in_method"
                  class="inline-flex items-center gap-1.5 text-[11px] font-semibold text-slate-600"
                >
                  <NavIcon :name="methodIcon(row.check_in_method)" :size="14" />
                  {{ METHOD_LABEL[row.check_in_method] }}
                </span>
                <span
                  v-else-if="row.status !== 'not_recorded'"
                  class="inline-flex items-center gap-1.5 text-[11px] font-semibold text-slate-400"
                >
                  <NavIcon name="edit" :size="14" />
                  {{ METHOD_LABEL.MANUAL }}
                </span>
                <span v-else class="text-slate-300 text-[11px] font-medium">—</span>
              </div>
              <div>
                <span
                  class="inline-flex items-center gap-1.5 text-[10.5px] font-bold px-2.5 py-1 rounded-full"
                  :class="statusPillClass(row.status)"
                >
                  <span class="w-1.5 h-1.5 rounded-full" :class="dotClass(row.status)" />
                  {{ STATUS_LABEL[row.status] }}
                  <span v-if="row.late_minutes" class="ml-0.5">+{{ row.late_minutes }}m</span>
                </span>
              </div>
              <div class="text-right">
                <button class="w-6.5 h-6.5 rounded-lg text-slate-400 hover:bg-slate-100 grid place-items-center">
                  <NavIcon name="more-vertical" :size="15" />
                </button>
              </div>
            </div>
          </div>
        </template>
      </div>

      <!-- Right rail: QR gate + method mix + live feed + belum-absen -->
      <div class="flex flex-col gap-4">
        <!-- QR gate live card -->
        <div
          v-if="me.can('attendance.gate_qr.manage')"
          class="rounded-2xl p-4 text-white shadow-card"
          style="background: linear-gradient(150deg, #0A1F4D, #143068);"
        >
          <div class="flex items-center gap-2 text-[10.5px] font-bold uppercase tracking-[.14em] text-sky-200">
            <NavIcon name="qr-code" :size="15" />QR Gerbang · aktif
          </div>
          <div class="mt-3 mx-auto w-[150px] h-[150px] rounded-[14px] bg-white p-2.5">
            <div v-if="gateQr" class="w-full h-full grid place-items-center text-navy-900 text-[11px] font-mono font-bold">
              <!-- Real QR is drawn by qrcode.vue in GateQrDisplayView; the rail
                   just shows a compact placeholder + the current token id -->
              {{ gateQr.token.slice(0, 10) }}…
            </div>
            <div v-else class="w-full h-full grid place-items-center text-slate-400 text-[10px]">
              Memuat…
            </div>
          </div>
          <div class="text-center font-mono text-[12px] font-semibold tracking-[.14em] text-sky-100">
            {{ gateQr ? gateQr.token.slice(-10).toUpperCase() : '—' }}
          </div>
          <div class="mt-2 flex items-center justify-center gap-2 text-[11px] text-sky-200">
            <button
              class="text-white hover:text-sky-200 disabled:opacity-50"
              :disabled="gateQrLoading"
              @click="rotateGate"
              aria-label="Rotasi sekarang"
            >
              <NavIcon name="refresh-cw" :size="13" />
            </button>
            Rotasi otomatis dalam
            <span class="tabular-nums font-bold text-white">
              {{ gateQr ? Math.max(0, gateQr.seconds_until_rotation) + 's' : '—' }}
            </span>
          </div>

          <!-- Method mix bars -->
          <div class="mt-4 space-y-2">
            <div
              v-for="key in ['QR_GATE', 'QR_CARD', 'SELFIE', 'MANUAL']"
              :key="key"
              class="flex items-center gap-2.5 text-[11.5px]"
            >
              <span class="w-6 h-6 rounded-md bg-white/10 grid place-items-center shrink-0">
                <NavIcon :name="methodIcon(key)" :size="13" class="text-sky-200" />
              </span>
              <span class="text-sky-100 font-medium w-[78px] shrink-0">{{ METHOD_LABEL[key] }}</span>
              <span class="flex-1 h-1.5 rounded-md bg-white/10 overflow-hidden">
                <span
                  class="block h-full bg-gradient-to-r from-sky-400 to-sky-200"
                  :style="{ width: mix ? ((mix[key as keyof typeof mix] / mixMax) * 100) + '%' : '0%' }"
                />
              </span>
              <span class="w-[34px] text-right font-bold tabular-nums">
                {{ mix ? mix[key as keyof typeof mix] : 0 }}
              </span>
            </div>
          </div>
        </div>

        <!-- Live feed -->
        <div class="rounded-2xl border border-slate-200 bg-white shadow-card overflow-hidden">
          <div class="flex items-center gap-2 px-4 py-3.5 border-b border-slate-100">
            <h4 class="text-[13.5px] font-bold text-slate-900">Check-in terbaru</h4>
            <span class="ml-auto inline-flex items-center gap-1.5 bg-emerald-100 text-emerald-700 text-[10.5px] font-bold tracking-[.08em] px-2.5 py-0.5 rounded-full">
              <span class="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse" />LIVE
            </span>
          </div>
          <div v-if="feed.length === 0" class="p-6 text-center text-slate-400 text-[12px]">
            Belum ada check-in.
          </div>
          <div v-else>
            <div
              v-for="(f, i) in feed"
              :key="`${f.student_id}-${i}`"
              class="flex items-center gap-2.5 px-4 py-2.5 border-b border-slate-100 last:border-0"
            >
              <span class="text-[11px] text-slate-400 w-[38px] tabular-nums font-semibold">{{ f.time }}</span>
              <span class="flex-1 text-[12px] font-semibold text-slate-900 truncate">{{ f.student_name }}</span>
              <span class="text-[9.5px] text-slate-400 font-medium whitespace-nowrap">
                {{ f.class_name }} · {{ METHOD_LABEL[f.method] ?? f.method }}
              </span>
            </div>
          </div>
        </div>

        <!-- Belum absen -->
        <div class="rounded-2xl border border-slate-200 bg-white shadow-card p-4">
          <div class="flex items-center gap-2.5 mb-2.5">
            <span class="w-9.5 h-9.5 rounded-[11px] bg-red-100 text-red-700 font-bold text-[14px] grid place-items-center" style="width:38px;height:38px">
              {{ belumAbsen.length }}
            </span>
            <div>
              <h4 class="text-[13px] font-bold text-slate-900">Belum absen</h4>
              <div class="text-[11px] text-slate-500 font-medium">
                <span v-if="belumAbsen.length === 0">Semua siswa sudah tercatat 🎉</span>
                <span v-else>{{ belumAbsen.length }} siswa belum scan</span>
              </div>
            </div>
          </div>
          <div v-if="belumAbsen.length > 0" class="flex flex-col gap-1 mb-3">
            <div
              v-for="row in belumAbsen.slice(0, 3)"
              :key="row.student_id"
              class="flex items-center gap-2.5 text-[11.5px] py-1"
            >
              <span
                class="w-6.5 h-6.5 rounded-lg grid place-items-center font-bold text-[10px]"
                :style="{ background: avatarColor(row.student_id).bg, color: avatarColor(row.student_id).fg, width: '26px', height: '26px' }"
              >{{ avatarInitials(row.student_name) }}</span>
              <span class="font-semibold text-slate-900 truncate flex-1">{{ row.student_name }}</span>
              <span class="text-[10px] text-slate-400 font-semibold">{{ row.class_name }}</span>
            </div>
            <div v-if="belumAbsen.length > 3" class="text-[10.5px] text-slate-400 pl-8.5 font-semibold">
              +{{ belumAbsen.length - 3 }} lainnya…
            </div>
          </div>
          <button
            v-if="belumAbsen.length > 0 && canRemind"
            type="button"
            class="w-full flex items-center justify-center gap-2 bg-role-admin text-white text-[12px] font-semibold py-2.5 rounded-lg hover:opacity-90 disabled:opacity-50"
            @click="remindAll"
          >
            <NavIcon name="message-circle" :size="15" />
            Ingatkan wali ({{ belumAbsen.length }}) via WhatsApp
          </button>
          <div
            v-else-if="belumAbsen.length > 0 && !canRemind"
            class="w-full text-center text-[11px] text-slate-400 py-2 font-medium"
          >
            Hanya admin yang bisa mengirim pengingat wali.
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
