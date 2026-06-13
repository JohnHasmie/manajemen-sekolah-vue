<!--
  ConversationalWizard — one-question-at-a-time wizard shell.

  Replaces the old 10-step sidebar layout. The user only ever sees:
    1. a thin progress bar with a soft "X dari Y" line
    2. the current question card (single input)
    3. a footer with Back / Skip-or-Next.

  Question list is selected from the active `tenant_type` on the
  store payload. Submission still hands off to the existing identity
  service so the backend contract is unchanged for sekolah; bimbel
  adds an extra `tenant_type` + `bimbel` slice to the request body.
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useDemoWizardStore } from '@/stores/demo-wizard';
import { DemoService } from '@/services/demo.service';
import { useToast } from '@/composables/useToast';
import NavIcon from '@/components/feature/NavIcon.vue';
import ToastHost from '@/components/ui/ToastHost.vue';
import QuestionInput from './QuestionInput.vue';
import {
  detectBadPhone,
  detectGibberish,
} from '@/lib/gibberish';
import { questionsFor, type Question } from './questions';
import type { DemoWizardPayload } from '@/types/demo';

const router = useRouter();
const wizard = useDemoWizardStore();
const toast = useToast();

const tenant = computed<'sekolah' | 'bimbel'>(() => wizard.payload.tenant_type);
const list = computed<readonly Question[]>(() => questionsFor(tenant.value));
const total = computed(() => list.value.length);

/** 0-based index of the question currently on screen. */
const idx = ref(0);
const current = computed<Question | undefined>(() => list.value[idx.value]);

/**
 * Local working copy of the current answer. We mirror it from the
 * payload on question-change, write keystrokes here, and commit back
 * into the payload on advance / back / skip. Keeps every keystroke
 * out of the store (no re-render churn) but never loses an answer.
 */
const draft = ref<unknown>(undefined);
watch(
  current,
  (q) => {
    draft.value = q ? q.value(wizard.payload) : undefined;
  },
  { immediate: true },
);

const isValid = computed(() => {
  const q = current.value;
  if (!q) return false;
  if (!q.required) return true;
  // The question's own predicate reads from a hypothetical merged
  // payload — for `isValid` we need the draft to count, not the
  // currently-committed value, so we temporarily merge.
  const merged = q.setValue(wizard.payload, draft.value);
  if (!q.isValid(merged)) return false;
  // Extra guards from the gibberish detector: applied on top of the
  // question's own predicate so a "looks-fine length" but actually-
  // keyboard-mashed answer never advances. Skipped silently when the
  // question hasn't opted in.
  const raw = String(draft.value ?? '');
  if (q.gibberishCheck && !detectGibberish(raw).ok) return false;
  if (q.phoneCheck && !detectBadPhone(raw).ok) return false;
  return true;
});

/**
 * Progress reflects ACTIVE questions only — questions a `skipIf`
 * predicate has hidden don't count for or against. Computed against
 * the live payload so picking a registry hit on Q1 instantly shrinks
 * the visible total (and bumps the percent).
 */
const activeCount = computed(() => {
  let n = 0;
  for (const q of list.value) {
    if (!q.skipIf?.(wizard.payload)) n++;
  }
  return Math.max(n, 1);
});
const activePosition = computed(() => {
  let pos = 0;
  for (let i = 0; i <= idx.value && i < list.value.length; i++) {
    const q = list.value[i];
    if (!q.skipIf?.(wizard.payload)) pos++;
  }
  return Math.max(pos, 1);
});
const progressPercent = computed(() =>
  Math.round((activePosition.value / activeCount.value) * 100),
);

const subtleProgressLabel = computed(() => {
  if (progressPercent.value < 25) return 'Baru mulai';
  if (progressPercent.value < 60) return 'Berjalan baik';
  if (progressPercent.value < 90) return 'Sebentar lagi selesai';
  return 'Tinggal sedikit lagi';
});

const chapterLabel = computed(() => current.value?.chapter ?? '');

// ── navigation ──────────────────────────────────────────────────────

function commitDraft(): void {
  const q = current.value;
  if (!q) return;
  wizard.replacePayload(q.setValue(wizard.payload, draft.value));
}

/**
 * Whole-payload patch from inputs that overwrite multiple slices at
 * once (school-search hit prefills name + npsn + city + education
 * level together; bimbel location picker patches city alongside its
 * own update). The store is the source of truth; we then re-read
 * the current question's value back into the local draft so the
 * input reflects the merged state.
 *
 * CRITICAL: we MUST commit the current draft into the payload BEFORE
 * the patcher runs. Otherwise patchers that touch a sibling slice
 * (e.g. the location picker patching bimbel.city while bimbel.location
 * is still only in the local draft) cause the re-read at the bottom
 * to overwrite draft with whatever's in the store — which is still
 * the pre-pick null. The user sees the pin on the map but Lanjut
 * stays disabled because draft.value snaps back to null.
 */
