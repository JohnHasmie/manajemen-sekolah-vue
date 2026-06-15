<!--
  ParentRegisterLeadView — wali calon "daftar anak baru" form.
  Hero + Batal chip, "Data anak" inputs, program choice cards with
  bimbel border-2 + offset-pad active style, notes textarea, and
  Simpan draft / Kirim CTA row. Keeps TutoringService.createLead path.
-->
<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { TutoringService } from '@/services/tutoring.service';
import type { TutoringProgram } from '@/types/tutoring';

import ParentBerandaHero from '@/components/feature/tutoring/ParentBerandaHero.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const { t } = useI18n();
const router = useRouter();

interface LeadForm {
  childName: string;
  grade: string;
  school: string;
  programId: string;
  notes: string;
}

const form = ref<LeadForm>({
  childName: '',
  grade: '',
  school: '',
  programId: '',
  notes: '',
});
const programs = ref<TutoringProgram[]>([]);
const saving = ref(false);
const message = ref<{ kind: 'ok' | 'err'; text: string } | null>(null);

const grades = [
  'Kelas 1 SD', 'Kelas 2 SD', 'Kelas 3 SD', 'Kelas 4 SD', 'Kelas 5 SD', 'Kelas 6 SD',
  'Kelas 7 SMP', 'Kelas 8 SMP', 'Kelas 9 SMP',
  'Kelas 10 SMA', 'Kelas 11 SMA', 'Kelas 12 SMA',
];

onMounted(async () => {
  try { programs.value = await TutoringService.getPrograms(); }
  catch {/* non-fatal */}

  // Hydrate from local draft if present — non-fatal if absent.
  try {
    const raw = localStorage.getItem('parent.registerLead.draft');
    if (raw) {
      const parsed = JSON.parse(raw) as Partial<LeadForm>;
      form.value = { ...form.value, ...parsed };
    }
  } catch {/* ignore */}
});

const canSubmit = computed(() =>
  form.value.childName.trim().length >= 2 &&
  !!form.value.programId &&
  !saving.value,
);

function saveDraft() {
  try {
    localStorage.setItem('parent.registerLead.draft', JSON.stringify(form.value));
    message.value = { kind: 'ok', text: t('wali.bimbel.register_lead.draft_saved') };
  } catch {/* ignore */}
}

function cancel() {
  router.back();
}

async function submit() {
  if (!canSubmit.value) return;
  saving.value = true;
  message.value = null;
  try {
    await TutoringService.createLead({
      name: form.value.childName,
      program_id: form.value.programId,
      notes: [
        form.value.grade && `Kelas: ${form.value.grade}`,
        form.value.school && `Sekolah: ${form.value.school}`,
        form.value.notes && `Catatan: ${form.value.notes}`,
      ].filter(Boolean).join(' · '),
    });
    message.value = { kind: 'ok', text: t('wali.bimbel.register_lead.submit_success') };
    form.value = { childName: '', grade: '', school: '', programId: '', notes: '' };
    try { localStorage.removeItem('parent.registerLead.draft'); } catch {/* ignore */}
  } catch (e) {
    message.value = { kind: 'err', text: e instanceof Error ? e.message : t('wali.bimbel.register_lead.error_default') };
  } finally { saving.value = false; }
}
</script>

