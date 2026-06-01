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
import Spinner from '../ui/Spinner.vue';
import EmptyState from './EmptyState.vue';
import ErrorState from './ErrorState.vue';

export interface AsyncState<T> {
  status: 'loading' | 'error' | 'empty' | 'content';
  data?: T;
  error?: string | null;
}

withDefaults(
  defineProps<{
    state: AsyncState<T>;
    emptyTitle?: string;
    emptyDescription?: string;
    emptyIcon?: string;
    errorTitle?: string;
    minHeight?: string;
  }>(),
  {
    emptyTitle: 'Belum ada data',
    emptyDescription: '',
    emptyIcon: 'inbox',
    errorTitle: 'Terjadi kesalahan',
    minHeight: '12rem',
  },
);

defineEmits<{ retry: [] }>();
</script>

<template>
  <div :style="{ minHeight }" class="w-full">
    <div
      v-if="state.status === 'loading'"
      class="flex items-center justify-center py-xl text-slate-400"
    >
      <Spinner size="md" />
    </div>

    <ErrorState
      v-else-if="state.status === 'error'"
      :title="errorTitle"
      :message="state.error ?? 'Mohon coba lagi dalam beberapa saat.'"
      @retry="$emit('retry')"
    />

    <EmptyState
      v-else-if="state.status === 'empty'"
      :title="emptyTitle"
      :description="emptyDescription"
      :icon="emptyIcon"
    />

    <slot v-else :data="state.data" />
  </div>
</template>