function applyPatch(patcher: (p: DemoWizardPayload) => DemoWizardPayload): void {
  const q = current.value;
  const baseline = q && draft.value !== undefined
    ? q.setValue(wizard.payload, draft.value)
    : wizard.payload;
  const next = patcher(baseline);
  wizard.replacePayload(next);
  if (q) draft.value = q.value(next);
}

/**
 * Walk the question list from `start` in `dir` (+1 forward, -1 back)
 * and return the index of the first question whose `skipIf` is NOT
 * truthy. Returns null when every remaining question is skippable —
 * forward → fire submit, back → bounce to landing.
 */
function findActiveIdx(start: number, dir: 1 | -1): number | null {
  let i = start;
  while (i >= 0 && i < total.value) {
    const q = list.value[i];
    if (!q?.skipIf?.(wizard.payload)) return i;
    i += dir;
  }
  return null;
}

function next(): void {
  const q = current.value;
  if (!q) return;
  // Required questions block advance until valid.
  if (q.required && !isValid.value) {
    toast.error('Lengkapi dulu jawaban di atas.');
    return;
  }
  commitDraft();
  const target = findActiveIdx(idx.value + 1, 1);
  if (target == null) submit();
  else idx.value = target;
}

function back(): void {
  commitDraft();
  const target = findActiveIdx(idx.value - 1, -1);
  if (target == null) router.push('/register-demo');
  else idx.value = target;
}

function skip(): void {
  if (current.value?.required) return;
  // Skipping commits whatever default is in the payload (defaults
  // are sensible). We do NOT clear the field so a user who skips a
  // billing question still has a coherent submission.
  const target = findActiveIdx(idx.value + 1, 1);
  if (target == null) submit();
  else idx.value = target;
}

// ── submit ───────────────────────────────────────────────────────────

const submitting = ref(false);
/**
 * Persistent error message rendered above the footer when submit fails.
 * Toast disappears after a few seconds; this stays until the user
 * dismisses it or successfully retries. Critical for throttle/network
 * errors where the user needs time to read "wait 1 minute" copy.
 */
const submitError = ref<string | null>(null);

async function submit(): Promise<void> {
  submitting.value = true;
  submitError.value = null;
  try {
    wizard.prepareIdentityHandoff();
    router.push('/register-demo/identity');
  } catch (e) {
    const msg = e instanceof Error ? e.message : 'Terjadi kesalahan.';
    submitError.value = msg;
    toast.error(msg);
  } finally {
    submitting.value = false;
  }
}

function dismissSubmitError(): void {
  submitError.value = null;
}

// ── debounced remote save on each answer commit ─────────────────────
let saveTimer: ReturnType<typeof setTimeout> | null = null;
watch(
  () => idx.value,
  () => {
    if (saveTimer) clearTimeout(saveTimer);
    saveTimer = setTimeout(() => {
      DemoService.saveWizardState({
        payload: wizard.payload,
        current_step: idx.value,
      }).catch(() => undefined);
    }, 600);
  },
);

// ── keyboard shortcut: Enter advances when input isn't focused ──────
function onGlobalEnter(e: KeyboardEvent): void {
  if (e.key !== 'Enter') return;
  const target = e.target as HTMLElement | null;
  // Let inputs handle their own Enter (they emit @submit to us).
  if (target && ['INPUT', 'TEXTAREA', 'SELECT', 'BUTTON'].includes(target.tagName)) {
    return;
  }
  next();
}

onMounted(async () => {
  await wizard.hydrate();
  document.addEventListener('keydown', onGlobalEnter);
});

watch(
  () => current.value?.key,
  () => {
    // No-op — placeholder for analytics ('question_view').
  },
);
</script>

