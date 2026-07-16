<!--
  LinkMasterPickerModal.vue — bottom-sheet-style picker used by
  <LinkMasterBanner> to bind a subject_schools row to a master
  curriculum subject.

  Lists /master-subjects (school-scoped by education level on the
  server) with a debounced search box. The row whose id matches
  the banner's `suggestedMasterId` (backend-suggested by LOWER-name
  exact match) is pre-selected on open so the admin can confirm the
  obvious pair in one click.

  Confirm hits PATCH /subjects/{id}/link-master and emits `linked`
  on success. Dismiss (backdrop / Cancel / ESC) emits `close`.

  Mirrors Flutter's `LinkMasterPickerSheet`.
-->
<script setup lang="ts">
import { onMounted, onUnmounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { SubjectService, type MasterSubject } from '@/services/subjects.service';
import { useToast } from '@/composables/useToast';
import Modal from '@/components/ui/Modal.vue';
import Button from '@/components/ui/Button.vue';
import Spinner from '@/components/ui/Spinner.vue';
import NavIcon from '@/components/feature/NavIcon.vue';

const props = defineProps<{
  subjectId: string;
  subjectName: string;
  suggestedMasterId?: number | null;
}>();

const emit = defineEmits<{
  (e: 'close'): void;
  (e: 'linked'): void;
}>();

const { t } = useI18n();
const toast = useToast();

const rows = ref<MasterSubject[]>([]);
const loading = ref(true);
const submitting = ref(false);
const searchQuery = ref('');
const selectedId = ref<number | null>(null);

let debounceHandle: ReturnType<typeof setTimeout> | null = null;

async function load(search?: string) {
  loading.value = true;
  try {
    rows.value = await SubjectService.listMasterSubjects(search);
  } finally {
    loading.value = false;
  }
}

onMounted(async () => {
  selectedId.value = props.suggestedMasterId ?? null;
  await load();
});

onUnmounted(() => {
  if (debounceHandle) clearTimeout(debounceHandle);
});

watch(searchQuery, (next) => {
  if (debounceHandle) clearTimeout(debounceHandle);
  debounceHandle = setTimeout(() => {
    load(next.trim() || undefined);
  }, 220);
});

function selectRow(m: MasterSubject) {
  const numericId = Number(m.id);
  if (Number.isFinite(numericId)) {
    selectedId.value = numericId;
  }
}

async function confirm() {
  if (selectedId.value == null || submitting.value) return;
  submitting.value = true;
  try {
    await SubjectService.linkToMaster(props.subjectId, selectedId.value);
    emit('linked');
  } catch {
    toast.error(t('admin.subjects.linkMaster.failed'));
  } finally {
    submitting.value = false;
  }
}

function isSelected(m: MasterSubject) {
  return Number(m.id) === selectedId.value;
}

function isSuggested(m: MasterSubject) {
  return (
    props.suggestedMasterId != null && Number(m.id) === props.suggestedMasterId
  );
}
</script>

<template>
  <Modal
    :title="t('admin.subjects.linkMaster.pickerTitle')"
    :subtitle="t('admin.subjects.linkMaster.pickerSubtitle')"
    size="md"
    @close="emit('close')"
  >
    <div class="link-master-picker">
      <div class="link-master-picker__search">
        <NavIcon name="search" :size="16" class="link-master-picker__search-icon" />
        <input
          v-model="searchQuery"
          type="text"
          :placeholder="t('admin.subjects.linkMaster.pickerSearch')"
          class="link-master-picker__search-input"
        />
      </div>

      <div class="link-master-picker__list">
        <div v-if="loading" class="link-master-picker__loading">
          <Spinner size="sm" />
          <span>{{ t('admin.subjects.linkMaster.pickerLoading') }}</span>
        </div>
        <div v-else-if="rows.length === 0" class="link-master-picker__empty">
          {{ t('admin.subjects.linkMaster.pickerEmpty') }}
        </div>
        <button
          v-for="row in rows"
          v-else
          :key="row.id"
          type="button"
          class="link-master-picker__row"
          :class="{ 'link-master-picker__row--selected': isSelected(row) }"
          @click="selectRow(row)"
        >
          <span class="link-master-picker__radio" aria-hidden="true">
            <span v-if="isSelected(row)" class="link-master-picker__radio-dot" />
          </span>
          <div class="link-master-picker__row-body">
            <div class="link-master-picker__row-title">
              <span>{{ row.name }}</span>
              <span
                v-if="isSuggested(row)"
                class="link-master-picker__badge"
              >
                {{ t('admin.subjects.linkMaster.pickerSuggestedBadge') }}
              </span>
            </div>
            <div
              v-if="row.grade_level"
              class="link-master-picker__row-grade"
            >
              Grade {{ row.grade_level }}
            </div>
          </div>
        </button>
      </div>

      <div class="link-master-picker__footer">
        <Button variant="ghost" @click="emit('close')">
          {{ t('admin.subjects.linkMaster.pickerCancel') }}
        </Button>
        <Button
          variant="primary"
          :disabled="selectedId == null || submitting"
          :loading="submitting"
          @click="confirm"
        >
          {{ t('admin.subjects.linkMaster.pickerConfirm') }}
        </Button>
      </div>
    </div>
  </Modal>
</template>

<style scoped>
.link-master-picker {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.link-master-picker__search {
  position: relative;
  display: flex;
  align-items: center;
}

.link-master-picker__search-icon {
  position: absolute;
  left: 0.75rem;
  color: rgb(100 116 139); /* slate-500 */
  pointer-events: none;
}

.link-master-picker__search-input {
  width: 100%;
  padding: 0.55rem 0.75rem 0.55rem 2rem;
  border-radius: 8px;
  border: 1px solid rgb(203 213 225); /* slate-300 */
  font-size: 0.875rem;
  background: white;
  color: rgb(15 23 42); /* slate-900 */
}

.link-master-picker__search-input:focus {
  outline: none;
  border-color: rgb(217 119 6); /* amber-600 */
  box-shadow: 0 0 0 2px rgb(253 230 138 / 0.5); /* amber-200 */
}

.link-master-picker__list {
  max-height: 22rem;
  overflow-y: auto;
  border: 1px solid rgb(226 232 240); /* slate-200 */
  border-radius: 8px;
  padding: 0.25rem;
  background: white;
}

.link-master-picker__loading,
.link-master-picker__empty {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  padding: 2rem 1rem;
  color: rgb(100 116 139);
  font-size: 0.875rem;
}

.link-master-picker__row {
  width: 100%;
  display: flex;
  align-items: flex-start;
  gap: 0.625rem;
  padding: 0.625rem 0.75rem;
  border-radius: 6px;
  border: none;
  background: transparent;
  cursor: pointer;
  text-align: left;
  transition: background 100ms ease;
}

.link-master-picker__row:hover {
  background: rgb(248 250 252); /* slate-50 */
}

.link-master-picker__row--selected {
  background: rgb(255 251 235); /* amber-50 */
}

.link-master-picker__row--selected:hover {
  background: rgb(254 243 199); /* amber-100 */
}

.link-master-picker__radio {
  flex: none;
  width: 18px;
  height: 18px;
  border-radius: 50%;
  border: 2px solid rgb(148 163 184); /* slate-400 */
  margin-top: 2px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.link-master-picker__row--selected .link-master-picker__radio {
  border-color: rgb(217 119 6); /* amber-600 */
}

.link-master-picker__radio-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: rgb(217 119 6);
}

.link-master-picker__row-body {
  flex: 1 1 auto;
  min-width: 0;
}

.link-master-picker__row-title {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  color: rgb(30 41 59); /* slate-800 */
  font-size: 0.875rem;
  font-weight: 600;
}

.link-master-picker__badge {
  display: inline-flex;
  align-items: center;
  padding: 0.125rem 0.375rem;
  border-radius: 4px;
  background: rgb(254 243 199); /* amber-100 */
  color: rgb(146 64 14); /* amber-800 */
  font-size: 0.6875rem;
  font-weight: 700;
  letter-spacing: 0.02em;
}

.link-master-picker__row-grade {
  color: rgb(100 116 139); /* slate-500 */
  font-size: 0.75rem;
  margin-top: 0.125rem;
}

.link-master-picker__footer {
  display: flex;
  justify-content: flex-end;
  gap: 0.5rem;
  padding-top: 0.25rem;
}

/* Dark theme — the app already toggles class="dark" on <html> in
   the dark preference; align the surfaces so the picker fits the
   host page's tone. */
:global(.dark) .link-master-picker__search-input {
  background: rgb(30 41 59);
  color: rgb(226 232 240);
  border-color: rgb(51 65 85);
}
:global(.dark) .link-master-picker__list {
  background: rgb(15 23 42);
  border-color: rgb(51 65 85);
}
:global(.dark) .link-master-picker__row:hover {
  background: rgb(30 41 59);
}
:global(.dark) .link-master-picker__row--selected {
  background: rgb(120 53 15 / 0.35);
}
:global(.dark) .link-master-picker__row-title {
  color: rgb(226 232 240);
}
:global(.dark) .link-master-picker__row-grade {
  color: rgb(148 163 184);
}
</style>
