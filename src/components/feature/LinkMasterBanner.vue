<!--
  LinkMasterBanner.vue — inline warning banner that appears on the
  LMS views (TeacherGradeRecapDetailView, TeacherMaterialView) when
  the currently-picked subject_schools row isn't yet linked to a
  master curriculum subject (subject_schools.subject_id IS NULL).

  Mirrors the Flutter `LinkMasterBanner` widget on mobile. The banner
  is self-contained around the API round-trip:

    - First render → GET /subjects/{id}/link-status (silent).
    - is_linked === true → renders nothing (v-if collapse).
    - is_linked === false → amber card with title, body and CTA that
      opens <LinkMasterPickerModal> for the "Tautkan Sekarang" flow.

  On successful link the banner hides itself (state flips) and emits
  `linked` so the parent re-fetches its dependent data (grade rows,
  chapter tree). Emitting instead of prop-drilling a callback keeps
  the parent's data-refresh logic close to its own state.

  The banner is a no-cost sliver on the happy path — the initial GET
  is fired once, and while it's in flight nothing renders (avoids the
  flash-then-hide flicker on a linked subject).
-->
<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { SubjectService } from '@/services/subjects.service';
import { useToast } from '@/composables/useToast';
import LinkMasterPickerModal from '@/components/feature/LinkMasterPickerModal.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const props = defineProps<{
  /** subject_schools.id of the mapel currently on screen. */
  subjectId: string;
  /**
   * Which host view renders the banner — decides the body copy
   * ("Rekap Nilai" vs "Bab"). Picker behaviour is identical.
   */
  context: 'grade-recap' | 'chapter';
}>();

const emit = defineEmits<{
  /** Fired after a successful PATCH so the parent can re-fetch. */
  (e: 'linked'): void;
}>();

const { t } = useI18n();
const toast = useToast();

interface LinkStatus {
  subject_school_id: string;
  name: string;
  code: string | null;
  subject_id: number | null;
  master_name: string | null;
  is_linked: boolean;
  suggested_master_id: number | null;
}

const status = ref<LinkStatus | null>(null);
const loading = ref(true);
const showPicker = ref(false);

const bodyText = computed(() =>
  props.context === 'chapter'
    ? t('admin.subjects.linkMaster.bannerBodyChapter')
    : t('admin.subjects.linkMaster.bannerBodyRecap'),
);

async function fetchStatus() {
  loading.value = true;
  const data = await SubjectService.getLinkStatus(props.subjectId);
  status.value = data;
  loading.value = false;
}

onMounted(fetchStatus);

// When the parent swaps the picked subject (e.g. user switches
// class/subject in the recap wizard), re-poll link-status so the
// banner reflects the new row.
watch(
  () => props.subjectId,
  (next, prev) => {
    if (next && next !== prev) fetchStatus();
  },
);

function openPicker() {
  showPicker.value = true;
}

function closePicker() {
  showPicker.value = false;
}

async function onPickerLinked() {
  // Silent success toast + refresh our own status; the parent
  // handles its own data refresh via the `linked` event.
  toast.success(t('admin.subjects.linkMaster.success'));
  showPicker.value = false;
  await fetchStatus();
  emit('linked');
}
</script>

<template>
  <!--
    Silent while the first link-status is in flight so the UI doesn't
    flash the banner and then hide it on the next frame. Also silent
    when link-status errored (fail-open — better a hidden banner than
    a permanent one that a transient network hiccup pinned open).
  -->
  <div v-if="!loading && status && !status.is_linked" class="link-master-banner-wrap">
    <div class="link-master-banner">
      <div class="link-master-banner__icon">
        <NavIcon name="link" :size="18" />
      </div>
      <div class="link-master-banner__body">
        <div class="link-master-banner__title">
          {{ t('admin.subjects.linkMaster.bannerTitle') }}
        </div>
        <p class="link-master-banner__text">
          {{ bodyText }}
        </p>
        <button
          type="button"
          class="link-master-banner__cta"
          @click="openPicker"
        >
          <NavIcon name="link" :size="14" class="link-master-banner__cta-icon" />
          {{ t('admin.subjects.linkMaster.bannerCta') }}
        </button>
      </div>
    </div>
    <LinkMasterPickerModal
      v-if="showPicker && status"
      :subject-id="props.subjectId"
      :subject-name="status.name"
      :suggested-master-id="status.suggested_master_id"
      @close="closePicker"
      @linked="onPickerLinked"
    />
  </div>
</template>

<style scoped>
.link-master-banner-wrap {
  margin: 0.75rem 0 0.25rem;
}
.link-master-banner {
  display: flex;
  gap: 0.75rem;
  align-items: flex-start;
  padding: 0.875rem 1rem;
  border-radius: 12px;
  border: 1px solid rgb(251 191 36); /* amber-400 */
  background: rgb(255 251 235); /* amber-50 */
}
.link-master-banner__icon {
  flex: none;
  width: 34px;
  height: 34px;
  border-radius: 9px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgb(254 243 199); /* amber-100 */
  color: rgb(180 83 9); /* amber-700 */
}
.link-master-banner__body {
  flex: 1 1 auto;
  min-width: 0;
}
.link-master-banner__title {
  color: rgb(146 64 14); /* amber-800 */
  font-weight: 700;
  font-size: 0.875rem;
  line-height: 1.25;
}
.link-master-banner__text {
  color: rgb(146 64 14);
  font-size: 0.8125rem;
  line-height: 1.4;
  margin-top: 0.25rem;
}
.link-master-banner__cta {
  margin-top: 0.625rem;
  display: inline-flex;
  align-items: center;
  gap: 0.375rem;
  padding: 0.4375rem 0.875rem;
  border-radius: 8px;
  background: rgb(217 119 6); /* amber-600 */
  color: white;
  font-size: 0.8125rem;
  font-weight: 600;
  border: none;
  cursor: pointer;
  transition: background 120ms ease;
}
.link-master-banner__cta:hover {
  background: rgb(180 83 9); /* amber-700 */
}
.link-master-banner__cta:focus-visible {
  outline: 2px solid rgb(217 119 6);
  outline-offset: 2px;
}
.link-master-banner__cta-icon {
  flex: none;
}
</style>
