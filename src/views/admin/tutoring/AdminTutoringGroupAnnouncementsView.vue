<!--
  AdminTutoringGroupAnnouncementsView — bimbel pengumuman per
  kelompok. Audience filter (semua / per kelompok) + tulis CTA →
  list of broadcast cards with delivery footer.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';
import { TutoringService } from '@/services/tutoring.service';
import { useToast } from '@/composables/useToast';
import { formatDateShort } from '@/lib/format';
import type {
  TutoringGroup,
  TutoringGroupAnnouncement,
} from '@/types/tutoring';

import TutorBerandaHero from '@/components/feature/tutoring/TutorBerandaHero.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const route = useRoute();
const toast = useToast();

const groupId = ref(String(route.query.groupId ?? ''));
const groups = ref<TutoringGroup[]>([]);
const rows = ref<TutoringGroupAnnouncement[]>([]);
const loading = ref(true);

const showCompose = ref(false);
const fGroupId = ref('');
const fTitle = ref('');
const fBody = ref('');
const saving = ref(false);

async function load() {
  loading.value = true;
  try {
    rows.value = await TutoringService.getGroupAnnouncements(
      groupId.value ? { group_id: groupId.value } : {},
    );
  } catch (e) {
    toast.error(e instanceof Error ? e.message : 'Gagal memuat pengumuman.');
  } finally { loading.value = false; }
}

onMounted(async () => {
  try { groups.value = await TutoringService.getAllGroups(); } catch {/* non-fatal */}
  await load();
});

const totalRecipients = computed(() =>
  groups.value.reduce((s, g) => s + (g.enrollments_count ?? 0), 0),
);

const heroStats = computed(() => [
  { label: 'PENGUMUMAN', value: String(rows.value.length), hint: '30 hari terakhir' },
  { label: 'KELOMPOK', value: String(groups.value.length) },
  { label: 'PENERIMA', value: String(totalRecipients.value) },
]);

function openCompose() {
  fGroupId.value = groupId.value || groups.value[0]?.id || '';
  fTitle.value = '';
  fBody.value = '';
  showCompose.value = true;
}

async function submitCompose() {
  if (!fGroupId.value) { toast.error('Pilih kelompok dulu.'); return; }
  if (fTitle.value.trim().length < 3 || fBody.value.trim().length < 3) {
    toast.error('Judul + isi minimal 3 karakter.'); return;
  }
  saving.value = true;
  try {
    await TutoringService.createGroupAnnouncement({
      tutoring_group_id: fGroupId.value,
      title: fTitle.value.trim(),
      body: fBody.value.trim(),
    });
    toast.success('Terbit.');
    showCompose.value = false;
    await load();
  } catch (e) {
    toast.error(e instanceof Error ? e.message : 'Gagal menerbitkan.');
  } finally { saving.value = false; }
}

async function remove(a: TutoringGroupAnnouncement) {
  if (!window.confirm(`Hapus "${a.title}"?`)) return;
  try { await TutoringService.deleteGroupAnnouncement(a.id); await load(); }
  catch (e) { toast.error(e instanceof Error ? e.message : 'Gagal menghapus.'); }
}

function recipientsFor(a: TutoringGroupAnnouncement): number {
  return groups.value.find((g) => g.id === a.tutoring_group_id)?.enrollments_count ?? 0;
}
</script>

