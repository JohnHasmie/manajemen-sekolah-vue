<!--
  QuestionInput — renders the right input for the current question.
  All variants emit a single `update` event with the new value; the
  shell handles binding back into the wizard payload.
-->
<script setup lang="ts">
import { computed, nextTick, onMounted, ref, watch } from 'vue';
import NavIcon from '@/components/feature/NavIcon.vue';
import TutoringLocationPicker, {
  type PickedLocation,
} from '@/components/tutoring/TutoringLocationPicker.vue';
import {
  TUTORING_SCENARIO_DEFINITIONS,
  DEMO_SOCIAL_CHANNELS,
  type TutoringScenarioKey,
  type DemoTutoringLocation,
  type DemoSocialChannel,
  type SchoolSearchHit,
} from '@/types/demo';
import { DemoService } from '@/services/demo.service';
import {
  detectBadPhone,
  detectGibberish,
  gibberishMessage,
  phoneMessage,
} from '@/lib/gibberish';
import { useDemoWizardStore } from '@/stores/demo-wizard';
import { educationLevelDisplay, normalizeEducationLevel } from '@/lib/labels';
import type { Question } from './questions';

const props = defineProps<{
  question: Question;
  modelValue: unknown;
}>();

const emit = defineEmits<{
  (e: 'update', v: unknown): void;
  /** Fired on Enter for inputs that should commit-and-advance. */
  (e: 'submit'): void;
  /**
   * Some inputs (school-search) commit the FULL payload immediately
   * because they overwrite multiple slices at once (name + npsn + city
   * + education_level). The shell takes the merged payload verbatim.
   */
  (e: 'patchPayload', patcher: (p: any) => any): void;
}>();

const wizard = useDemoWizardStore();

// ── focus management ────────────────────────────────────────────────
const textRef = ref<HTMLInputElement | null>(null);

onMounted(() => focusFirstInput());
watch(
  () => props.question.key,
  () => nextTick(focusFirstInput),
);

function focusFirstInput() {
  if (textRef.value) textRef.value.focus();
}

// ── text / tel / number ────────────────────────────────────────────
const textValue = computed({
  get: () => String(props.modelValue ?? ''),
  set: (v) => emit('update', v),
});

function onEnter(e: Event) {
  e.preventDefault();
  emit('submit');
}

// ── gibberish + phone warnings ─────────────────────────────────────
const gibberishWarning = computed<string | null>(() => {
  if (!props.question.gibberishCheck) return null;
  const v = String(props.modelValue ?? '').trim();
  if (v.length === 0) return null;
  return gibberishMessage(detectGibberish(v));
});

const phoneWarning = computed<string | null>(() => {
  if (!props.question.phoneCheck) return null;
  const v = String(props.modelValue ?? '').trim();
  if (v.length === 0) return null;
  return phoneMessage(detectBadPhone(v));
});

const inputWarning = computed<string | null>(
  () => gibberishWarning.value ?? phoneWarning.value,
);

// ── school search (sekolah path Q1 only) ──────────────────────────
const searchHits = ref<SchoolSearchHit[]>([]);
const isSearching = ref(false);
/** True once we've completed at least one search for the current input. */
const hasSearched = ref(false);
const SEARCH_MIN = 3;
let searchTimer: ReturnType<typeof setTimeout> | null = null;

watch(
  () => props.modelValue,
  (next) => {
    if (!props.question.schoolSearch) return;
    if (searchTimer) clearTimeout(searchTimer);
    const q = String(next ?? '').trim();
    // Reset state on every change so the UI doesn't show a stale
    // "0 results" while the user is still typing.
    hasSearched.value = false;
    if (q.length < SEARCH_MIN || gibberishWarning.value !== null) {
      searchHits.value = [];
      return;
    }
    isSearching.value = true;
    searchTimer = setTimeout(async () => {
      try {
        // Don't filter by education_level on the very first question —
        // the user hasn't picked a jenjang yet (the default 'SMP' in
        // the payload is just bootstrap state, not a chosen value).
        // Filtering early hides matching schools of other jenjang.
        searchHits.value = await DemoService.searchSchools({
          q,
          limit: 6,
        });
      } catch {
        searchHits.value = [];
      } finally {
        isSearching.value = false;
        hasSearched.value = true;
      }
    }, 350);
  },
  { immediate: false },
);

