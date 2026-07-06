<!--
  AsyncView.vue — async-data state-machine wrapper.
  Web equivalent of Flutter's TeacherAsyncView in `lib/core/widgets/`.

  Pass a `state` object — { status: 'loading'|'error'|'empty'|'content', error?, … }
  and the component renders the right child:
    - loading  → Spinner
    - error    → ErrorState
    - empty    → EmptyState
    - content  → default slot (your list/table)

  This is the canonical pattern for list screens. Don't hand-roll
  `if (isLoading) … else if (error) …` blocks.
-->
<script setup lang="ts" generic="T">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Spinner from '../ui/Spinner.vue';
import EmptyState from './EmptyState.vue';
import ErrorState from './ErrorState.vue';

export interface AsyncState<T> {
  status: 'loading' | 'error' | 'empty' | 'content';
  data?: T;
  error?: string | null;
}

const props = withDefaults(
  defineProps<{
    state: AsyncState<T>;
    loadingLabel?: string;
    emptyTitle?: string;
    emptyDescription?: string;
    emptyIcon?: string;
    emptyActionLabel?: string;
    errorTitle?: string;
    minHeight?: string;
  }>(),
  {
    emptyDescription: '',
    emptyIcon: 'inbox',
    emptyActionLabel: '',
    minHeight: '12rem',
  },
);

defineEmits<{ retry: []; 'empty-action': [] }>();

const { t } = useI18n();

// Defaults resolve through i18n so every page using AsyncView gets
// localised loading/error/empty labels for free unless it passes its own copy.
const loadingLabelText = computed(() =>
  props.loadingLabel?.trim() ? props.loadingLabel : t('common.loading'),
);
const emptyTitleText = computed(() =>
  props.emptyTitle?.trim() ? props.emptyTitle : t('common.emptyTitle'),
);
const errorTitleText = computed(() =>
  props.errorTitle?.trim() ? props.errorTitle : t('common.errorTitle'),
);
const errorMessageText = computed(() =>
  props.state.error ?? t('common.errorMessage'),
);
</script>

<template>
  <div :style="{ minHeight }" class="w-full">
    <div
      v-if="state.status === 'loading'"
      class="flex flex-col items-center justify-center py-xl text-slate-400"
    >
      <Spinner size="md" />
      <p class="mt-sm text-sm">{{ loadingLabelText }}</p>
    </div>

    <ErrorState
      v-else-if="state.status === 'error'"
      :title="errorTitleText"
      :message="errorMessageText"
      @retry="$emit('retry')"
    />

    <EmptyState
      v-else-if="state.status === 'empty'"
      :title="emptyTitleText"
      :description="emptyDescription"
      :icon="emptyIcon"
      :action-label="emptyActionLabel"
      @action="$emit('empty-action')"
    />

    <slot v-else :data="state.data" />
  </div>
</template>