<template>
  <div class="min-h-screen flex flex-col bg-slate-50">
    <!-- Topbar -->
    <header class="bg-white border-b border-slate-200">
      <div class="max-w-3xl mx-auto px-6 h-14 flex items-center justify-between">
        <div class="flex items-center gap-2.5">
          <div class="w-7 h-7 rounded-lg bg-brand-dark-blue text-white text-xs font-black grid place-items-center">
            K
          </div>
          <div class="text-sm font-bold text-slate-900">
            Daftar demo
            <span class="ml-1 text-xs font-medium text-slate-500">
              · {{ tenant === 'bimbel' ? 'Bimbel' : 'Sekolah' }}
            </span>
          </div>
        </div>
        <button
          type="button"
          class="text-xs font-semibold text-slate-500 hover:text-brand-cobalt"
          @click="router.push('/register-demo')"
        >
          Pilih ulang jenis lembaga
        </button>
      </div>
      <!-- Progress -->
      <div class="max-w-3xl mx-auto px-6 pb-3 pt-1">
        <div class="flex items-center justify-between text-[11px] tracking-wider text-slate-400 mb-1.5">
          <span>{{ subtleProgressLabel }}</span>
          <span class="font-semibold">{{ progressPercent }}%</span>
        </div>
        <div class="h-[3px] rounded-full bg-slate-100 overflow-hidden">
          <div
            class="h-full bg-brand-cobalt rounded-full transition-all duration-500 ease-out"
            :style="{ width: progressPercent + '%' }"
          ></div>
        </div>
      </div>
    </header>

    <!-- Body -->
    <main class="flex-1 flex items-center justify-center px-6 py-8">
      <Transition
        enter-active-class="transition duration-300 ease-out"
        enter-from-class="opacity-0 translate-y-2"
        enter-to-class="opacity-100 translate-y-0"
        leave-active-class="transition duration-200"
        leave-from-class="opacity-100"
        leave-to-class="opacity-0 -translate-y-2"
        mode="out-in"
      >
        <section
          v-if="current"
          :key="current.key"
          class="w-full max-w-2xl bg-white rounded-3xl border border-slate-200 shadow-sm p-8 sm:p-10 text-center"
        >
          <!-- chapter intro (e.g. identity → "Data faktual untuk verifikasi") -->
          <div
            v-if="current.chapterIntro"
            class="mb-6 rounded-2xl border border-amber-200 bg-amber-50/70 px-5 py-4 text-left"
          >
            <div class="flex items-start gap-3">
              <span class="w-7 h-7 rounded-lg bg-amber-100 text-amber-700 grid place-items-center flex-shrink-0">
                <NavIcon name="info" :size="14" />
              </span>
              <div class="min-w-0">
                <p class="text-[12px] font-bold text-amber-900">
                  {{ current.chapterIntro.title }}
                </p>
                <p class="text-[11.5px] text-amber-800/90 leading-relaxed mt-0.5">
                  {{ current.chapterIntro.body }}
                </p>
              </div>
            </div>
          </div>
          <p class="text-[10px] font-black tracking-[0.3em] uppercase text-brand-cobalt mb-3">
            {{ chapterLabel }}
          </p>
          <h1 class="text-2xl sm:text-[26px] font-bold text-slate-900 tracking-tight leading-tight mb-2">
            {{ current.prompt }}
          </h1>
          <p v-if="current.helper" class="text-sm text-slate-500 mb-7 max-w-md mx-auto leading-relaxed">
            {{ current.helper }}
          </p>

          <QuestionInput
            :question="current"
            :model-value="draft"
            @update="draft = $event"
            @submit="next"
            @patch-payload="applyPatch"
          />

          <div class="mt-7">
            <button
              v-if="!current.required"
              type="button"
              class="text-xs font-semibold text-slate-400 hover:text-brand-cobalt inline-flex items-center gap-1"
              @click="skip"
            >
              <NavIcon name="arrow-right" :size="12" />
              Lewati pertanyaan ini
            </button>
          </div>
        </section>
      </Transition>
    </main>

    <!-- Submit error banner — persistent until dismissed or retried. -->
    <Transition
      enter-active-class="transition duration-200"
      enter-from-class="opacity-0 -translate-y-1"
      leave-active-class="transition duration-150"
      leave-to-class="opacity-0 -translate-y-1"
    >
      <div
        v-if="submitError"
        class="bg-rose-50 border-t border-rose-200 text-rose-800"
      >
        <div class="max-w-3xl mx-auto px-6 py-3 flex items-start gap-3">
          <NavIcon
            name="alert-circle"
            :size="16"
            class="mt-0.5 flex-shrink-0 text-rose-600"
          />
          <div class="flex-1 min-w-0">
            <p class="text-[13px] font-bold leading-tight">
              Gagal mengirim permintaan demo
            </p>
            <p class="text-[12px] text-rose-700/90 leading-snug mt-0.5">
              {{ submitError }}
            </p>
          </div>
          <button
            type="button"
            class="text-[11px] font-semibold text-rose-700 hover:text-rose-900 flex-shrink-0"
            @click="dismissSubmitError"
          >
            Tutup
          </button>
        </div>
      </div>
    </Transition>

    <!-- Footer -->
    <footer class="bg-white border-t border-slate-200">
      <div class="max-w-3xl mx-auto px-6 py-3.5 flex items-center justify-between">
        <button
          type="button"
          class="inline-flex items-center gap-1.5 text-sm font-semibold text-slate-500 hover:text-slate-900"
          @click="back"
        >
          <NavIcon name="arrow-left" :size="14" />
          Kembali
        </button>
        <p class="hidden sm:block text-[11px] text-slate-400">
          Tekan Enter untuk lanjut
        </p>
        <button
          type="button"
          class="inline-flex items-center gap-1.5 bg-brand-dark-blue text-white text-sm font-bold px-5 py-2.5 rounded-xl hover:bg-brand-cobalt transition disabled:opacity-50"
          :disabled="submitting || (current?.required && !isValid)"
          @click="next"
        >
          <span v-if="idx === total - 1">
            {{ submitting ? 'Mengirim…' : 'Kirim permintaan demo' }}
          </span>
          <span v-else>Lanjut</span>
          <NavIcon :name="idx === total - 1 ? 'check' : 'arrow-right'" :size="14" />
        </button>
      </div>
    </footer>

    <ToastHost />
  </div>
</template>