/** Has the user typed enough to expect search results yet? */
const searchTyping = computed(() => {
  if (!props.question.schoolSearch) return false;
  const q = String(props.modelValue ?? '').trim();
  return q.length > 0 && q.length < SEARCH_MIN;
});

const showSearchPanel = computed(() => {
  if (!props.question.schoolSearch) return false;
  return (
    isSearching.value ||
    searchHits.value.length > 0 ||
    (hasSearched.value && searchHits.value.length === 0) ||
    searchTyping.value
  );
});

/** Read the first non-empty value across the tenant / registry aliases. */
function hitEducationLevel(hit: SchoolSearchHit): string | null {
  return hit.education_level ?? hit.jenjang ?? null;
}
function hitCity(hit: SchoolSearchHit): string | null {
  return hit.city ?? hit.kota ?? null;
}
function hitProvince(hit: SchoolSearchHit): string | null {
  return hit.province ?? hit.provinsi ?? null;
}

function pickSchoolHit(hit: SchoolSearchHit): void {
  // Registry/Dapodik hits return the legacy Indonesian education_level
  // (`SD`/`SMP`/`SMA`/`SMK`) — normalise to the canonical English wire
  // form before committing to the payload so the rest of the wizard
  // doesn't see a mixed value set.
  const lvlRaw = hitEducationLevel(hit);
  const lvl = lvlRaw ? normalizeEducationLevel(lvlRaw) : null;
  const city = hitCity(hit);
  emit('patchPayload', (p: any) => ({
    ...p,
    school: {
      ...p.school,
      name: hit.name,
      npsn: hit.npsn ?? null,
      city: city ?? p.school.city ?? null,
      education_level: lvl ?? p.school.education_level,
    },
  }));
  emit('update', hit.name);
  // Hide the dropdown so the user knows the pick took effect.
  searchHits.value = [];
}

function hitTierColor(hit: SchoolSearchHit): string {
  if (hit.kind === 'tenant') return 'bg-emerald-50 text-emerald-700 border-emerald-200';
  if (hit.kind === 'demo') return 'bg-amber-50 text-amber-700 border-amber-200';
  return 'bg-slate-50 text-slate-600 border-slate-200';
}

function hitTierLabel(hit: SchoolSearchHit): string {
  if (hit.kind === 'tenant') return 'Sekolah KamilEdu';
  if (hit.kind === 'demo') return 'Demo aktif';
  return 'Registri NPSN';
}

// ── pills (single select) ───────────────────────────────────────────
function pickPill(v: string) {
  emit('update', v);
}

// ── pills_with_other (single chip + free-text fallback) ────────────
// "Other" is active when the current value doesn't exactly match any
// preset option. The free-text input below is rendered in that state
// + when the user explicitly clicks the "Lainnya…" chip (which
// blanks the value so the input starts empty + focused).
const isOtherActive = computed<boolean>(() => {
  if (props.question.input !== 'pills_with_other') return false;
  const v = String(props.modelValue ?? '').trim();
  if (v === '') return true;
  const opts = props.question.options ?? [];
  return !opts.some((o) => o.value === v);
});
function pickOther() {
  // Clear the value so the input below shows its placeholder. The
  // user types their custom role into it; the chip "Lainnya…" stays
  // visually active until the value matches a preset.
  emit('update', '');
}
function onOtherInput(e: Event) {
  const target = e.target as HTMLInputElement | null;
  emit('update', target?.value ?? '');
}

// ── chips_multi (multi select toggle) ──────────────────────────────
const multiValue = computed<string[]>(() => {
  const v = props.modelValue;
  if (Array.isArray(v)) return v.map(String);
  return [];
});
function toggleMulti(v: string) {
  const set = new Set(multiValue.value);
  if (set.has(v)) set.delete(v);
  else set.add(v);
  emit('update', Array.from(set));
}