<template>
  <div class="space-y-3 pb-12">
    <ParentBerandaHero
      :kicker="t('wali.bimbel.register_lead.kicker')"
      :title="t('wali.bimbel.register_lead.title')"
      :subtitle="t('wali.bimbel.register_lead.subtitle')"
      :stats="[]"
    >
      <template #actions>
        <button
          type="button"
          class="hidden sm:inline-flex items-center gap-1.5 rounded-lg bg-white text-bimbel-hero px-3 py-1.5 text-[14px] font-bold hover:bg-white/95"
          @click="cancel"
        >
          <NavIcon name="x" :size="12" />
          {{ t('wali.bimbel.register_lead.cancel') }}
        </button>
      </template>
    </ParentBerandaHero>

    <p class="text-[12px] tracking-[0.1em] text-bimbel-text-lo font-bold uppercase mb-2 mt-3 first:mt-0">
      {{ t('wali.bimbel.register_lead.child_data_heading') }}
    </p>
    <label class="block text-[12px] text-bimbel-text-mid mb-1">{{ t('wali.bimbel.register_lead.child_name_label') }}</label>
    <input
      v-model="form.childName"
      type="text"
      class="rounded-md bg-bimbel-bg px-3 py-2.5 text-[14px] text-bimbel-text-hi block w-full focus:outline-none mb-2"
    />
    <div class="grid grid-cols-2 gap-2">
      <div>
        <label class="block text-[12px] text-bimbel-text-mid mb-1">{{ t('wali.bimbel.register_lead.class_label') }}</label>
        <select
          v-model="form.grade"
          class="rounded-md bg-bimbel-bg px-3 py-2.5 text-[14px] text-bimbel-text-hi block w-full focus:outline-none"
        >
          <option value="">{{ t('wali.bimbel.register_lead.class_placeholder') }}</option>
          <option v-for="g in grades" :key="g" :value="g">{{ g }}</option>
        </select>
      </div>
      <div>
        <label class="block text-[12px] text-bimbel-text-mid mb-1">{{ t('wali.bimbel.register_lead.school_label') }}</label>
        <input
          v-model="form.school"
          type="text"
          class="rounded-md bg-bimbel-bg px-3 py-2.5 text-[14px] text-bimbel-text-hi block w-full focus:outline-none"
        />
      </div>
    </div>

    <p class="text-[12px] tracking-[0.1em] text-bimbel-text-lo font-bold uppercase mb-2 mt-3">
      {{ t('wali.bimbel.register_lead.program_heading') }}
    </p>
    <div
      v-if="!programs.length"
      class="rounded-md bg-bimbel-panel border border-bimbel-border-soft p-6 text-center text-[13px] text-bimbel-text-mid"
    >
      {{ t('wali.bimbel.register_lead.loading_programs') }}
    </div>
    <button
      v-for="p in programs"
      :key="p.id"
      type="button"
      :class="[
        'w-full rounded-md bg-bimbel-panel border flex gap-2.5 items-center mb-1.5 text-left',
        form.programId === p.id ? 'border-2 border-bimbel-hero p-[11px]' : 'border-bimbel-border-soft p-3',
      ]"
      @click="form.programId = p.id"
    >
      <div class="w-10 h-10 rounded-lg bg-bimbel-accent-dim text-bimbel-hero grid place-items-center flex-shrink-0">
        <NavIcon name="school" :size="18" />
      </div>
      <div class="flex-1 min-w-0">
        <p class="text-[14px] font-bold text-bimbel-text-hi">{{ p.name }}</p>
        <p class="text-[12px] text-bimbel-text-mid">{{ p.description || '—' }}</p>
      </div>
      <span
        :class="[
          'w-4 h-4 rounded-full border-2 flex-shrink-0',
          form.programId === p.id ? 'border-bimbel-hero bg-bimbel-hero/20' : 'border-bimbel-border',
        ]"
      ></span>
    </button>

    <p class="text-[12px] tracking-[0.1em] text-bimbel-text-lo font-bold uppercase mb-2 mt-3">
      {{ t('wali.bimbel.register_lead.notes_heading') }}
    </p>
    <textarea
      v-model="form.notes"
      rows="3"
      :placeholder="t('wali.bimbel.register_lead.notes_placeholder')"
      class="rounded-md bg-bimbel-bg px-3 py-2.5 text-[14px] text-bimbel-text-hi w-full focus:outline-none placeholder:text-bimbel-text-lo min-h-12"
    ></textarea>

    <div
      v-if="message"
      class="rounded-md mt-3 px-3 py-2 text-[13px]"
      :class="message.kind === 'ok' ? 'bg-bimbel-green-dim text-green-700' : 'bg-bimbel-red-dim text-red-700'"
    >{{ message.text }}</div>

    <div class="flex gap-2 mt-3">
      <button
        type="button"
        class="rounded-lg bg-bimbel-bg text-bimbel-text-mid border border-bimbel-border-soft text-[14px] px-3.5 py-2.5"
        @click="saveDraft"
      >{{ t('wali.bimbel.register_lead.save_draft') }}</button>
      <button
        type="button"
        :disabled="!canSubmit"
        class="flex-1 rounded-lg bg-bimbel-hero text-white text-[14px] font-bold px-3.5 py-2.5 disabled:opacity-50"
        @click="submit"
      >{{ saving ? t('wali.bimbel.register_lead.submitting') : t('wali.bimbel.register_lead.submit') }}</button>
    </div>
  </div>
</template>
