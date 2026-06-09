<!--
  TutorCreateSessionView — schedule a single bimbel session. Web mirror
  of the Flutter `tutor_create_session_screen.dart`. Pick group → date →
  time → duration/room/topic → submit. The session inherits the group's
  default tutor server-side.
-->
<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import type { TutoringGroup } from '@/types/tutoring';

const router = useRouter();
const toast = useToast();

const loading = ref(true);
const saving = ref(false);
const groups = ref<TutoringGroup[]>([]);

const groupId = ref<string | null>(null);
const date = ref<string>(''); // yyyy-mm-dd
const time = ref<string>('15:00');
const duration = ref<number>(90);
const room = ref('');
const topic = ref('');

async function load() {
  loading.value = true;
  try {
    // All tenant groups (no program filter) — a tutor may lead groups
    // across programs.
    groups.value = await TutoringService.getAllGroups();
  } catch (e) {
    toast.error(e instanceof Error ? e.message : 'Gagal memuat kelompok.');
  } finally {
    loading.value = false;
  }
}

async function submit() {
  if (!groupId.value) {
    toast.error('Pilih kelompok dulu.');
    return;
  }
  if (!date.value) {
    toast.error('Pilih tanggal.');
    return;
  }
  saving.value = true;
  try {
    await TutoringService.createSession({
      group_id: groupId.value,
      scheduled_at: new Date(`${date.value}T${time.value}:00`).toISOString(),
      duration_minutes: duration.value,
      room: room.value.trim() || undefined,
      topic: topic.value.trim() || undefined,
    });
    toast.success('Sesi dibuat.');
    router.back();
  } catch (e) {
    toast.error(e instanceof Error ? e.message : 'Gagal membuat sesi.');
  } finally {
    saving.value = false;
  }
}

onMounted(load);
</script>

<template>
  <div class="mx-auto max-w-2xl p-4">
    <h1 class="mb-4 text-lg font-bold text-slate-800">Buat Sesi</h1>

    <div v-if="loading" class="py-16 text-center text-slate-500">Memuat…</div>

    <p
      v-else-if="groups.length === 0"
      class="py-12 text-center text-slate-500"
    >
      Belum ada kelompok. Minta admin membuat kelompok dulu.
    </p>

    <div v-else class="space-y-3">
      <label class="block">
        <span class="text-sm font-semibold text-slate-700">Kelompok</span>
        <select
          v-model="groupId"
          class="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2"
        >
          <option :value="null" disabled>Pilih kelompok</option>
          <option v-for="g in groups" :key="g.id" :value="g.id">
            {{ g.name }}
          </option>
        </select>
      </label>

      <div class="flex gap-2">
        <label class="block flex-1">
          <span class="text-sm font-semibold text-slate-700">Tanggal</span>
          <input
            v-model="date"
            type="date"
            class="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2"
          />
        </label>
        <label class="block w-32">
          <span class="text-sm font-semibold text-slate-700">Jam</span>
          <input
            v-model="time"
            type="time"
            class="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2"
          />
        </label>
      </div>

      <label class="block">
        <span class="text-sm font-semibold text-slate-700">Durasi (menit)</span>
        <select
          v-model.number="duration"
          class="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2"
        >
          <option :value="60">60 menit</option>
          <option :value="90">90 menit</option>
          <option :value="120">120 menit</option>
          <option :value="150">150 menit</option>
        </select>
      </label>

      <label class="block">
        <span class="text-sm font-semibold text-slate-700">Ruang (opsional)</span>
        <input
          v-model="room"
          class="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2"
        />
      </label>

      <label class="block">
        <span class="text-sm font-semibold text-slate-700">Topik (opsional)</span>
        <input
          v-model="topic"
          class="mt-1 w-full rounded-lg border border-slate-300 px-3 py-2"
        />
      </label>

      <button
        :disabled="saving"
        class="w-full rounded-lg bg-teal-700 px-4 py-2.5 font-semibold text-white disabled:opacity-50"
        @click="submit"
      >
        {{ saving ? 'Menyimpan…' : 'Simpan Sesi' }}
      </button>
    </div>
  </div>
</template>