// ── chips_add (programs) ───────────────────────────────────────────
const addBuffer = ref('');
const chipList = computed<string[]>(() => {
  const v = props.modelValue;
  if (Array.isArray(v)) return v.map(String);
  return [];
});
function toggleSuggestion(s: string) {
  const set = new Set(chipList.value);
  if (set.has(s)) set.delete(s);
  else set.add(s);
  emit('update', Array.from(set));
}
function commitNewChip() {
  const trimmed = addBuffer.value.trim();
  if (!trimmed) return;
  const list = [...chipList.value];
  if (!list.includes(trimmed)) {
    list.push(trimmed);
    emit('update', list);
  }
  addBuffer.value = '';
}
function removeChip(v: string) {
  emit(
    'update',
    chipList.value.filter((x) => x !== v),
  );
}

// ── social media ────────────────────────────────────────────────────
const socialChannels = DEMO_SOCIAL_CHANNELS;
const socialMap = computed<Record<DemoSocialChannel, string>>(() => {
  const v = (props.modelValue ?? {}) as Record<string, string>;
  return socialChannels.reduce(
    (acc, c) => ({ ...acc, [c]: v[c] ?? '' }),
    {} as Record<DemoSocialChannel, string>,
  );
});
function updateSocial(channel: DemoSocialChannel, value: string) {
  emit('update', { ...socialMap.value, [channel]: value });
}

const socialLabels: Record<DemoSocialChannel, { label: string; icon: string; ph: string }> = {
  instagram: { label: 'Instagram', icon: 'instagram', ph: '@username' },
  facebook: { label: 'Facebook', icon: 'facebook', ph: 'facebook.com/username' },
  threads: { label: 'Threads', icon: 'at', ph: '@username' },
  linkedin: { label: 'LinkedIn', icon: 'linkedin', ph: 'linkedin.com/in/…' },
  other: { label: 'Lain (TikTok / Web)', icon: 'link', ph: 'mis. tiktok.com/@username' },
};

const hasAnySocial = computed(() =>
  socialChannels.some((c) => (socialMap.value[c] ?? '').trim() !== ''),
);

/**
 * WhatsApp deeplink for the "tidak punya medsos" escape-hatch — a
 * minority of legitimate requesters (private individuals, low-
 * engagement profiles) genuinely have no public social presence and
 * would otherwise dead-end on this required step. Tapping the link
 * opens WhatsApp with a pre-filled message to the verification team
 * (+62 851-7981-9002) so they can route the requester through a
 * manual identity check.
 *
 * The message is intentionally brief + factual — references the
 * exact wizard step so the team can connect the chat back to the
 * requester's pending demo_request.
 */
const noSocialContactHref = computed(() => {
  const phone = '6285179819002';
  const msg =
    'Halo Tim KamilEdu,\n\nSaya ingin mendaftar demo KamilEdu tapi terkendala di ' +
    'langkah verifikasi media sosial — saya tidak memiliki akun media sosial yang ' +
    'aktif untuk dicantumkan.\n\nMohon panduan untuk verifikasi identitas melalui ' +
    'jalur alternatif. Terima kasih.';
  return `https://wa.me/${phone}?text=${encodeURIComponent(msg)}`;
});

// ── scenarios (bimbel) ─────────────────────────────────────────────
const scenarioSet = computed<Set<string>>(() => {
  const v = props.modelValue;
  if (Array.isArray(v)) return new Set(v as string[]);
  return new Set();
});
// ── bimbel location picker ─────────────────────────────────────────
/**
 * Current location value as a typed reference. The shell stores
 * `null` when the user hasn't picked yet — we read either the
 * existing value (resume) or a fresh null. Picker emits partial
 * picks (lat+lng first, reverse-geocoded address+city in a follow-up
 * emit) so we MERGE rather than replace, otherwise the second emit
 * would clobber the lat/lng with whatever defaults the picker sent.
 */
const currentLocation = computed<DemoTutoringLocation | null>(() => {
  const v = props.modelValue;
  if (v && typeof v === 'object') return v as DemoTutoringLocation;
  return null;
});

