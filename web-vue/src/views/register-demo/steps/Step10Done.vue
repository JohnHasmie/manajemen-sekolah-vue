<!--
  Step 12 — Done (request received).

  The demo is now a REVIEWED request, so this terminal step no longer
  shows credentials or seeded-data stats. It confirms the PENDING
  request was received and that activation will follow after the
  KamilEdu team validates + identifies the requester, with info sent
  via WhatsApp/email. NO activation internals are revealed.
-->
<script setup lang="ts">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useDemoWizardStore } from '@/stores/demo-wizard';
import NavIcon from '@/components/feature/NavIcon.vue';
import Spinner from '@/components/ui/Spinner.vue';

const { t, locale } = useI18n();
const wizard = useDemoWizardStore();

const result = computed(() => wizard.result);
const requester = computed(() => wizard.payload.requester);
const schoolName = computed(() => wizard.payload.school.name);

/** Short, human-readable submitted-at — falls back gracefully. */
const submittedAt = computed(() => {
  const raw = result.value?.submitted_at;
  if (!raw) return '';
  const d = new Date(raw);
  if (Number.isNaN(d.getTime())) return '';
  return d.toLocaleString(locale.value === 'en' ? 'en-US' : 'id-ID', {
    dateStyle: 'medium',
    timeStyle: 'short',
  });
});
</script>

<template>
  <div>
    <div v-if="wizard.isProvisioning" class="py-12 text-center">
      <Spinner size="lg" />
      <p class="mt-4 text-[14px] font-bold text-slate-700">
        {{ t('registerDemo.pendingSubmitting') }}
      </p>
      <p class="mt-1 text-[12px] text-slate-500">
        {{ t('registerDemo.pendingSubmittingNote') }}
      </p>
    </div>

    <div v-else-if="!result" class="py-12 text-center text-[13px] text-slate-500">
      {{ t('registerDemo.pendingNoResultYet') }}
    </div>

    <div v-else>
      <div
        class="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-emerald-100"
      >
        <NavIcon name="check-circle" :size="32" class="text-emerald-600" />
      </div>
      <h2 class="mb-1 text-center text-[22px] font-black text-slate-900">
        {{ t('registerDemo.pendingTitle') }}
      </h2>
      <p class="mb-5 text-center text-[13px] leading-relaxed text-slate-600">
        {{ t('registerDemo.pendingSubtitle') }}
      </p>

      <!-- Request summary card -->
      <div class="rounded-xl border border-slate-200 bg-slate-50 p-4">
        <p class="mb-3 text-[10.5px] font-bold uppercase tracking-widest text-slate-500">
          {{ t('registerDemo.pendingSummaryLabel') }}
        </p>
        <dl class="space-y-2.5 text-[13px]">
          <div class="flex items-start gap-3">
            <dt class="w-28 flex-shrink-0 text-slate-500">
              {{ t('registerDemo.pendingFieldSchool') }}
            </dt>
            <dd class="flex-1 font-bold text-slate-900">{{ schoolName || '—' }}</dd>
          </div>
          <div class="flex items-start gap-3">
            <dt class="w-28 flex-shrink-0 text-slate-500">
              {{ t('registerDemo.pendingFieldRequester') }}
            </dt>
            <dd class="flex-1 font-bold text-slate-900">{{ requester.full_name || '—' }}</dd>
          </div>
          <div class="flex items-start gap-3">
            <dt class="w-28 flex-shrink-0 text-slate-500">
              {{ t('registerDemo.pendingFieldWhatsapp') }}
            </dt>
            <dd class="flex-1 font-mono text-[12.5px] text-slate-900">
              {{ requester.whatsapp || '—' }}
            </dd>
          </div>
          <div v-if="submittedAt" class="flex items-start gap-3">
            <dt class="w-28 flex-shrink-0 text-slate-500">
              {{ t('registerDemo.pendingFieldSubmittedAt') }}
            </dt>
            <dd class="flex-1 text-slate-900">{{ submittedAt }}</dd>
          </div>
          <div class="flex items-start gap-3">
            <dt class="w-28 flex-shrink-0 text-slate-500">
              {{ t('registerDemo.pendingFieldStatus') }}
            </dt>
            <dd class="flex-1">
              <span
                class="inline-flex items-center gap-1.5 rounded-full bg-amber-100 px-2.5 py-0.5 text-[11.5px] font-bold text-amber-800"
              >
                <NavIcon name="clock" :size="12" />
                {{ t('registerDemo.pendingStatusBadge') }}
              </span>
            </dd>
          </div>
        </dl>
      </div>

      <!-- What happens next — no activation internals. -->
      <div
        class="mt-4 flex items-start gap-2.5 rounded-lg border border-emerald-200 bg-emerald-50 px-3.5 py-3"
      >
        <NavIcon name="send" :size="16" class="mt-0.5 flex-shrink-0 text-emerald-600" />
        <p class="text-[12.5px] leading-relaxed text-emerald-900">
          {{ t('registerDemo.pendingNextSteps') }}
        </p>
      </div>

      <p class="mt-4 text-center text-[11.5px] leading-snug text-slate-500">
        {{ t('registerDemo.pendingFinalNote') }}
      </p>
    </div>
  </div>
</template>
