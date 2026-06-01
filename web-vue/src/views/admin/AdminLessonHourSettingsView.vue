<!--
  AdminLessonHourSettingsView.vue — admin · pengaturan jam pelajaran.

  Day-by-day matrix of lesson hours. Each day has its own column of
  rows with hour_number, start_time, end_time. CRUD via add/edit
  modals; copy-day fanout via the "Salin Hari" action.

  Endpoints:
    GET    /lesson-hour-settings
    POST   /lesson-hour-settings
    PUT    /lesson-hour-settings/{id}
    DELETE /lesson-hour-settings/{id}
    POST   /lesson-hour-settings/copy
    POST   /lesson-hour-settings/bulk-delete
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { LessonHourService } from '@/services/lesson-hour.service';
import { ScheduleService } from '@/services/schedule.service';
import type {
  LessonHour,
  LessonHourPayload,
  ScheduleFilterOptions,
} from '@/types/schedule';
import AsyncView, { type AsyncState } from '@/components/data/AsyncView.vue';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import Toast from '@/components/ui/Toast.vue';
import ConfirmationDialog from '@/components/ui/ConfirmationDialog.vue';
import { useAcademicYearWatcher } from '@/composables/useAcademicYearWatcher';

const hours = ref<LessonHour[]>([]);
const filterOptions = ref<ScheduleFilterOptions | null>(null);
const isLoading = ref(true);
const error = ref<string | null>(null);
const toast = ref<{ message: string; tone: 'success' | 'error' } | null>(null);

const showForm = ref(false);
const editingDayId = ref<string>('');
const editingHour = ref<LessonHour | null>(null);
const formHourNumber = ref<number>(1);
const formStart = ref<string>('07:00');
const formEnd = ref<string>('07:45');
const formRoom = ref<string>('');
const isSaving = ref(false);
const formErr = ref<string | null>(null);

const confirmDelete = ref<LessonHour | null>(null);
const isDeleting = ref(false);

const showCopySheet = ref(false);
const copySourceDayId = ref<string>('');
const copyTargetDayId = ref<string>('');
const copyOverwrite = ref(false);
const isCopying = ref(false);
const copyErr = ref<string | null>(null);

