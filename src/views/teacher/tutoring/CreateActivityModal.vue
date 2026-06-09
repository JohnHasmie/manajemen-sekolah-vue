<!--
  CreateActivityModal — bottom-sheet-style form for POST /tutoring/
  activities. Group + type + title + optional description + optional
  tenggat. On success, emits `done` so the parent reloads.
-->
<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import type { TutoringGroup } from '@/types/tutoring';

const { t } = useI18n();

const emit = defineEmits<{
  (e: 'close'): void;
  (e: 'done'): void;
}>();

const groups = ref<TutoringGroup[]>([]);
const groupId = ref('');
const type = ref<'HOMEWORK' | 'EXAM' | 'QUIZ' | 'PROJECT'>('HOMEWORK');
const title = ref('');
const description = ref('');
const dueDate = ref(''); // yyyy-mm-dd
const dueTime = ref('17:00');
const saving = ref(false);
const errMsg = ref<string | null>(null);

onMounted(async () => {
  try {
    groups.value = await TutoringService.getAllGroups();
    if (groups.value[0]) groupId.value = groups.value[0].id;
  } catch {/* non-fatal */}
});

async function submit() {
  if (!groupId.value) {
    errMsg.value = 'Pilih kelompok dulu.';
    return;
  }
  if (title.value.trim().length < 3) {
    errMsg.value = 'Judul minimal 3 karakter.';
    return;
  }
  saving.value = true;
  errMsg.value = null;
  try {
    const dueIso = dueDate.value
      ? new Date(`${dueDate.value}T${dueTime.value}:00`).toISOString()
      : null;
    await TutoringService.createActivity({
      tutoring_group_id: groupId.value,
      type: type.value,
      title: title.value.trim(),
      description: description.value.trim() || undefined,
      due_at: dueIso,
    });
    emit('done');
  } catch (e) {
    errMsg.value = e instanceof Error ? e.message : String(e);
  } finally {
    saving.value = false;
  }
}
</script>

<template>
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/40 p-4"
    @click.self="emit('close')"
  >
    <div class="w-full max-w-md bg-white rounded-2xl p-5 sm:p-6">
      <h2 class="text-base font-bold text-slate-900 tracking-tight">
        Aktivitas Baru
      </h2>
      <p class="text-xs text-slate-500 mt-1">
        Beri tugas / quiz / ujian untuk kelompok.
      </p>

      <div class="mt-4 space-y-3">
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
        <label class="block">
          <span class="text-[10.5px] font-bold text-slate-500 uppercase tracking-wider">
            Tipe
          </span>
          <select
            v-model="type"
            class="mt-1.5 w-full rounded-lg border border-slate-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-teacher/20 focus:border-role-teacher"
          >
            <option value="HOMEWORK">PR</option>
            <option value="EXAM">Ujian</option>
            <option value="QUIZ">Quiz</option>
            <option value="PROJECT">Proyek</option>
          </select>
        </label>
        <label class="block">
          <span class="text-[10.5px] font-bold text-slate-500 uppercase tracking-wider">
            Judul
          </span>
          <input
            v-model="title"
            class="mt-1.5 w-full rounded-lg border border-slate-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-teacher/20 focus:border-role-teacher"
            placeholder="cth. Latihan Trigonometri Bab 3"
          />
        </label>
        <label class="block">
          <span class="text-[10.5px] font-bold text-slate-500 uppercase tracking-wider">
            Deskripsi / instruksi (opsional)
          </span>
          <textarea
            v-model="description"
            rows="3"
            class="mt-1.5 w-full rounded-lg border border-slate-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-teacher/20 focus:border-role-teacher resize-none"
          />
        </label>
        <div class="flex gap-2">
          <label class="block flex-1">
            <span class="text-[10.5px] font-bold text-slate-500 uppercase tracking-wider">
              Tenggat (opsional)
            </span>
            <input
              v-model="dueDate"
              type="date"
              class="mt-1.5 w-full rounded-lg border border-slate-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-teacher/20 focus:border-role-teacher"
            />
          </label>
          <label class="block w-32">
            <span class="text-[10.5px] font-bold text-slate-500 uppercase tracking-wider">
              Jam
            </span>
            <input
              v-model="dueTime"
              type="time"
              class="mt-1.5 w-full rounded-lg border border-slate-200 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-role-teacher/20 focus:border-role-teacher"
            />
          </label>
        </div>
        <p v-if="errMsg" class="text-xs text-status-danger">{{ errMsg }}</p>
      </div>

      <div class="mt-5 flex items-center gap-2 justify-end">
        <button
          type="button"
          class="rounded-lg px-3 py-2 text-sm font-semibold text-slate-700 hover:bg-slate-100"
          @click="emit('close')"
        >
          {{ t('tutoring.common.close') }}
        </button>
        <button
          type="button"
          :disabled="saving"
          class="rounded-lg bg-role-teacher hover:bg-role-teacher/90 px-4 py-2 text-sm font-semibold text-white disabled:opacity-50"
          @click="submit"
        >
          {{ saving ? t('tutoring.common.saving') : 'Simpan Aktivitas' }}
        </button>
      </div>
    </div>
  </div>
</template>
