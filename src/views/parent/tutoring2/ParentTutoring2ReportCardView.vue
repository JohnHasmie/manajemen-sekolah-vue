<!--
  ParentTutoring2ReportCardView.vue — Wali bimbel report card.

  Route: /parent/tutoring2/report-card/:studentId

  ── Why this screen no longer shows a report card ──

  It rendered a complete, official-looking rapor that was invented from
  end to end:

    Bimbel Cendekia / SBMPTN Saintek   a different institution and a
                                       programme the child is not in
    term "Jan–Jun 2026"                hardcoded
    Matematika 85 A · Fisika 78 B+ ·   three marks that do not exist
    Kimia 72 B
    StatusBadge "published"            asserting the rapor was official

  A parent could open this, read grades for their child, and act on
  them — a conversation with the tutor, a decision about the next term.
  The marks were not their child's, and the programme was not their
  child's programme.

  There is NO rapor endpoint. The header used to say so ("BE-6 has not
  shipped") while presenting the output as though it had, which is the
  combination that makes this worse than an empty screen: it looks
  finished.

  The route is kept so an existing link lands on an explanation rather
  than a 404. The entry point stays too — a parent looking for a rapor
  should find out where it actually is.

  ── What a real implementation needs ──

  A term-scoped aggregate the backend does not model yet: per-programme
  scores rolled up over a term, a predikat band, and a tutor note.
  `GET /tutoring-v2/students/{id}/progress` already returns the raw
  graded history and is what the Progress screen reads — it is the
  natural input, but a rapor is an attested document, not a chart, so
  it needs its own endpoint and its own publish state.

  Until that exists, marks reach parents through the Progress screen,
  which shows only what a tutor actually entered.
-->
<script setup lang="ts">
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import BrandPageHeader from '@/components/layout/BrandPageHeader.vue';
import Button from '@/components/ui/Button.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const studentId = String(route.params.studentId ?? '');

/** The real marks a tutor has entered, which do exist. */
function openProgress() {
  if (!studentId) return;
  router.push({ name: 'parent.tutoring2.progress', params: { studentId } });
}
</script>

<template>
  <div class="space-y-md pb-24">
    <BrandPageHeader
      role="parent"
      :kicker="t('tutoring2.parent.home.subtitle')"
      :title="t('tutoring2.parent.reportCard.title')"
    />

    <section class="rounded-3xl border border-amber-100 bg-amber-50/60 p-md">
      <h2 class="text-sm font-bold text-amber-900">
        {{ t('tutoring2.parent.reportCard.unavailableTitle') }}
      </h2>
      <p class="mt-1.5 text-2xs leading-relaxed text-amber-800">
        {{ t('tutoring2.parent.reportCard.unavailableBody') }}
      </p>

      <div class="mt-4">
        <Button v-if="studentId" variant="primary" size="sm" @click="openProgress">
          {{ t('tutoring2.parent.reportCard.seeProgress') }}
        </Button>
      </div>
    </section>
  </div>
</template>