function onLocationPick(p: PickedLocation): void {
  const prev = currentLocation.value;
  emit('update', {
    lat: p.lat,
    lng: p.lng,
    // Keep the previous address/city if the new emit didn't include
    // one yet (reverse-geocode still pending).
    address: p.address ?? prev?.address ?? null,
    // has_office defaults to true the first time we get a pick — user
    // can flip the toggle below.
    has_office: prev?.has_office ?? true,
  } satisfies DemoTutoringLocation);

  // ALSO mirror the resolved city into tutoring.city so the wizard's
  // next question (Kota) auto-skips. We do this via the patchPayload
  // event so the parent updates that slice atomically with location.
  if (p.city && p.city.trim().length >= 2) {
    emit('patchPayload', (payload: any) => ({
      ...payload,
      tutoring: { ...payload.tutoring, city: p.city },
    }));
  }
}

function toggleHasOffice(): void {
  const loc = currentLocation.value;
  if (!loc) return;
  emit('update', { ...loc, has_office: !loc.has_office });
}

function clearLocation(): void {
  emit('update', null);
}

function toggleScenario(key: TutoringScenarioKey) {
  const set = new Set(scenarioSet.value);
  if (set.has(key)) set.delete(key);
  else set.add(key);
  emit('update', Array.from(set));
}
</script>

