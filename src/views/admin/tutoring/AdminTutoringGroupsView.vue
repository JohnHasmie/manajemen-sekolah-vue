<!--
  AdminTutoringGroupsView — list of all kelompok in this tenant with
  full CRUD (create + edit + delete + assign tutor) per card.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import type { TutoringGroup, TutoringProgram, TutoringTutorRow } from '@/types/tutoring';

import TutorBerandaHero from '@/components/feature/tutoring/TutorBerandaHero.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import AdminActionMenu from '@/components/feature/tutoring/AdminActionMenu.vue';
import AdminConfirmDialog from '@/components/feature/tutoring/AdminConfirmDialog.vue';

const router = useRouter();
const toast = useToast();

const loading = ref(true);
const groups = ref<TutoringGroup[]>([]);
const programs = ref<TutoringProgram[]>([]);
const tutors = ref<TutoringTutorRow[]>([]);
const query = ref('');
const status = ref<'all' | 'active' | 'full' | 'closed'>('all');

type ModalKind = null | 'create' | 'edit' | 'assign' | 'delete';
const modal = ref<ModalKind>(null);
const target = ref<TutoringGroup | null>(null);
const saving = ref(false);

const form = ref({ name: '', capacity: 10, program_id: '', tutor_user_id: '' });

async function load() {
  loading.value = true;
  try {
    [groups.value, programs.value, tutors.value] = await Promise.all([
      TutoringService.getAllGroups(),
      TutoringService.getPrograms(),
      TutoringService.getAdminTutors(),
    ]);
  } catch {/* non-fatal */}
  finally { loading.value = false; }
}
onMounted(load);

const filtered = computed(() => {
  let list = groups.value;
  if (status.value === 'active') list = list.filter((g) => /active|aktif|open/i.test(g.status));
  if (status.value === 'full') list = list.filter((g) => (g.enrollments_count ?? 0) >= g.capacity);
  if (status.value === 'closed') list = list.filter((g) => /closed|selesai/i.test(g.status));
  const q = query.value.trim().toLowerCase();
  if (q) list = list.filter((g) => g.name.toLowerCase().includes(q));
  return list;
});

const needsAttention = computed(() => groups.value.filter((g) => !g.tutor_user_id).length);

function programNameFor(g: TutoringGroup): string {
  return programs.value.find((p) => p.id === g.program_id)?.name ?? '—';
}

function openCreate() {
  target.value = null;
  form.value = { name: '', capacity: 10, program_id: programs.value[0]?.id ?? '', tutor_user_id: '' };
  modal.value = 'create';
}

function pickAction(g: TutoringGroup, key: string) {
  target.value = g;
  if (key === 'edit') {
    form.value = { name: g.name, capacity: g.capacity, program_id: g.program_id, tutor_user_id: '' };
    modal.value = 'edit';
  } else if (key === 'assign') {
    form.value = { ...form.value, tutor_user_id: g.tutor_user_id ?? '' };
    modal.value = 'assign';
  } else if (key === 'delete') {
    modal.value = 'delete';
  } else if (key === 'open') {
    router.push({ name: 'admin.tutoring.group-detail', params: { groupId: g.id } });
  }
}

async function submitCreate() {
  if (form.value.name.trim().length < 3) { toast.error('Nama minimal 3 huruf'); return; }
  if (!form.value.program_id) { toast.error('Pilih program'); return; }
  saving.value = true;
  try {
    await TutoringService.createGroup({
      program_id: form.value.program_id,
      name: form.value.name.trim(),
      capacity: form.value.capacity,
      tutor_user_id: form.value.tutor_user_id || undefined,
    });
    toast.success('Kelompok dibuat.');
    modal.value = null;
    await load();
  } catch (e) { toast.error(e instanceof Error ? e.message : 'Gagal membuat.'); }
  finally { saving.value = false; }
}

async function submitEdit() {
  if (!target.value) return;
  if (form.value.name.trim().length < 3) { toast.error('Nama minimal 3 huruf'); return; }
  saving.value = true;
  try {
    await TutoringService.updateGroup(target.value.id, {
      name: form.value.name.trim(),
      capacity: form.value.capacity,
    });
    toast.success('Kelompok diperbarui.');
    modal.value = null;
    await load();
  } catch (e) { toast.error(e instanceof Error ? e.message : 'Gagal menyimpan.'); }
  finally { saving.value = false; }
}

async function submitAssign() {
  if (!target.value) return;
  saving.value = true;
  try {
    await TutoringService.assignGroupTutor(target.value.id, form.value.tutor_user_id || null);
    toast.success('Tutor diperbarui.');
    modal.value = null;
    await load();
  } catch (e) { toast.error(e instanceof Error ? e.message : 'Gagal menugaskan tutor.'); }
  finally { saving.value = false; }
}

