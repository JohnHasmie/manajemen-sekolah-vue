<!--
  AsyncView.vue — async-data state-machine wrapper.
  Web equivalent of Flutter's TeacherAsyncView in `lib/core/widgets/`.

  Pass a `state` object — { status: 'loading'|'error'|'empty'|'content', error?, … }
  and the component renders the right child:
    - loading  → skeleton (shape controlled by `loading-variant` prop or #loading slot)
    - error    → ErrorState
    - empty    → EmptyState
    - content  → default slot (your list/table)

  Loading branch shape:
    - default: 'list' — N rows of icon-square + 2 lines, matches most
      list-heavy views (schedule, roster, activity feed, announcement).
    - 'cards' — grid of N placeholder cards (dashboards, hub tiles).
    - 'spinner' — the legacy centred spinner + label (opt-in for
      short-response calls where a skeleton would over-dominate).
    - #loading slot — hand it a bespoke skeleton for unusual layouts
      (matrix grids, forms, complex hero sections).

  This is the canonical pattern for list screens. Don't hand-roll
  `if (isLoading) … else if (error) …` blocks.
-->
<script setup lang="ts" generic="T">
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Spinner from '../ui/Spinner.vue';
import EmptyState from './EmptyState.vue';
import ErrorState from './ErrorState.vue';
import SkeletonList from './SkeletonList.vue';
import SkeletonCards from './SkeletonCards.vue';
import { classifyError, type ErrorHint } from '@/lib/errorHints';

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
    /**
     * Override the auto-classified error hint. Leave undefined to let
     * AsyncView infer from the raw error string ("Network Error" →
     * network, "status code 403" → permission, etc.).
     */
    errorHint?: ErrorHint | null;
    minHeight?: string;
    /**
     * How the loading branch is rendered.
     * - `list` (default): N stacked skeleton rows — matches most list
     *   views and reads as "loading" everywhere else too.
     * - `cards`: grid of N skeleton cards (dashboards, hub tiles).
     * - `spinner`: legacy centred spinner + label — pick this only for
     *   very short-response calls where a skeleton over-dominates.
     * Providing a `#loading` slot overrides this prop entirely.
     */
    loadingVariant?: 'list' | 'cards' | 'spinner';
    /** How many skeleton rows/cards to render (list/cards variants). */
    loadingRows?: number;
  }>(),
  {
    emptyDescription: '',
    emptyIcon: 'inbox',
    emptyActionLabel: '',
    minHeight: '12rem',
    loadingVariant: 'list',
    loadingRows: 3,
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
// Explicit prop wins; otherwise best-effort classification from the
// raw error string. `undefined` means "no explicit override" — we
// still auto-classify; `null` means "no hint at all", suppressing it.
const errorHintText = computed<ErrorHint | null>(() => {
  if (props.errorHint !== undefined) return props.errorHint;
  return classifyError(props.state.error);
});
</script>

<template>
  <div :style="{ minHeight }" class="w-full">
    <template v-if="state.status === 'loading'">
      <!-- Custom skeleton from the parent — used by views whose loaded
           shape isn't a list or a card grid (matrix, form, hero). -->
      <slot name="loading">
        <SkeletonList
          v-if="loadingVariant === 'list'"
          :rows="loadingRows"
        />
        <SkeletonCards
          v-else-if="loadingVariant === 'cards'"
          :cards="loadingRows"
        />
        <div
          v-else
          class="flex flex-col items-center justify-center py-xl text-slate-400"
        >
          <Spinner size="md" />
          <p class="mt-sm text-sm">{{ loadingLabelText }}</p>
        </div>
      </slot>
    </template>

    <ErrorState
      v-else-if="state.status === 'error'"
      :title="errorTitleText"
      :message="errorMessageText"
      :hint="errorHintText"
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
