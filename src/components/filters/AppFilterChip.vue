<!--
  AppFilterChip.vue - label + value pill with icon, used in the filter
  toolbar pattern for Teacher Presensi, Gradebook, and similar pages.

  Layout: [icon] [label / value] [chevron]
  Tone determines the icon-square color.
-->
<script setup lang="ts">
import { useAttrs, watchEffect } from 'vue';
import NavIcon from '@/components/feature/NavIcon.vue';

withDefaults(
  defineProps<{
    label: string;
    value: string;
    iconName?: string;
    tone?: 'brand' | 'amber' | 'violet' | 'green' | 'red' | 'slate';
    disabled?: boolean;
    /** A concrete filter value is applied (not the "all" default). Gives
     *  the chip a cobalt ring + role-admin-soft fill so an active filter
     *  is legible at a glance without changing the chip's structure. */
    active?: boolean;
  }>(),
  { iconName: '', tone: 'brand', disabled: false, active: false },
);

defineEmits<{ click: [] }>();

/**
 * Dev-only misspelled-prop guard.
 *
 * This component has a single root <button> and does not set
 * `inheritAttrs: false`, so ANY attribute it does not declare silently
 * falls through to the DOM. That is how ten call sites came to pass
 * `:is-active` instead of `:active`: Vue never matched it as a prop,
 * the real `active` stayed at its `false` default, and every one of
 * those chips rendered inert grey while its filter was applied. Nothing
 * failed — not the type-check, not the tests, not the build.
 *
 * `vue-tsc` cannot see this as the repo is configured: there is no
 * `vueCompilerOptions` anywhere, so Volar's `checkUnknownProps`
 * defaults to false and an undeclared attribute is legal by design
 * (indistinguishable from deliberate fall-through). Turning that flag
 * on is the stronger, repo-wide fix and is tracked separately; it costs
 * 62 errors across 40 files to get green first. Until then this guard
 * gives the one component with ~127 call sites a fast local signal.
 *
 * Stripped from production entirely: Vite replaces `import.meta.env.DEV`
 * with `false`, so the whole block is dead-code-eliminated.
 */
if (import.meta.env.DEV) {
  const attrs = useAttrs();

  const DECLARED = ['label', 'value', 'iconName', 'tone', 'disabled', 'active'];

  /**
   * Attributes that are LEGITIMATELY passed through to the root button
   * and must never warn. `title` is load-bearing: 15 call sites use it
   * for a native tooltip today, and a guard that cries wolf gets
   * switched off. Event listeners arrive camelised (`onKeydown`), every
   * other attribute under its authored name (`data-testid`, `is-active`).
   */
  const ALLOWED =
    /^(?:class|style|id|title|role|tabindex|slot|key|ref)$|^(?:data|aria)-|^on[A-Z]/;

  const camelize = (s: string) => s.replace(/-(\w)/g, (_, c: string) => c.toUpperCase());
  const warned = new Set<string>();

  watchEffect(() => {
    for (const name of Object.keys(attrs)) {
      if (ALLOWED.test(name) || warned.has(name)) continue;
      warned.add(name);

      // Did-you-mean: the common slip is an is-/has- prefix, so a
      // containment match on the normalised names finds it reliably.
      const norm = camelize(name).toLowerCase();
      const guess = DECLARED.find(
        (p) => norm.includes(p.toLowerCase()) || p.toLowerCase().includes(norm),
      );

      console.warn(
        `[AppFilterChip] Unknown prop "${name}" — it is NOT a declared prop, so it ` +
          `falls through to the DOM as a plain attribute and does nothing.` +
          (guess ? ` Did you mean ":${guess}"?` : '') +
          ` Declared props: ${DECLARED.join(', ')}.`,
      );
    }
  });
}
</script>

<template>
  <button
    type="button"
    class="inline-flex items-center gap-2.5 rounded-xl border transition-all px-3 py-2"
    :class="[
      disabled
        ? 'bg-slate-50 border-slate-100 text-slate-400 cursor-not-allowed'
        : active
          ? 'bg-role-admin-soft border-brand-cobalt ring-2 ring-brand-cobalt/30 text-slate-900'
          : 'bg-slate-50 border-slate-200 hover:bg-white hover:border-brand-cobalt text-slate-900',
    ]"
    :disabled="disabled"
    @click="$emit('click')"
  >
    <span
      v-if="iconName"
      class="w-7 h-7 rounded-lg grid place-items-center flex-shrink-0"
      :class="{
        'bg-brand-cobalt/10 text-brand-cobalt': tone === 'brand',
        'bg-amber-100 text-amber-700': tone === 'amber',
        'bg-violet-100 text-violet-700': tone === 'violet',
        'bg-emerald-100 text-emerald-700': tone === 'green',
        'bg-red-100 text-red-700': tone === 'red',
        'bg-slate-100 text-slate-600': tone === 'slate',
      }"
    >
      <NavIcon :name="iconName" :size="14" />
    </span>
    <span class="flex flex-col items-start min-w-0 leading-none">
      <span class="text-4xs font-bold text-slate-400 uppercase tracking-widest">{{ label }}</span>
      <span class="text-[13px] font-bold text-slate-900 truncate mt-0.5">{{ value }}</span>
    </span>
    <svg
      v-if="!disabled"
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      class="w-3 h-3 text-slate-400 ml-1"
      aria-hidden="true"
    >
      <polyline points="6 9 12 15 18 9" />
    </svg>
  </button>
</template>