async function submitDelete() {
  if (!target.value) return;
  saving.value = true;
  try {
    await TutoringService.deleteGroup(target.value.id);
    toast.success('Kelompok dihapus.');
    modal.value = null;
    await load();
  } catch (e) { toast.error(e instanceof Error ? e.message : 'Gagal menghapus.'); }
  finally { saving.value = false; }
}

function cardActions(g: TutoringGroup) {
  return [
    { key: 'open', label: 'Lihat detail', icon: 'chevron-right' },
    { key: 'edit', label: 'Ubah kelompok', icon: 'edit' },
    { key: 'assign', label: g.tutor_user_id ? 'Ganti tutor' : 'Tugaskan tutor', icon: 'user-check' },
    { key: 'delete', label: 'Hapus kelompok', icon: 'trash-2', danger: true },
  ];
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <TutorBerandaHero
      greeting="BIMBEL · KELOMPOK"
      title="Daftar kelompok"
      :subtitle="`${groups.length} aktif · ${needsAttention} perlu tutor`"
      :stats="[]"
    >
      <template #actions>
        <button
          type="button"
          class="rounded-lg bg-white text-bimbel-accent px-3 py-1.5 text-[13px] font-bold hover:opacity-90"
          @click="openCreate"
        >
          <NavIcon name="plus" :size="13" class="inline -mt-0.5" /> Buat kelompok
        </button>
      </template>
    </TutorBerandaHero>

    <div class="flex flex-wrap items-center gap-2">
      <div class="relative min-w-0 flex-1">
        <NavIcon name="search" :size="14" class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-bimbel-text-lo" />
        <input
          v-model="query"
          type="text"
          placeholder="Cari kelompok…"
          class="w-full rounded-xl border border-bimbel-border bg-bimbel-panel pl-9 pr-3 py-2 text-[14px] text-bimbel-text-hi placeholder:text-bimbel-text-lo focus:border-bimbel-accent focus:outline-none"
        />
      </div>
      <div class="flex gap-1.5">
        <button
          v-for="opt in [
            { id: 'all' as const, label: 'Semua' },
            { id: 'active' as const, label: 'Aktif' },
            { id: 'full' as const, label: 'Penuh' },
            { id: 'closed' as const, label: 'Selesai' },
          ]"
          :key="opt.id"
          type="button"
          class="rounded-full border px-3 py-1.5 text-[13px] font-semibold"
          :class="status === opt.id ? 'border-bimbel-accent bg-bimbel-accent-dim text-bimbel-accent' : 'border-bimbel-border bg-bimbel-panel text-bimbel-text-mid'"
          @click="status = opt.id"
        >{{ opt.label }}</button>
      </div>
    </div>

    <div v-if="loading" class="py-12 text-center text-bimbel-text-mid">Memuat…</div>

    <div v-else-if="filtered.length" class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
      <div
        v-for="g in filtered"
        :key="g.id"
        class="group relative rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-3.5 transition hover:border-bimbel-accent/40"
      >
        <div class="flex items-start justify-between gap-2">
          <button
            type="button"
            class="min-w-0 text-left flex-1"
            @click="router.push({ name: 'admin.tutoring.group-detail', params: { groupId: g.id } })"
          >
            <p class="text-[14px] font-bold text-bimbel-text-hi truncate">{{ g.name }}</p>
            <p class="text-[12px] text-bimbel-text-mid truncate">{{ programNameFor(g) }}</p>
          </button>
          <AdminActionMenu
            :items="cardActions(g)"
            aria-label="Aksi kelompok"
            @pick="(k) => pickAction(g, k)"
          />
        </div>
        <div class="mt-2.5 flex items-center gap-2 text-[12px] text-bimbel-text-mid">
          <span class="inline-flex items-center gap-1">
            <NavIcon name="users" :size="12" /> {{ g.enrollments_count ?? 0 }} / {{ g.capacity }}
          </span>
          <span v-if="g.tutor?.name" class="inline-flex items-center gap-1 truncate">
            · <NavIcon name="user-check" :size="12" /> {{ g.tutor.name }}
          </span>
          <span v-else class="inline-flex items-center gap-1 rounded-md bg-amber-500/15 px-1.5 py-0.5 text-[11px] font-bold text-amber-700 dark:text-amber-300">
            <NavIcon name="alert-circle" :size="10" /> Perlu tutor
          </span>
        </div>
      </div>
    </div>

    <div v-else class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-8 text-center text-sm text-bimbel-text-mid">
      Tidak ada kelompok sesuai filter.
    </div>

    <!-- Create / Edit modal -->
    <div v-if="modal === 'create' || modal === 'edit'" class="fixed inset-0 z-50 flex items-start justify-center bg-black/55 p-6" @click.self="modal = null">
      <div class="w-full max-w-md rounded-2xl bg-bimbel-panel p-5 shadow-xl space-y-3">
        <h3 class="text-[16px] font-bold text-bimbel-text-hi">
          {{ modal === 'create' ? 'Kelompok baru' : 'Ubah kelompok' }}
        </h3>
        <label v-if="modal === 'create'" class="block">
          <span class="block text-[12px] font-bold uppercase tracking-wider text-bimbel-text-mid">Program <span class="text-rose-500">*</span></span>
          <select v-model="form.program_id" class="mt-1 w-full rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[13px] text-bimbel-text-hi focus:border-bimbel-accent focus:outline-none">
            <option v-for="p in programs" :key="p.id" :value="p.id">{{ p.name }}</option>
          </select>
        </label>
        <label class="block">
          <span class="block text-[12px] font-bold uppercase tracking-wider text-bimbel-text-mid">Nama kelompok <span class="text-rose-500">*</span></span>
          <input v-model="form.name" type="text" placeholder="SMA-IPA-12-A" class="mt-1 w-full rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[13px] text-bimbel-text-hi focus:border-bimbel-accent focus:outline-none" />
        </label>
        <label class="block">
          <span class="block text-[12px] font-bold uppercase tracking-wider text-bimbel-text-mid">Kapasitas</span>
          <input v-model.number="form.capacity" type="number" min="1" max="100" class="mt-1 w-full rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[13px] text-bimbel-text-hi focus:border-bimbel-accent focus:outline-none" />
        </label>
        <label v-if="modal === 'create'" class="block">
          <span class="block text-[12px] font-bold uppercase tracking-wider text-bimbel-text-mid">Tutor (opsional)</span>
          <select v-model="form.tutor_user_id" class="mt-1 w-full rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[13px] text-bimbel-text-hi focus:border-bimbel-accent focus:outline-none">
            <option value="">— belum ada tutor —</option>
            <option v-for="t in tutors" :key="t.user_id" :value="t.user_id">{{ t.name }}</option>
          </select>
        </label>
        <div class="flex gap-2 pt-1">
          <button type="button" class="flex-1 rounded-lg border border-bimbel-border bg-bimbel-panel px-3 py-2 text-[13px] font-bold text-bimbel-text-hi hover:bg-bimbel-border-soft" @click="modal = null">Batal</button>
          <button type="button" :disabled="saving" class="flex-1 rounded-lg bg-bimbel-accent px-3 py-2 text-[13px] font-bold text-white hover:opacity-90 disabled:opacity-50" @click="modal === 'create' ? submitCreate() : submitEdit()">{{ saving ? 'Menyimpan…' : 'Simpan' }}</button>
        </div>
      </div>
    </div>

    <!-- Assign tutor modal -->
    <div v-if="modal === 'assign'" class="fixed inset-0 z-50 flex items-start justify-center bg-black/55 p-6" @click.self="modal = null">
      <div class="w-full max-w-md rounded-2xl bg-bimbel-panel p-5 shadow-xl space-y-3">
        <h3 class="text-[16px] font-bold text-bimbel-text-hi">Tugaskan tutor</h3>
        <p class="text-[13px] text-bimbel-text-mid">{{ target?.name }}</p>
        <label class="block">
          <span class="block text-[12px] font-bold uppercase tracking-wider text-bimbel-text-mid">Tutor</span>
          <select v-model="form.tutor_user_id" class="mt-1 w-full rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[13px] text-bimbel-text-hi focus:border-bimbel-accent focus:outline-none">
            <option value="">— belum ada tutor —</option>
            <option v-for="t in tutors" :key="t.user_id" :value="t.user_id">{{ t.name }}</option>
          </select>
        </label>
        <div class="flex gap-2 pt-1">
          <button type="button" class="flex-1 rounded-lg border border-bimbel-border bg-bimbel-panel px-3 py-2 text-[13px] font-bold text-bimbel-text-hi hover:bg-bimbel-border-soft" @click="modal = null">Batal</button>
          <button type="button" :disabled="saving" class="flex-1 rounded-lg bg-bimbel-accent px-3 py-2 text-[13px] font-bold text-white hover:opacity-90 disabled:opacity-50" @click="submitAssign">{{ saving ? 'Menyimpan…' : 'Simpan' }}</button>
        </div>
      </div>
    </div>

    <AdminConfirmDialog
      :open="modal === 'delete'"
      title="Hapus kelompok?"
      :message="`Kelompok ${target?.name ?? ''} akan dihapus. Siswa & sesi yang sudah dijadwalkan tidak dapat dipulihkan.`"
      confirm-label="Hapus"
      danger
      :busy="saving"
      @cancel="modal = null"
      @confirm="submitDelete"
    />
  </div>
</template>
