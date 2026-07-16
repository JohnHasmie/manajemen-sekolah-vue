<!--
  ParentRegisterLeadView — parent calon "list anak baru" form.
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

import ParentHomeHero from '@/components/feature/tutoring/ParentHomeHero.vue';
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
    <ParentHomeHero
      :kicker="t('wali.bimbel.register_lead.kicker')"
      :title="t('wali.bimbel.register_lead.title')"
      :subtitle="t('wali.bimbel.register_lead.subtitle')"
      :stats="[]"
    >
      <template #actions>
        <button
          type="button"
          class="hidden sm:inline-flex items-center gap-1.5 rounded-lg bg-white text-tutoring-hero px-3 py-1.5 text-[14px] font-bold hover:bg-white/95"
          @click="cancel"
        >
          <NavIcon name="x" :size="12" />
          {{ t('wali.bimbel.register_lead.cancel') }}
        </button>
      </template>
    </ParentHomeHero>

    <p class="text-[12px] tracking-[0.1em] text-tutoring-text-lo font-bold uppercase mb-2 mt-3 first:mt-0">
      {{ t('wali.bimbel.register_lead.child_data_heading') }}
    </p>
    <label class="block text-[12px] text-tutoring-text-mid mb-1">{{ t('wali.bimbel.register_lead.child_name_label') }}</label>
    <input
      v-model="form.childName"
      type="text"
      class="rounded-md bg-tutoring-bg px-3 py-2.5 text-[14px] text-tutoring-text-hi block w-full focus:outline-none mb-2"
    />
    <div class="grid grid-cols-2 gap-2">
      <div>
        <label class="block text-[12px] text-tutoring-text-mid mb-1">{{ t('wali.bimbel.register_lead.class_label') }}</label>
        <select
          v-model="form.grade"
          class="rounded-md bg-tutoring-bg px-3 py-2.5 text-[14px] text-tutoring-text-hi block w-full focus:outline-none"
        >
          <option value="">{{ t('wali.bimbel.register_lead.class_placeholder') }}</option>
          <option v-for="g in grades" :key="g" :value="g">{{ g }}</option>
        </select>
      </div>
      <div>
        <label class="block text-[12px] text-tutoring-text-mid mb-1">{{ t('wali.bimbel.register_lead.school_label') }}</label>
        <input
          v-model="form.school"
          type="text"
          class="rounded-md bg-tutoring-bg px-3 py-2.5 text-[14px] text-tutoring-text-hi block w-full focus:outline-none"
        />
      </div>
    </div>

    <p class="text-[12px] tracking-[0.1em] text-tutoring-text-lo font-bold uppercase mb-2 mt-3">
      {{ t('wali.bimbel.register_lead.program_heading') }}
    </p>
    <div v-if="!programs.length" class="space-y-2" aria-hidden="true">
      <div v-for="i in 3" :key="i" class="flex items-center gap-3 rounded-md bg-tutoring-panel border border-tutoring-border-soft p-3">
        <div class="h-8 w-8 rounded-lg bg-tutoring-bg animate-pulse motion-reduce:animate-none" />
        <div class="flex-1 space-y-2">
          <div class="h-3 w-2/5 rounded bg-tutoring-bg animate-pulse motion-reduce:animate-none" />
          <div class="h-2 w-3/5 rounded bg-tutoring-bg animate-pulse motion-reduce:animate-none" />
        </div>
      </div>
    </div>
    <button
      v-for="p in programs"
      :key="p.id"
      type="button"
      :class="[
        'w-full rounded-md bg-tutoring-panel border flex gap-2.5 items-center mb-1.5 text-left',
        form.programId === p.id ? 'border-2 border-tutoring-hero p-[11px]' : 'border-tutoring-border-soft p-3',
      ]"
      @click="form.programId = p.id"
    >
      <div class="w-10 h-10 rounded-lg bg-tutoring-accent-dim text-tutoring-hero grid place-items-center flex-shrink-0">
        <NavIcon name="school" :size="18" />
      </div>
      <div class="flex-1 min-w-0">
        <p class="text-[14px] font-bold text-tutoring-text-hi">{{ p.name }}</p>
        <p class="text-[12px] text-tutoring-text-mid">{{ p.description || '—' }}</p>
      </div>
      <span
        :class="[
          'w-4 h-4 rounded-full border-2 flex-shrink-0',
          form.programId === p.id ? 'border-tutoring-hero bg-tutoring-hero/20' : 'border-tutoring-border',
        ]"
      ></span>
    </button>

    <p class="text-[12px] tracking-[0.1em] text-tutoring-text-lo font-bold uppercase mb-2 mt-3">
      {{ t('wali.bimbel.register_lead.notes_heading') }}
    </p>
    <textarea
      v-model="form.notes"
      rows="3"
      :placeholder="t('wali.bimbel.register_lead.notes_placeholder')"
      class="rounded-md bg-tutoring-bg px-3 py-2.5 text-[14px] text-tutoring-text-hi w-full focus:outline-none placeholder:text-tutoring-text-lo min-h-12"
    ></textarea>

    <div
      v-if="message"
      class="rounded-md mt-3 px-3 py-2 text-[13px]"
      :class="message.kind === 'ok' ? 'bg-tutoring-green-dim text-green-700' : 'bg-tutoring-red-dim text-red-700'"
    >{{ message.text }}</div>

    <div class="flex gap-2 mt-3">
      <button
        type="button"
        class="rounded-lg bg-tutoring-bg text-tutoring-text-mid border border-tutoring-border-soft text-[14px] px-3.5 py-2.5"
        @click="saveDraft"
      >{{ t('wali.bimbel.register_lead.save_draft') }}</button>
      <button
        type="button"
        :disabled="!canSubmit"
        class="flex-1 rounded-lg bg-tutoring-hero text-white text-[14px] font-bold px-3.5 py-2.5 disabled:opacity-50"
        @click="submit"
      >{{ saving ? t('wali.bimbel.register_lead.submitting') : t('wali.bimbel.register_lead.submit') }}</button>
    </div>
  </div>
</template>