async function load() {
  isLoading.value = true;
  error.value = null;
  try {
    const [list, opts] = await Promise.all([
      LessonHourService.list(),
      ScheduleService.getFilterOptions(),
    ]);
    hours.value = list;
    filterOptions.value = opts;
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

onMounted(load);
useAcademicYearWatcher(load);

const days = computed(() => filterOptions.value?.days ?? []);

const hoursByDay = computed<Record<string, LessonHour[]>>(() => {
  const out: Record<string, LessonHour[]> = {};
  for (const h of hours.value) {
    const list = out[h.day_id] ?? [];
    list.push(h);
    out[h.day_id] = list;
  }
  for (const list of Object.values(out)) {
    list.sort((a, b) => a.hour_number - b.hour_number);
  }
  return out;
});

const listState = computed<AsyncState<LessonHour[]>>(() => {
  if (isLoading.value && hours.value.length === 0) return { status: 'loading' };
  if (error.value) return { status: 'error', error: error.value };
  if (hours.value.length === 0) return { status: 'empty' };
  return { status: 'content', data: hours.value };
});

function openAdd(dayId: string) {
  editingHour.value = null;
  editingDayId.value = dayId;
  const existing = hoursByDay.value[dayId] ?? [];
  formHourNumber.value = (existing[existing.length - 1]?.hour_number ?? 0) + 1;
  const lastEnd = existing[existing.length - 1]?.end_time ?? '07:00';
  formStart.value = lastEnd;
  formEnd.value = addMinutes(lastEnd, 45);
  formRoom.value = '';
  formErr.value = null;
  showForm.value = true;
}

function openEdit(h: LessonHour) {
  editingHour.value = h;
  editingDayId.value = h.day_id;
  formHourNumber.value = h.hour_number;
  formStart.value = h.start_time;
  formEnd.value = h.end_time;
  formRoom.value = h.room ?? '';
  formErr.value = null;
  showForm.value = true;
}

function addMinutes(hhmm: string, mins: number): string {
  const [h, m] = hhmm.split(':').map(Number);
  if (!Number.isFinite(h) || !Number.isFinite(m)) return hhmm;
  const total = h * 60 + m + mins;
  const nh = Math.floor((total % 1440) / 60);
  const nm = total % 60;
  return `${String(nh).padStart(2, '0')}:${String(nm).padStart(2, '0')}`;
}

async function save() {
  if (!editingDayId.value) {
    formErr.value = 'Pilih hari terlebih dulu.';
    return;
  }
  if (formHourNumber.value < 1) {
    formErr.value = 'Jam ke- harus ≥ 1.';
    return;
  }
  if (!formStart.value || !formEnd.value) {
    formErr.value = 'Isi waktu mulai & selesai.';
    return;
  }
  isSaving.value = true;
  formErr.value = null;
  try {
    const payload: LessonHourPayload = {
      day_id: editingDayId.value,
      hour_number: formHourNumber.value,
      start_time: formStart.value,
      end_time: formEnd.value,
      room: formRoom.value || null,
    };
    if (editingHour.value) {
      await LessonHourService.update(editingHour.value.id, payload);
      toast.value = { message: 'Jam pelajaran diperbarui.', tone: 'success' };
    } else {
      await LessonHourService.create(payload);
      toast.value = { message: 'Jam pelajaran ditambahkan.', tone: 'success' };
    }
    showForm.value = false;
    await load();
  } catch (e) {
    formErr.value = (e as Error).message;
  } finally {
    isSaving.value = false;
  }
}

async function doDelete() {
  if (!confirmDelete.value) return;
  isDeleting.value = true;
  try {
    await LessonHourService.destroy(confirmDelete.value.id);
    toast.value = { message: 'Jam pelajaran dihapus.', tone: 'success' };
    await load();
  } catch (e) {
    toast.value = { message: (e as Error).message, tone: 'error' };
  } finally {
    isDeleting.value = false;
    confirmDelete.value = null;
  }
}

async function copyDay() {
  if (!copySourceDayId.value || !copyTargetDayId.value) {
    copyErr.value = 'Pilih hari sumber & tujuan.';
    return;
  }
  if (copySourceDayId.value === copyTargetDayId.value) {
    copyErr.value = 'Hari sumber tidak boleh sama dengan tujuan.';
    return;
  }
  isCopying.value = true;
  copyErr.value = null;
  try {
    const res = await LessonHourService.copyDay({
      source_day_id: copySourceDayId.value,
      target_day_id: copyTargetDayId.value,
      overwrite: copyOverwrite.value,
    });
    toast.value = {
      message: `${res.copied_count} jam disalin.`,
      tone: 'success',
    };
    showCopySheet.value = false;
    copySourceDayId.value = '';
    copyTargetDayId.value = '';
    copyOverwrite.value = false;
    await load();
  } catch (e) {
    copyErr.value = (e as Error).message;
  } finally {
    isCopying.value = false;
  }
}

function dayName(id: string): string {
  return days.value.find((d) => d.id === id)?.name ?? '—';
}
</script>

<template>
  <div class="space-y-md pb-12">
    <BrandPageHeader
      role="admin"
      kicker="Admin · Jadwal"
      title="Pengaturan Jam Pelajaran"
      :meta="`${hours.length} slot terdaftar untuk ${days.length} hari`"
    >
      <Button variant="secondary" size="sm" @click="showCopySheet = true">
        <NavIcon name="copy" :size="12" />
        Salin Hari
      </Button>
    </BrandPageHeader>

    <AsyncView
      :state="listState"
      empty-title="Belum ada jam pelajaran"
      empty-description="Tambah jam pelajaran per hari untuk membuka form jadwal."
      empty-icon="clock"
      @retry="load"
    >
      <template #default>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
          <section
            v-for="d in days"
            :key="d.id"
            class="bg-white border border-slate-200 rounded-2xl p-4 space-y-3"
          >
            <header class="flex items-center justify-between">
              <div>
                <h3 class="text-[13px] font-black text-slate-900">{{ d.name }}</h3>
                <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">
                  {{ hoursByDay[d.id]?.length ?? 0 }} jam
                </p>
              </div>
              <Button variant="secondary" size="sm" @click="openAdd(d.id)">
                <NavIcon name="plus" :size="11" />
                Tambah
              </Button>
            </header>

            <div v-if="(hoursByDay[d.id]?.length ?? 0) === 0" class="text-[11px] text-slate-400 text-center py-4">
              Belum ada jam.
            </div>
            <div v-else class="divide-y divide-slate-100">
              <div
                v-for="h in hoursByDay[d.id]"
                :key="h.id"
                class="flex items-center gap-2 py-2"
              >
                <div class="w-10 text-center flex-shrink-0">
                  <p class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">JP</p>
                  <p class="text-[14px] font-black text-role-admin">{{ h.hour_number }}</p>
                </div>
                <div class="flex-1 min-w-0">
                  <p class="text-[12px] font-bold text-slate-900 tabular-nums">
                    {{ h.start_time }}–{{ h.end_time }}
                  </p>
                  <p v-if="h.room" class="text-[10px] text-slate-500">{{ h.room }}</p>
                </div>
                <button
                  type="button"
                  class="p-1.5 text-slate-400 hover:text-role-admin"
                  @click="openEdit(h)"
                >
                  <NavIcon name="edit" :size="13" />
                </button>
                <button
                  type="button"
                  class="p-1.5 text-slate-400 hover:text-red-600"
                  @click="confirmDelete = h"
                >
                  <NavIcon name="trash-2" :size="13" />
                </button>
              </div>
            </div>
          </section>
        </div>
      </template>
    </AsyncView>

    <!-- Add/Edit form modal -->
    <Modal
      v-if="showForm"
      :title="editingHour ? 'Edit Jam Pelajaran' : 'Tambah Jam Pelajaran'"
      :subtitle="`Hari ${dayName(editingDayId)}`"
      size="sm"
      @close="showForm = false"
    >
      <div class="space-y-3">
        <div>
          <label class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Jam ke-</label>
          <input
            v-model.number="formHourNumber"
            type="number"
            min="1"
            class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
          />
        </div>
        <div class="grid grid-cols-2 gap-3">
          <div>
            <label class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Mulai</label>
            <input
              v-model="formStart"
              type="time"
              class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
            />
          </div>
          <div>
            <label class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Selesai</label>
            <input
              v-model="formEnd"
              type="time"
              class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
            />
          </div>
        </div>
        <div>
          <label class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Ruangan (opsional)</label>
          <input
            v-model="formRoom"
            type="text"
            placeholder="R-101"
            class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
          />
        </div>

        <p v-if="formErr" class="text-[11px] text-red-700 bg-red-50 border border-red-200 rounded-xl p-3">
          {{ formErr }}
        </p>

        <div class="grid grid-cols-2 gap-2 pt-2">
          <Button variant="secondary" block @click="showForm = false">Batal</Button>
          <Button variant="primary" block :loading="isSaving" @click="save">
            {{ editingHour ? 'Simpan' : 'Tambah' }}
          </Button>
        </div>
      </div>
    </Modal>

    <!-- Copy-day sheet -->
    <Modal
      v-if="showCopySheet"
      title="Salin Hari"
      subtitle="Duplikat semua jam pelajaran dari satu hari ke hari lain"
      size="md"
      @close="showCopySheet = false"
    >
      <div class="space-y-3">
        <div>
          <label class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Sumber</label>
          <select
            v-model="copySourceDayId"
            class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
          >
            <option value="">— pilih hari —</option>
            <option v-for="d in days" :key="d.id" :value="d.id">{{ d.name }}</option>
          </select>
        </div>
        <div>
          <label class="text-[10px] font-bold text-slate-400 uppercase tracking-widest">Tujuan</label>
          <select
            v-model="copyTargetDayId"
            class="mt-1 w-full bg-slate-50 border border-slate-200 rounded-xl px-3 py-2 text-[13px] font-bold text-slate-900 outline-none focus:border-role-admin"
          >
            <option value="">— pilih hari —</option>
            <option v-for="d in days" :key="d.id" :value="d.id">{{ d.name }}</option>
          </select>
        </div>
        <label class="flex items-center gap-2 text-[11px] font-bold text-slate-700 cursor-pointer">
          <input v-model="copyOverwrite" type="checkbox" class="accent-role-admin" />
          Timpa jam yang sudah ada di hari tujuan
        </label>

        <p v-if="copyErr" class="text-[11px] text-red-700 bg-red-50 border border-red-200 rounded-xl p-3">
          {{ copyErr }}
        </p>

        <div class="grid grid-cols-2 gap-2 pt-2">
          <Button variant="secondary" block @click="showCopySheet = false">Batal</Button>
          <Button variant="primary" block :loading="isCopying" @click="copyDay">
            Salin
          </Button>
        </div>
      </div>
    </Modal>

    <ConfirmationDialog
      v-if="confirmDelete"
      title="Hapus Jam Pelajaran"
      :message="`Hapus jam ke-${confirmDelete.hour_number} (${confirmDelete.start_time}–${confirmDelete.end_time})? Jadwal yang terikat ke jam ini akan gagal load.`"
      confirm-label="Hapus"
      danger
      :loading="isDeleting"
      @close="confirmDelete = null"
      @confirm="doDelete"
    />

    <Toast v-if="toast" :message="toast.message" :tone="toast.tone" @close="toast = null" />
  </div>
</template>
