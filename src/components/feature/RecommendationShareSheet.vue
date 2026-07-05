<!--
  RecommendationShareSheet.vue — Bagikan ke Parent (Frame H).

  Web port of `recommendation_share_sheet.dart`. Cobalt-themed modal
  that lets the homeroom teacher fan a rec out to one or more parents.

  Body (top-down):
    1. Penerima — recipient picker, tap to toggle (default: all
       available parents pre-selected)
    2. Nada Pesan — 4 tone chips with emoji (Hangat / Formal / Singkat / Detail)
    3. Catatan Tambahan — optional textarea
    4. Pratinjau Pesan — live-preview card with the actual message
       parents will receive
    5. Kanal Pengiriman — Push (always-on) + WhatsApp (opt-in)

  Recipient picker source-of-truth: `rec.student_parents` denorm from
  the hydrated detail call. When empty (Mengajar scope without the
  homeroom eager-load), the caller passes `fallbackParents` derived
  from `student.mother_name` / `father_name`.

  Emits `shared(updated: LearningRecommendation)` so the parent can
  patch the local rec state without a refetch.
-->
<script setup lang="ts">
import { computed, ref, watch } from 'vue';
import {
  RecommendationService,
  RateLimitError,
} from '@/services/recommendations.service';
import {
  TONE_LABELS,
  type LearningRecommendation,
  type RecTone,
} from '@/types/recommendations';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

interface ParentOption {
  parent_user_id?: string | null;
  parent_name: string;
  parent_relation?: string | null;
  parent_phone?: string | null;
}

const props = withDefaults(
  defineProps<{
    rec: LearningRecommendation;
    teacherId: string;
    /**
     * Optional explicit recipient list. When omitted, falls back to
     * `rec.student_parents` denorm — parent always provides one or
     * the other (an empty roster shows a "tidak ada parent" hint).
     */
    availableParents?: ParentOption[];
    busy?: boolean;
  }>(),
  { availableParents: () => [], busy: false },
);

const emit = defineEmits<{
  close: [];
  shared: [updated: LearningRecommendation];
}>();

// ── Recipient pool ──
// Prefer the explicit prop; else fall through to rec.student_parents.
const parentPool = computed<ParentOption[]>(() => {
  if (props.availableParents.length > 0) return props.availableParents;
  return props.rec.student_parents ?? [];
});

const selectedKeys = ref<Set<string>>(new Set());

// Key uniqueness: parent_user_id when present, fall through to name.
function parentKey(p: ParentOption): string {
  return p.parent_user_id ? `id:${p.parent_user_id}` : `n:${p.parent_name}`;
}

// Default: select every available parent on first mount.
watch(
  parentPool,
  (list) => {
    selectedKeys.value = new Set(list.map(parentKey));
  },
  { immediate: true },
);

function toggleParent(p: ParentOption) {
  const next = new Set(selectedKeys.value);
  const k = parentKey(p);
  if (next.has(k)) next.delete(k);
  else next.add(k);
  selectedKeys.value = next;
}

const selectedParents = computed<ParentOption[]>(() =>
  parentPool.value.filter((p) => selectedKeys.value.has(parentKey(p))),
);

// ── Tone chips ──
const tone = ref<RecTone>('warm');
const TONE_OPTIONS: { key: RecTone; emoji: string; label: string }[] = [
  { key: 'warm', emoji: '😊', label: TONE_LABELS.warm },
  { key: 'formal', emoji: '📋', label: TONE_LABELS.formal },
  { key: 'concise', emoji: '⚡', label: TONE_LABELS.concise },
  { key: 'detailed', emoji: '🎯', label: TONE_LABELS.detailed },
];

// ── Note + channels ──
const note = ref<string>('');
const channelPush = ref<boolean>(true);
const channelWhatsapp = ref<boolean>(false);

// ── Live preview ──
//
// Mirrors Flutter copy: a tone-flavoured intro + the rec title +
// optional teacher note. Backend re-renders authoritatively per
// channel — this is teacher-facing reassurance only.
const studentName = computed(() => props.rec.student_name ?? 'siswa');
const intro = computed(() => {
  switch (tone.value) {
    case 'formal':
      return `Yth. Bapak/Ibu wali dari ${studentName.value}, mohon perkenankan kami menyampaikan rekomendasi berikut:`;
    case 'concise':
      return `Pak/Bu, rekomendasi untuk ${studentName.value}:`;
    case 'detailed':
      return `Selamat siang Bapak/Ibu. Berikut rekomendasi terbaru dari AI untuk membantu pembelajaran ${studentName.value}:`;
    case 'warm':
    default:
      return `Halo Bapak/Ibu! Ada rekomendasi baru untuk ${studentName.value} 👋`;
  }
});