<template>
  <div class="space-y-4 pb-12">
    <TutorBerandaHero
      greeting="BIMBEL · PENGUMUMAN KELOMPOK"
      title="Broadcast & pengumuman"
      :subtitle="`${rows.length} pengumuman${groupId ? ' di kelompok terpilih' : ''}`"
      :stats="heroStats"
    >
      <template #actions>
        <button
          type="button"
          class="rounded-lg bg-white text-bimbel-accent px-3 py-1.5 text-[14px] font-bold"
          @click="openCompose"
        >
          <NavIcon name="plus" :size="13" class="inline -mt-0.5" /> Tulis pengumuman
        </button>
      </template>
    </TutorBerandaHero>

    <div class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-3 flex flex-wrap items-center gap-2">
      <span class="text-[13px] font-bold uppercase tracking-wider text-bimbel-text-mid">Audiens:</span>
      <button
        type="button"
        class="rounded-full border px-3 py-1.5 text-[14px] font-semibold"
        :class="groupId === '' ? 'border-bimbel-accent bg-bimbel-accent-dim text-bimbel-accent' : 'border-bimbel-border bg-bimbel-panel text-bimbel-text-mid'"
        @click="groupId = ''; load()"
      >Semua kelompok</button>
      <button
        v-for="g in groups"
        :key="g.id"
        type="button"
        class="rounded-full border px-3 py-1.5 text-[14px] font-semibold"
        :class="groupId === g.id ? 'border-bimbel-accent bg-bimbel-accent-dim text-bimbel-accent' : 'border-bimbel-border bg-bimbel-panel text-bimbel-text-mid'"
        @click="groupId = g.id; load()"
      >{{ g.name }}</button>
    </div>

    <div v-if="loading" class="py-12 text-center text-bimbel-text-mid">Memuat…</div>

    <div v-else-if="rows.length" class="space-y-2">
      <article v-for="a in rows" :key="a.id" class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-4">
        <div class="flex items-start justify-between gap-2">
          <div class="min-w-0">
            <h3 class="text-[15px] font-bold tracking-tight text-bimbel-text-hi">{{ a.title }}</h3>
            <p class="text-[13px] text-bimbel-text-mid mt-0.5">
              {{ a.group_name ?? '—' }}
              <template v-if="a.author_name"> · oleh {{ a.author_name }}</template>
              <template v-if="a.created_at"> · {{ formatDateShort(a.created_at) }}</template>
            </p>
          </div>
          <button
            type="button"
            class="rounded-md border border-bimbel-border bg-bimbel-panel p-1.5 text-bimbel-text-lo hover:bg-bimbel-border-soft hover:text-rose-500"
            title="Hapus"
            @click="remove(a)"
          >
            <NavIcon name="trash-2" :size="13" />
          </button>
        </div>
        <p class="text-[14px] text-bimbel-text-mid mt-2 whitespace-pre-wrap">{{ a.body }}</p>
        <div class="mt-2.5 flex items-center gap-3 border-t border-bimbel-border-soft pt-2 text-[13px] text-bimbel-text-mid">
          <span class="inline-flex items-center gap-1">
            <NavIcon name="users" :size="12" /> {{ recipientsFor(a) }} penerima
          </span>
          <span class="inline-flex items-center gap-1">
            <NavIcon name="check" :size="12" /> Terkirim aplikasi
          </span>
          <span class="ml-auto inline-flex items-center gap-1">
            <NavIcon name="megaphone" :size="12" /> {{ a.group_name ?? '—' }}
          </span>
        </div>
      </article>
    </div>

    <div v-else class="rounded-2xl border border-bimbel-border-soft bg-bimbel-panel p-8 text-center text-sm text-bimbel-text-mid">
      Belum ada pengumuman. Klik "Tulis pengumuman" untuk membuat broadcast pertama.
    </div>

    <div
      v-if="showCompose"
      class="fixed inset-0 z-50 flex items-start justify-center bg-black/55 p-6"
      @click.self="showCompose = false"
    >
      <div class="w-full max-w-lg rounded-2xl bg-bimbel-panel p-5 shadow-xl space-y-3">
        <h3 class="text-[16px] font-bold text-bimbel-text-hi">Pengumuman baru</h3>
        <label class="block">
          <span class="block text-[13px] font-bold uppercase tracking-wider text-bimbel-text-mid">
            Kelompok <span class="text-rose-500">*</span>
          </span>
          <select
            v-model="fGroupId"
            class="mt-1 w-full rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[14px] text-bimbel-text-hi focus:border-bimbel-accent focus:outline-none"
          >
            <option value="" disabled>Pilih kelompok</option>
            <option v-for="g in groups" :key="g.id" :value="g.id">
              {{ g.name }} ({{ g.enrollments_count ?? 0 }} siswa)
            </option>
          </select>
        </label>
        <label class="block">
          <span class="block text-[13px] font-bold uppercase tracking-wider text-bimbel-text-mid">Judul</span>
          <input
            v-model="fTitle"
            type="text"
            class="mt-1 w-full rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[14px] text-bimbel-text-hi focus:border-bimbel-accent focus:outline-none"
          />
        </label>
        <label class="block">
          <span class="block text-[13px] font-bold uppercase tracking-wider text-bimbel-text-mid">Isi</span>
          <textarea
            v-model="fBody"
            rows="6"
            class="mt-1 w-full rounded-lg border border-bimbel-border bg-bimbel-bg px-3 py-2 text-[14px] text-bimbel-text-hi focus:border-bimbel-accent focus:outline-none resize-none"
          ></textarea>
        </label>
        <div class="flex gap-2 pt-1">
          <button
            type="button"
            class="flex-1 rounded-lg border border-bimbel-border bg-bimbel-panel px-3 py-2 text-[14px] font-bold text-bimbel-text-hi hover:bg-bimbel-border-soft"
            @click="showCompose = false"
          >Batal</button>
          <button
            type="button"
            :disabled="saving"
            class="flex-1 rounded-lg bg-bimbel-accent px-3 py-2 text-[14px] font-bold text-white hover:opacity-90 disabled:opacity-50"
            @click="submitCompose"
          >{{ saving ? 'Mengirim…' : 'Terbitkan' }}</button>
        </div>
      </div>
    </div>
  </div>
</template>
