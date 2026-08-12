import { describe, expect, it } from 'vitest';
import { ref } from 'vue';

import { useModuleSelection } from './useModuleSelection';
import type { BillingPeriod, ModuleCatalog, PricingPlan } from '@/types/subscription-billing';

/**
 * `bundleBenchmark` powers the "would a bundle be cheaper?" nudge in the
 * subscribe summary. It used to read `cat.bundles['bundle_complete']` by
 * name, which is the SEKOLAH bundle.
 *
 * The catalog is tenant-scoped, so on a bimbel signup that key is absent
 * and the correct one — `bundle_tutoring` ("Paket Bimbel") — was never
 * looked at. Worse, when the catalog was fetched unscoped (the bug fixed
 * alongside this), `bundle_complete` WAS present and a bimbel customer
 * was pitched a bundle whose members are sekolah-only modules that route
 * no bimbel traffic. Reported 2026-08-12 from a live /subscribe/new
 * screenshot: summary read "Paket Lengkap (Sekolah)" for a Bimbel tenant.
 *
 * These pin the benchmark to whatever primary bundle the scoped catalog
 * actually carries, so neither tenant kind can be sold the other's.
 */

function makeCatalog(bundles: ModuleCatalog['bundles']): ModuleCatalog {
  return {
    optional: {},
    bundles,
    core_prefixes: [],
  } as unknown as ModuleCatalog;
}

function bundle(label: string, members: string[], perStudent = 6000, perStaff = 4000) {
  return {
    label,
    members,
    price_per_student: perStudent,
    price_per_staff: perStaff,
  } as unknown as ModuleCatalog['bundles'][string];
}

function mount(catalog: ModuleCatalog) {
  return useModuleSelection({
    catalog: ref(catalog) as never,
    plan: ref(null) as unknown as ReturnType<typeof ref<PricingPlan | null>>,
    studentCount: () => 35,
    staffCount: () => 5,
    period: ref('monthly') as unknown as ReturnType<typeof ref<BillingPeriod>>,
  });
}

describe('useModuleSelection · bundleBenchmark', () => {
  it('offers the bimbel bundle on a bimbel-scoped catalog', () => {
    const { bundleBenchmark } = mount(
      makeCatalog({
        bundle_tutoring: bundle('Paket Bimbel', ['tutoring', 'finance', 'communication']),
        bundle_ai: bundle('Paket AI', ['ai_rpp', 'ai_material_quiz']),
      }),
    );

    expect(bundleBenchmark.value?.key).toBe('bundle_tutoring');
    expect(bundleBenchmark.value?.label).toBe('Paket Bimbel');
  });

  it('offers the sekolah bundle on a sekolah-scoped catalog', () => {
    const { bundleBenchmark } = mount(
      makeCatalog({
        bundle_complete: bundle('Paket Lengkap (Sekolah)', ['grades', 'report_cards', 'attendance_class']),
        bundle_ai: bundle('Paket AI', ['ai_rpp']),
      }),
    );

    expect(bundleBenchmark.value?.key).toBe('bundle_complete');
  });

  it('never treats the AI add-on as the primary bundle', () => {
    // bundle_ai stacks on top of either primary; picking it would pitch
    // "swap to AI" as though it replaced the rest.
    const { bundleBenchmark } = mount(
      makeCatalog({
        bundle_ai: bundle('Paket AI', ['ai_rpp', 'ai_material_quiz', 'ai_recommendation']),
        bundle_tutoring: bundle('Paket Bimbel', ['tutoring']),
      }),
    );

    expect(bundleBenchmark.value?.key).toBe('bundle_tutoring');
  });

  it('returns null when the catalog carries no primary bundle', () => {
    const { bundleBenchmark } = mount(makeCatalog({ bundle_ai: bundle('Paket AI', ['ai_rpp']) }));

    expect(bundleBenchmark.value).toBeNull();
  });

  it('prices the benchmark from the live seat counts', () => {
    const { bundleBenchmark } = mount(
      makeCatalog({ bundle_tutoring: bundle('Paket Bimbel', ['tutoring'], 6000, 4000) }),
    );

    // 35 peserta × 6.000 + 5 tutor × 4.000
    expect(bundleBenchmark.value?.monthlyTotal).toBe(35 * 6000 + 5 * 4000);
  });
});