const previewBody = computed(() => {
  const lines = [intro.value, '', `📌 ${props.rec.title}`];
  if (props.rec.description) {
    // Strip HTML tags for the plain-text preview.
    const plain = props.rec.description
      .replace(/<[^>]+>/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
    if (plain) lines.push('', plain);
  }
  const trimmedNote = note.value.trim();
  if (trimmedNote) {
    lines.push('', `Catatan dari guru:`, trimmedNote);
  }
  lines.push('', 'Mari kita bantu bersama. Terima kasih 🙏');
  return lines.join('\n');
});

// ── Submit ──
const error = ref<string | null>(null);
const isSubmitting = ref(false);

const canSubmit = computed(
  () =>
    !isSubmitting.value &&
    !props.busy &&
    selectedParents.value.length > 0 &&
    (channelPush.value || channelWhatsapp.value),
);

async function submit() {
  error.value = null;
  if (selectedParents.value.length === 0) {
    error.value = 'Pilih minimal satu penerima.';
    return;
  }
  if (!channelPush.value && !channelWhatsapp.value) {
    error.value = 'Pilih minimal satu kanal pengiriman.';
    return;
  }
  isSubmitting.value = true;
  try {
    const updated = await RecommendationService.shareRecommendation({
      rec_id: props.rec.id,
      teacher_id: props.teacherId,
      parents: selectedParents.value.map((p) => ({
        parent_user_id: p.parent_user_id ?? null,
        parent_name: p.parent_name,
        parent_phone: p.parent_phone ?? null,
        parent_relation: p.parent_relation ?? undefined,
      })),
      message: note.value.trim() || undefined,
      tone: tone.value,
      channel_push: channelPush.value,
      channel_whatsapp: channelWhatsapp.value,
    });
    if (updated) emit('shared', updated);
    emit('close');
  } catch (e) {
    if (e instanceof RateLimitError) {
      error.value =
        e.dailyLimit && e.dailyUsage !== undefined
          ? `Batas harian AI tercapai (${e.dailyUsage}/${e.dailyLimit}).`
          : 'Batas harian AI tercapai. Coba lagi besok.';
    } else {
      error.value = (e as Error).message;
    }
  } finally {
    isSubmitting.value = false;
  }
}
</script>

<template>
  <Modal
    title="Bagikan ke Wali"
    :subtitle="`${rec.title} · ${studentName}`"
    size="lg"
    @close="emit('close')"
  >
    <div class="space-y-4">
      <!-- 1. PENERIMA -->
      <div>
        <div class="flex items-center gap-2 mb-1.5">
          <label class="block text-3xs font-bold text-slate-500 uppercase tracking-widest">
            Penerima
          </label>
          <span class="text-3xs text-slate-400 tabular-nums">
            · {{ selectedParents.length }}/{{ parentPool.length }} dipilih
          </span>
        </div>
        <div
          v-if="parentPool.length === 0"
          class="bg-amber-50 border border-amber-200 rounded-lg px-3 py-3 text-[12px] text-amber-800"
        >
          Belum ada wali terdaftar untuk siswa ini. Tambahkan kontak wali di profil siswa dulu.
        </div>
        <div v-else class="space-y-1.5">
          <button
            v-for="p in parentPool"
            :key="parentKey(p)"
            type="button"
            class="w-full text-left rounded-xl border px-3 py-2.5 flex items-center gap-3 transition"
            :class="
              selectedKeys.has(parentKey(p))
                ? 'bg-brand-cobalt/5 border-brand-cobalt ring-2 ring-brand-cobalt/15'
                : 'bg-white border-slate-200 hover:border-brand-cobalt/40'
            "
            :disabled="busy || isSubmitting"
            @click="toggleParent(p)"
          >
            <span
              class="w-5 h-5 rounded-md border-2 grid place-items-center flex-shrink-0"
              :class="
                selectedKeys.has(parentKey(p))
                  ? 'bg-brand-cobalt border-brand-cobalt text-white'
                  : 'bg-white border-slate-300'
              "
            >
              <NavIcon
                v-if="selectedKeys.has(parentKey(p))"
                name="check"
                :size="11"
              />
            </span>
            <div class="flex-1 min-w-0">
              <p class="text-[12.5px] font-bold text-slate-900 truncate">
                {{ p.parent_name }}
              </p>
              <p class="text-[10.5px] text-slate-500 mt-0.5">
                <template v-if="p.parent_relation">
                  {{ p.parent_relation }}
                </template>
                <template v-else>Wali</template>
                <template v-if="p.parent_phone">
                  · {{ p.parent_phone }}
                </template>
                <template v-if="!p.parent_user_id">
                  · Belum punya akun
                </template>
              </p>
            </div>
          </button>
        </div>
      </div>

      <!-- 2. NADA PESAN -->
      <div>
        <label class="block text-3xs font-bold text-slate-500 uppercase tracking-widest mb-1.5">
          Nada Pesan
        </label>
        <div class="grid grid-cols-2 sm:grid-cols-4 gap-1.5">
          <button
            v-for="opt in TONE_OPTIONS"
            :key="opt.key"
            type="button"
            class="px-3 py-2 rounded-xl border transition inline-flex items-center justify-center gap-1.5 text-[11.5px] font-bold"
            :class="
              tone === opt.key
                ? 'bg-brand-cobalt text-white border-brand-cobalt shadow-sm'
                : 'bg-white text-slate-600 border-slate-200 hover:border-brand-cobalt/40'
            "
            :disabled="busy || isSubmitting"
            @click="tone = opt.key"
          >
            <span>{{ opt.emoji }}</span>
            {{ opt.label }}
          </button>
        </div>
      </div>

      <!-- 3. CATATAN -->
      <div>
        <label class="block text-3xs font-bold text-slate-500 uppercase tracking-widest mb-1.5">
          Catatan Tambahan <span class="text-slate-400 normal-case font-normal">· opsional</span>
        </label>
        <textarea
          v-model="note"
          rows="3"
          placeholder="Misal: Tolong dampingi belajar SPLDV di rumah ya, Bu."
          class="w-full rounded-xl border border-slate-200 px-3 py-2 text-[12.5px] focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/15 focus:outline-none bg-white resize-y"
          :disabled="busy || isSubmitting"
        />
      </div>

      <!-- 4. PRATINJAU -->
      <div>
        <label class="block text-3xs font-bold text-slate-500 uppercase tracking-widest mb-1.5">
          Pratinjau Pesan
        </label>
        <div class="bg-slate-50 border border-slate-200 rounded-xl px-3 py-3 text-[12.5px] text-slate-700 whitespace-pre-wrap leading-relaxed font-medium">
          {{ previewBody }}
        </div>
      </div>

      <!-- 5. KANAL -->
      <div>
        <label class="block text-3xs font-bold text-slate-500 uppercase tracking-widest mb-1.5">
          Kanal Pengiriman
        </label>
        <div class="grid grid-cols-2 gap-2">
          <label
            class="rounded-xl border px-3 py-2.5 flex items-center gap-2.5 cursor-pointer transition"
            :class="
              channelPush
                ? 'bg-brand-cobalt/5 border-brand-cobalt'
                : 'bg-white border-slate-200 hover:border-brand-cobalt/40'
            "
          >
            <input
              v-model="channelPush"
              type="checkbox"
              class="w-4 h-4 accent-brand-cobalt flex-shrink-0"
              :disabled="busy || isSubmitting"
            />
            <span class="text-[14px]">📱</span>
            <div class="flex-1 min-w-0">
              <p class="text-[12px] font-bold text-slate-900 leading-tight">Push App</p>
              <p class="text-3xs text-slate-500 mt-0.5">Aplikasi wali</p>
            </div>
          </label>
          <label
            class="rounded-xl border px-3 py-2.5 flex items-center gap-2.5 cursor-pointer transition"
            :class="
              channelWhatsapp
                ? 'bg-emerald-50 border-emerald-500'
                : 'bg-white border-slate-200 hover:border-emerald-300'
            "
          >
            <input
              v-model="channelWhatsapp"
              type="checkbox"
              class="w-4 h-4 accent-emerald-600 flex-shrink-0"
              :disabled="busy || isSubmitting"
            />
            <span class="text-[14px]">💬</span>
            <div class="flex-1 min-w-0">
              <p class="text-[12px] font-bold text-slate-900 leading-tight">WhatsApp</p>
              <p class="text-3xs text-slate-500 mt-0.5">Pesan langsung</p>
            </div>
          </label>
        </div>
      </div>

      <!-- ERROR -->
      <div
        v-if="error"
        class="bg-red-50 border border-red-200 rounded-lg px-3 py-2 text-[12px] text-red-700"
      >
        {{ error }}
      </div>

      <!-- FOOTER -->
      <div class="grid grid-cols-2 gap-2 pt-2 border-t border-slate-100">
        <Button
          variant="secondary"
          block
          :disabled="isSubmitting"
          @click="emit('close')"
        >
          Batal
        </Button>
        <Button
          variant="primary"
          block
          :loading="isSubmitting"
          :disabled="!canSubmit"
          @click="submit"
        >
          <NavIcon name="send" :size="14" />
          Kirim ke {{ selectedParents.length }} Wali
        </Button>
      </div>
    </div>
  </Modal>
</template>
