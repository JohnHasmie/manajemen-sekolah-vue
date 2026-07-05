<!--
  LessonPlanReviewHistoryModal.vue — RPP audit-trail timeline.

  Web port of `lesson_plan_review_history_screen.dart`. Shows every
  state change captured in `lesson_plan_reviews` (created → submitted
  → approved/rejected/sent_back → updated) in newest-first order.

  Each row:
    ┌─────────────────────────────────────────────────────────────┐
    │  ●  Disetujui                  Bu Sari · 2 jam lalu         │
    │  │  "Bagus, langsung bisa dipakai."                          │
    │  │  Pending → Approved                                       │
    └─────────────────────────────────────────────────────────────┘

  Dot color follows REVIEW_ACTION_TONES so the visual matches the
  status tones used everywhere else. Sent-back events surface the
  `revision_areas` chips so the reader sees exactly what was flagged.
-->
<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { LessonPlanService } from '@/services/lesson-plans.service';
import {
  REVIEW_ACTION_TONES,
  sectionLabel,
  STATUS_LABELS,
  type LessonPlanReview,
} from '@/types/lesson-plans';
import Modal from '@/components/ui/Modal.vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import { formatRelative } from '@/lib/format';

const props = defineProps<{
  planId: string;
  /** Shown in the subtitle so the reader knows which RPP this is for. */
  planTitle?: string;
}>();

const emit = defineEmits<{ close: [] }>();

const reviews = ref<LessonPlanReview[]>([]);
const isLoading = ref(true);
const error = ref<string | null>(null);

async function load() {
  isLoading.value = true;
  error.value = null;
  try {
    const rows = await LessonPlanService.getReviews(props.planId);
    // Newest first — service already returns in chronological order
    // most of the time, but defend against mixed ordering from older
    // backend versions.
    reviews.value = [...rows].sort((a, b) =>
      String(b.created_at ?? '').localeCompare(String(a.created_at ?? '')),
    );
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    isLoading.value = false;
  }
}

onMounted(load);

function fmtIso(iso: string): string {
  if (!iso) return '—';
  try {
    return new Date(iso).toLocaleString('id-ID', {
      day: '2-digit',
      month: 'short',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  } catch {
    return iso;
  }
}
</script>

<template>
  <Modal
    title="Riwayat Persetujuan"
    :subtitle="planTitle ? planTitle : 'Audit trail RPP'"
    @close="emit('close')"
  >
    <div class="space-y-2">
      <!-- Loading -->
      <div v-if="isLoading" class="py-8 text-center">
        <div class="inline-block w-6 h-6 rounded-full border-2 border-slate-200 border-t-brand-cobalt animate-spin" />
        <p class="text-2xs text-slate-500 mt-3">Memuat riwayat…</p>
      </div>

      <!-- Error -->
      <div
        v-else-if="error"
        class="bg-red-50 border border-red-200 rounded-lg px-3 py-3 text-[12px] text-red-700"
      >
        <p class="font-bold mb-1">Gagal memuat riwayat</p>
        <p>{{ error }}</p>
        <button
          type="button"
          class="mt-2 text-2xs font-bold text-red-700 underline"
          @click="load"
        >
          Coba lagi
        </button>
      </div>

      <!-- Empty -->
      <div
        v-else-if="reviews.length === 0"
        class="py-8 text-center"
      >
        <span class="inline-flex items-center justify-center w-12 h-12 rounded-2xl bg-slate-100 text-slate-400">
          <NavIcon name="list" :size="22" />
        </span>
        <p class="text-[13px] font-bold text-slate-700 mt-3">Belum ada riwayat</p>
        <p class="text-2xs text-slate-500 mt-1">
          Audit trail akan terisi setiap kali status RPP berubah.
        </p>
      </div>

      <!-- Timeline -->
      <div v-else class="relative pl-5">
        <!-- vertical guide line -->
        <span
          class="absolute left-[7px] top-2 bottom-2 w-px bg-slate-200"
          aria-hidden="true"
        />

        <article
          v-for="r in reviews"
          :key="r.id"
          class="relative pb-3 last:pb-0"
        >
          <!-- dot -->
          <span
            class="absolute -left-5 top-1.5 w-3 h-3 rounded-full ring-2 ring-white"
            :class="REVIEW_ACTION_TONES[r.action].dot"
          />

          <!-- header line -->
          <div class="flex items-baseline gap-2 flex-wrap">
            <span
              class="text-[12px] font-bold"
              :class="REVIEW_ACTION_TONES[r.action].text"
            >
              {{ r.label }}
            </span>
            <span class="text-[10.5px] text-slate-400">
              · {{ r.actor_name || 'Pengguna' }}
            </span>
            <span class="flex-1"></span>
            <span
              class="text-3xs text-slate-400 tabular-nums"
              :title="fmtIso(r.created_at)"
            >
              {{ formatRelative(r.created_at) }}
            </span>
          </div>

          <!-- status transition pill -->
          <p
            v-if="r.from_status || r.to_status"
            class="text-[10.5px] text-slate-500 mt-1 inline-flex items-center gap-1"
          >
            <span v-if="r.from_status" class="font-medium text-slate-600">
              {{ STATUS_LABELS[r.from_status] }}
            </span>
            <NavIcon
              v-if="r.from_status && r.to_status"
              name="arrow-right"
              :size="10"
              class="text-slate-300"
            />
            <span v-if="r.to_status" class="font-bold text-slate-700">
              {{ STATUS_LABELS[r.to_status] }}
            </span>
          </p>

          <!-- note -->
          <blockquote
            v-if="r.note"
            class="mt-1.5 text-[12px] text-slate-700 leading-relaxed border-l-2 pl-2.5 italic"
            :class="
              r.action === 'rejected'
                ? 'border-red-300'
                : r.action === 'sent_back'
                  ? 'border-violet-300'
                  : 'border-slate-200'
            "
          >
            {{ r.note }}
          </blockquote>

          <!-- revision areas chips (sent_back) -->
          <div
            v-if="r.revision_areas && r.revision_areas.length > 0"
            class="mt-1.5 flex flex-wrap gap-1"
          >
            <span class="text-3xs text-slate-500 font-semibold mr-1">
              Bagian:
            </span>
            <span
              v-for="key in r.revision_areas"
              :key="key"
              class="text-3xs font-bold px-1.5 py-0.5 rounded-full bg-violet-100 text-violet-700"
            >
              {{ sectionLabel(key) }}
            </span>
          </div>
        </article>
      </div>
    </div>
  </Modal>
</template>