<template>
  <div class="w-full">
    <!-- text / tel ------------------------------------------------- -->
    <div
      v-if="question.input === 'text' || question.input === 'tel'"
      class="flex flex-col items-center"
    >
      <input
        ref="textRef"
        v-model="textValue"
        :type="question.input === 'tel' ? 'tel' : 'text'"
        :placeholder="question.placeholder"
        class="w-full max-w-md text-center text-lg font-medium px-4 py-3 rounded-xl border focus:outline-none focus:ring-2 transition"
        :class="
          inputWarning
            ? 'border-amber-300 focus:border-amber-500 focus:ring-amber-200'
            : 'border-slate-200 focus:border-brand-cobalt focus:ring-brand-cobalt/15'
        "
        @keydown.enter="onEnter"
      />

      <!-- gibberish / phone inline warning -->
      <p
        v-if="inputWarning"
        class="mt-2 text-[12px] text-amber-700 max-w-md text-center inline-flex items-center justify-center gap-1.5"
      >
        <NavIcon name="info" :size="12" />
        {{ inputWarning }}
      </p>

      <!-- school-search dropdown ---------------------------------- -->
      <div v-if="showSearchPanel" class="w-full max-w-md mt-3">
        <!-- ≥0 < 3 chars typed: hint user to type more -->
        <div
          v-if="searchTyping"
          class="bg-slate-50 border border-dashed border-slate-200 rounded-2xl px-4 py-3 text-center"
        >
          <p class="text-[12px] text-slate-500 inline-flex items-center gap-1.5">
            <NavIcon name="search" :size="13" />
            Ketik minimal 3 karakter untuk mencari…
          </p>
        </div>

        <!-- searching state -->
        <div
          v-else-if="isSearching"
          class="bg-white border border-slate-200 rounded-2xl px-4 py-3 text-center"
        >
          <p class="text-[12px] text-slate-500 inline-flex items-center gap-1.5">
            <NavIcon name="search" :size="13" class="animate-pulse" />
            Mencari dari registri NPSN…
          </p>
        </div>

        <!-- has hits -->
        <template v-else-if="searchHits.length > 0">
          <div class="flex items-center gap-2 px-1 mb-1.5">
            <span class="text-[10px] font-black uppercase tracking-widest text-slate-400">
              {{ searchHits.length }} hasil ditemukan
            </span>
          </div>
          <div class="bg-white border border-slate-200 rounded-2xl overflow-hidden divide-y divide-slate-100 shadow-card">
            <button
              v-for="hit in searchHits"
              :key="(hit.id ?? '') + ':' + (hit.npsn ?? '') + ':' + hit.name"
              type="button"
              class="w-full text-left px-4 py-3 hover:bg-slate-50 transition flex items-start gap-3 group"
              @click="pickSchoolHit(hit)"
            >
              <div class="w-8 h-8 rounded-lg bg-brand-cobalt/10 text-brand-cobalt grid place-items-center flex-shrink-0">
                <NavIcon name="building" :size="14" />
              </div>
              <div class="flex-1 min-w-0">
                <div class="text-[13px] font-bold text-slate-900 truncate">{{ hit.name }}</div>
                <div class="text-[11px] text-slate-500 truncate">
                  {{
                    [
                      educationLevelDisplay(hitEducationLevel(hit)),
                      hitCity(hit),
                      hitProvince(hit),
                    ]
                      .filter(Boolean)
                      .join(' · ') || '—'
                  }}
                  <span v-if="hit.npsn" class="font-mono text-slate-400">· NPSN {{ hit.npsn }}</span>
                </div>
              </div>
              <span
                class="text-[10px] font-bold px-2 py-0.5 rounded-md border whitespace-nowrap flex-shrink-0"
                :class="hitTierColor(hit)"
              >
                {{ hitTierLabel(hit) }}
              </span>
            </button>
          </div>
          <p class="text-[10.5px] text-slate-400 mt-2 text-center">
            Klik untuk pakai data dari registri. Atau lanjut dengan ketikan Anda untuk daftar baru.
          </p>
        </template>

        <!-- searched but 0 hits -->
        <div
          v-else
          class="bg-slate-50 border border-dashed border-slate-200 rounded-2xl px-4 py-4 text-center"
        >
          <p class="text-[12px] text-slate-500 mb-1 inline-flex items-center gap-1.5">
            <NavIcon name="info" :size="13" />
            Tidak ada sekolah cocok di registri.
          </p>
          <p class="text-[11px] text-slate-400">
            Tidak masalah — lanjut dengan ketikan Anda untuk mendaftarkan sebagai sekolah baru.
          </p>
        </div>
      </div>
    </div>

    <!-- number ----------------------------------------------------- -->
    <div
      v-else-if="question.input === 'number'"
      class="flex flex-col items-center"
    >
      <div class="flex items-center justify-center gap-3">
        <input
          ref="textRef"
          v-model="textValue"
          type="number"
          inputmode="numeric"
          min="0"
          :placeholder="question.placeholder"
          class="w-44 text-center text-xl font-semibold px-4 py-3 rounded-xl border focus:outline-none focus:ring-2 transition"
          :class="
            inputWarning
              ? 'border-amber-300 focus:border-amber-500 focus:ring-amber-200'
              : 'border-slate-200 focus:border-brand-cobalt focus:ring-brand-cobalt/15'
          "
          @keydown.enter="onEnter"
        />
        <span v-if="question.suffix" class="text-sm text-slate-500 font-medium">
          {{ question.suffix }}
        </span>
      </div>
      <p
        v-if="inputWarning"
        class="mt-2 text-[12px] text-amber-700 inline-flex items-center gap-1.5"
      >
        <NavIcon name="info" :size="12" />
        {{ inputWarning }}
      </p>
    </div>

    <!-- pills (single select) ------------------------------------- -->
    <div
      v-else-if="question.input === 'pills'"
      class="flex flex-wrap justify-center gap-2 max-w-2xl mx-auto"
    >
      <button
        v-for="o in question.options"
        :key="o.value"
        type="button"
        class="px-4 py-2.5 rounded-xl border text-sm font-semibold transition text-left"
        :class="
          modelValue === o.value
            ? 'bg-brand-cobalt/10 border-brand-cobalt text-brand-cobalt'
            : 'bg-white border-slate-200 text-slate-700 hover:border-brand-cobalt/40'
        "
        @click="pickPill(o.value)"
      >
        <div>{{ o.label }}</div>
        <div
          v-if="o.hint"
          class="text-[11px] font-medium mt-0.5"
          :class="modelValue === o.value ? 'text-brand-cobalt/80' : 'text-slate-400'"
        >
          {{ o.hint }}
        </div>
      </button>
    </div>

    <!--
      pills_with_other ----------------------------------------------
      Single-select chip picker with a free-text fallback for "Other".
      The chip is active when modelValue exactly matches one of the
      options; otherwise the "Lainnya" chip lights up and reveals an
      input below for the custom role. setValue receives the final
      STRING either way — backend doesn't care which path produced it.
    -->
    <div
      v-else-if="question.input === 'pills_with_other'"
      class="max-w-2xl mx-auto"
    >
      <div class="flex flex-wrap justify-center gap-2">
        <button
          v-for="o in question.options"
          :key="o.value"
          type="button"
          class="px-4 py-2.5 rounded-xl border text-sm font-semibold transition"
          :class="
            modelValue === o.value
              ? 'bg-brand-cobalt/10 border-brand-cobalt text-brand-cobalt'
              : 'bg-white border-slate-200 text-slate-700 hover:border-brand-cobalt/40'
          "
          @click="pickPill(o.value)"
        >
          {{ o.label }}
        </button>
        <button
          type="button"
          class="px-4 py-2.5 rounded-xl border text-sm font-semibold transition"
          :class="
            isOtherActive
              ? 'bg-brand-cobalt/10 border-brand-cobalt text-brand-cobalt'
              : 'bg-white border-slate-200 text-slate-700 hover:border-brand-cobalt/40'
          "
          @click="pickOther"
        >
          Lainnya…
        </button>
      </div>
      <div v-if="isOtherActive" class="mt-4 max-w-xl mx-auto">
        <input
          :value="modelValue ?? ''"
          type="text"
          :placeholder="question.placeholder ?? 'Ketik peran Anda'"
          class="w-full px-4 py-3 bg-white border-2 border-slate-200 rounded-xl text-base text-slate-900 focus:outline-none focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/15 placeholder:text-slate-300"
          @input="onOtherInput($event)"
          @keydown.enter="onEnter"
        />
      </div>
    </div>

    <!-- chips_multi -------------------------------------------------->
    <div
      v-else-if="question.input === 'chips_multi'"
      class="flex flex-wrap justify-center gap-2 max-w-xl mx-auto"
    >
      <button
        v-for="o in question.options"
        :key="o.value"
        type="button"
        class="px-4 py-2 rounded-full border text-sm font-semibold transition"
        :class="
          multiValue.includes(o.value)
            ? 'bg-brand-cobalt text-white border-brand-cobalt'
            : 'bg-white border-slate-200 text-slate-700 hover:border-brand-cobalt/40'
        "
        @click="toggleMulti(o.value)"
      >
        {{ o.label }}
      </button>
    </div>

    <!-- chips_add (programs) -------------------------------------- -->
    <div v-else-if="question.input === 'chips_add'" class="max-w-xl mx-auto">
      <div v-if="question.suggestions?.length" class="flex flex-wrap justify-center gap-2 mb-3">
        <button
          v-for="s in question.suggestions"
          :key="s"
          type="button"
          class="px-3 py-1.5 rounded-full border text-sm font-semibold transition"
          :class="
            chipList.includes(s)
              ? 'bg-brand-cobalt text-white border-brand-cobalt'
              : 'bg-white border-dashed border-slate-300 text-slate-600 hover:border-brand-cobalt/40'
          "
          @click="toggleSuggestion(s)"
        >
          + {{ s }}
        </button>
      </div>

      <div v-if="chipList.length" class="flex flex-wrap justify-center gap-2 mb-3">
        <span
          v-for="c in chipList"
          :key="c"
          class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-brand-cobalt/10 text-brand-cobalt text-sm font-semibold"
        >
          {{ c }}
          <button
            type="button"
            class="text-brand-cobalt/70 hover:text-brand-cobalt"
            :aria-label="`Hapus ${c}`"
            @click="removeChip(c)"
          >
            <NavIcon name="x" :size="12" />
          </button>
        </span>
      </div>

      <div class="flex items-center gap-2 max-w-md mx-auto">
        <input
          ref="textRef"
          v-model="addBuffer"
          type="text"
          :placeholder="question.placeholder"
          class="flex-1 px-4 py-2.5 rounded-xl border border-slate-200 focus:outline-none focus:border-brand-cobalt focus:ring-2 focus:ring-brand-cobalt/15 transition text-sm"
          @keydown.enter.prevent="commitNewChip"
        />
        <button
          type="button"
          class="px-4 py-2.5 rounded-xl bg-slate-100 text-slate-700 text-sm font-semibold hover:bg-slate-200 transition disabled:opacity-50"
          :disabled="!addBuffer.trim()"
          @click="commitNewChip"
        >
          Tambah
        </button>
      </div>
    </div>

    <!-- social media (5 channels, ≥1 required) -------------------- -->
    <div v-else-if="question.input === 'social'" class="max-w-md mx-auto space-y-2">
      <div
        v-for="c in socialChannels"
        :key="c"
        class="flex items-center gap-3 bg-white rounded-xl border border-slate-200 px-3 py-2 focus-within:border-brand-cobalt focus-within:ring-2 focus-within:ring-brand-cobalt/15 transition"
      >
        <div class="w-8 h-8 rounded-lg bg-slate-50 text-slate-600 grid place-items-center flex-shrink-0">
          <NavIcon :name="socialLabels[c].icon" :size="16" />
        </div>
        <div class="flex-1 min-w-0 text-left">
          <div class="text-[10px] font-bold uppercase tracking-widest text-slate-400 mb-0.5">
            {{ socialLabels[c].label }}
          </div>
          <input
            :value="socialMap[c]"
            type="text"
            :placeholder="socialLabels[c].ph"
            class="w-full text-sm text-slate-900 bg-transparent focus:outline-none placeholder:text-slate-300 text-left"
            @input="updateSocial(c, ($event.target as HTMLInputElement).value)"
            @keydown.enter="onEnter"
          />
        </div>
        <NavIcon
          v-if="(socialMap[c] ?? '').trim()"
          name="check-circle"
          :size="16"
          class="text-emerald-500 flex-shrink-0"
        />
      </div>
      <p
        class="text-[11px] mt-2 text-center"
        :class="hasAnySocial ? 'text-emerald-600' : 'text-amber-600'"
      >
        <NavIcon
          :name="hasAnySocial ? 'check-circle' : 'info'"
          :size="11"
          class="inline-block mr-1"
        />
        {{ hasAnySocial ? 'Cukup — minimal satu sudah terisi.' : 'Minimal satu channel wajib diisi.' }}
      </p>

      <!--
        Escape-hatch: a small minority of legitimate requesters genuinely
        have no public social presence (private individuals, very-low-
        engagement profiles). Rather than dead-end them on this required
        step, surface a manual-review path that pre-fills a WhatsApp
        message to the demo team. They can verify identity through
        another channel.
      -->
      <a
        :href="noSocialContactHref"
        target="_blank"
        rel="noopener"
        class="mt-4 block text-center text-[12px] text-slate-500 hover:text-brand-cobalt underline underline-offset-2 transition"
      >
        Tidak punya media sosial? Hubungi tim verifikasi
      </a>
    </div>

    <!-- scenarios (bimbel) ---------------------------------------- -->
    <!-- bimbel location (Nominatim/Leaflet map picker) -->
    <div v-else-if="question.input === 'location'" class="max-w-2xl mx-auto text-left">
      <TutoringLocationPicker
        :lat="currentLocation?.lat ?? null"
        :lng="currentLocation?.lng ?? null"
        :address="currentLocation?.address ?? null"
        @pick="onLocationPick"
      />

      <!-- Picked-location summary + "Belum punya kantor fisik" toggle. -->
      <div
        v-if="currentLocation"
        class="mt-4 rounded-2xl border bg-slate-50 px-4 py-3"
        :class="
          currentLocation.has_office
            ? 'border-slate-200'
            : 'border-amber-200 bg-amber-50/60'
        "
      >
        <div class="flex items-start gap-3">
          <NavIcon
            :name="currentLocation.has_office ? 'map-pin' : 'user'"
            :size="16"
            class="mt-0.5 flex-shrink-0"
            :class="currentLocation.has_office ? 'text-brand-cobalt' : 'text-amber-700'"
          />
          <div class="flex-1 min-w-0">
            <p
              class="text-[10px] font-black uppercase tracking-widest mb-0.5"
              :class="currentLocation.has_office ? 'text-brand-cobalt' : 'text-amber-700'"
            >
              {{
                currentLocation.has_office
                  ? 'Alamat kantor lembaga'
                  : 'Lokasi operator (tanpa kantor fisik)'
              }}
            </p>
            <p class="text-[12px] text-slate-700 leading-snug">
              {{ currentLocation.address ?? 'Memuat alamat dari pin…' }}
            </p>
            <p class="text-[10.5px] font-mono text-slate-400 mt-0.5">
              {{ currentLocation.lat.toFixed(5) }},
              {{ currentLocation.lng.toFixed(5) }}
            </p>
          </div>
          <button
            type="button"
            class="text-[11px] font-semibold text-slate-500 hover:text-slate-900 flex-shrink-0"
            @click="clearLocation"
          >
            Hapus
          </button>
        </div>
        <label
          class="mt-3 flex items-start gap-2.5 text-[12px] text-slate-700 cursor-pointer pt-3 border-t border-slate-200/70"
        >
          <input
            type="checkbox"
            :checked="!currentLocation.has_office"
            class="w-4 h-4 accent-amber-600 mt-0.5"
            @change="toggleHasOffice"
          />
          <span class="leading-snug">
            <span class="font-semibold">Belum punya kantor fisik</span>
            <span class="block text-[11px] text-slate-500 mt-0.5">
              Centang kalau Anda bimbel online / mobile. Pin di atas
              dianggap sebagai lokasi operator, bukan alamat kantor —
              tim verifikasi akan menyesuaikan flow konfirmasi.
            </span>
          </span>
        </label>
      </div>

      <!-- Empty-state nudge — location is required, but if the
           lembaga doesn't have an office yet, the requester can
           still proceed by picking their current location and
           ticking the "Belum punya kantor fisik" toggle that
           appears once a pin is dropped. -->
      <div
        v-else
        class="mt-3 rounded-2xl border border-dashed border-slate-300 bg-slate-50/70 px-4 py-3 text-center"
      >
        <p class="text-[12px] font-semibold text-slate-700">
          Lokasi wajib diisi.
        </p>
        <p class="text-[11px] text-slate-500 mt-1 leading-snug">
          Klik <span class="font-semibold text-brand-cobalt">“Lokasi saya”</span>
          atau tap di peta untuk drop pin. Belum punya kantor fisik?
          Pakai lokasi sekarang saja — akan muncul toggle untuk menandai
          itu sebagai lokasi operator.
        </p>
      </div>
    </div>

    <div v-else-if="question.input === 'scenarios'" class="grid sm:grid-cols-2 gap-2 max-w-2xl mx-auto">
      <button
        v-for="s in TUTORING_SCENARIO_DEFINITIONS"
        :key="s.key"
        type="button"
        class="flex items-start gap-3 text-left px-3 py-3 rounded-xl border transition"
        :class="
          scenarioSet.has(s.key)
            ? 'bg-brand-cobalt/5 border-brand-cobalt'
            : 'bg-white border-slate-200 hover:border-brand-cobalt/40'
        "
        @click="toggleScenario(s.key)"
      >
        <div
          class="w-8 h-8 rounded-lg grid place-items-center flex-shrink-0"
          :class="scenarioSet.has(s.key) ? 'bg-brand-cobalt text-white' : 'bg-slate-100 text-slate-500'"
        >
          <NavIcon :name="scenarioSet.has(s.key) ? 'check' : s.icon" :size="15" />
        </div>
        <div class="flex-1 min-w-0">
          <div class="text-sm font-bold text-slate-900">{{ s.label }}</div>
          <div class="text-[11px] text-slate-500 leading-snug">{{ s.description }}</div>
        </div>
      </button>
    </div>
  </div>
</template>
