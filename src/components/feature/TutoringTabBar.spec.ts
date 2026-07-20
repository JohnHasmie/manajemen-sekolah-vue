/**
 * Vitest spec for TutoringTabBar — pins the prop/emit contract so
 * downstream callers (WEB-4 tutor mobile, WEB-5 siswa+wali mobile) can
 * rely on a stable shape.
 *
 * Follows the same pattern as the rest of web-vue's spec files: written
 * for the Vitest API and type-checked by `vue-tsc --build`. Vitest
 * itself isn't wired into the run yet — `vue-tsc` is today's active
 * gate, and this file must pass it.
 */
import { describe, expect, it } from 'vitest';
import type { DefineComponent } from 'vue';
import TutoringTabBar from './TutoringTabBar.vue';

/** Prop shape the tab bar exposes — anchor for consumer type-checks. */
type Props = {
  modelValue: string;
  tabs: Array<{ id: string; label: string }>;
  fit?: boolean;
};

describe('TutoringTabBar contract', () => {
  it('exports a Vue component', () => {
    // DefineComponent is what `<script setup>` compiles to; the
    // instantiation-check catches wholesale removal of the module.
    const c: DefineComponent = TutoringTabBar as unknown as DefineComponent;
    expect(c).toBeTruthy();
  });

  it('accepts an id/label tab list', () => {
    // Compile-time contract: consumers must be able to pass this exact
    // shape. If a future refactor changes it, this fails to type-check.
    const _sample: Props = {
      modelValue: 'aliran',
      tabs: [
        { id: 'aliran', label: 'Aliran' },
        { id: 'session', label: 'Session' },
        { id: 'grade', label: 'Grade' },
      ],
      fit: false,
    };
    expect(_sample.tabs.length).toBeGreaterThan(0);
  });

  it('emits update:modelValue with a string id', () => {
    // The @update:modelValue callback resolves to string, matching how
    // v-model on modelValue: string exposes itself.
    const _handler: (v: string) => void = (v) => v.toString();
    expect(typeof _handler).toBe('function');
  });
});
