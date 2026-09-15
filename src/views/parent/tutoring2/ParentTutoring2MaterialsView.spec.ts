/**
 * Contract spec for ParentTutoring2MaterialsView — the wali "Bahan Ajar"
 * screen.
 *
 * ── What is deliberately NOT stubbed, and why ──
 *
 * `AsyncView`, `EmptyState` and `TutoringMaterialRow` all mount for real.
 *
 * The sibling announcement spec in this folder says plainly why:
 * stubbing `BottomSheetFooter` on two screens "is precisely why the dead
 * button was never seen". The same trap is live here twice over — an
 * `AsyncView` stub that renders its default slot unconditionally makes
 * the empty-state assertion vacuous (the state it is meant to prove is
 * the one the stub skips), and a `TutoringMaterialRow` stub would let a
 * wrong `role` prop through while still reporting a rendered row.
 *
 * ── Why the REAL locale file ──
 *
 * The messages come from `src/locales/id.json`, not a hand-written
 * fixture. A fixture proves the template referenced *a* key; the real
 * file proves it referenced a key that EXISTS. A typo'd `t()` path
 * renders as the path itself on screen, and a bespoke fixture cannot
 * tell the difference.
 */
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import ParentTutoring2MaterialsView from './ParentTutoring2MaterialsView.vue';
import TutoringMaterialRow from '@/components/tutoring/TutoringMaterialRow.vue';
import { MaterialsService } from '@/services/tutoring2/materials';
import id from '@/locales/id.json';

vi.mock('@/services/tutoring2/materials', () => ({
  MaterialsService: { list: vi.fn() },
}));

const toastError = vi.fn();
const toastInfo = vi.fn();
vi.mock('@/composables/useToast', () => ({
  useToast: () => ({ error: toastError, info: toastInfo, success: vi.fn() }),
}));

// `useDataRefresh` already registers these two watchers itself; the
// sibling parent specs neutralise them the same way.
vi.mock('@/composables/useAcademicYearWatcher', () => ({
  useAcademicYearWatcher: () => {},
}));
vi.mock('@/composables/useLocaleWatcher', () => ({
  useLocaleWatcher: () => {},
}));

/** An uploaded file pinned to a learning group. */
const GROUP_MATERIAL = {
  id: 'mat-1',
  learning_group_id: 'gr-1',
  learning_group_name: 'UTBK Pagi A',
  program_id: null,
  program_name: null,
  title: 'Ringkasan Trigonometri',
  description: null,
  file_url: 'https://bucket.example.com/signed/trig.pdf',
  file_name: 'trig.pdf',
  file_size: 2_400_000,
  file_mime: 'application/pdf',
  kind: 'PDF',
  uploaded_by_user_id: 'u-1',
  uploaded_by_name: 'Tutor Satu',
  published_at: '2026-09-10T09:00:00+07:00',
  is_published: true,
};

/**
 * A PROGRAMME-pinned material: `learning_group_id` is null. This is the
 * category a `:studentId`-scoped screen would have dropped, so it earns
 * a place in the default fixture rather than a special case.
 */
const PROGRAM_MATERIAL = {
  ...GROUP_MATERIAL,
  id: 'mat-2',
  learning_group_id: null,
  learning_group_name: null,
  program_id: 'pr-1',
  program_name: 'Intensif SNBT',
  title: 'Jadwal Try Out',
  file_url: 'https://drive.example.com/file/abc',
  file_name: null,
  file_size: null,
  file_mime: null,
  kind: 'LINK',
  published_at: '2026-09-09T09:00:00+07:00',
};

function makeI18n() {
  return createI18n({
    legacy: false,
    locale: 'id',
    fallbackLocale: 'id',
    // The real bundle — see the file docblock.
    messages: { id },
    missingWarn: false,
    fallbackWarn: false,
  });
}

async function mountView() {
  setActivePinia(createPinia());
  const w = mount(ParentTutoring2MaterialsView, {
    global: {
      plugins: [makeI18n()],
      stubs: {
        // Presentational chrome only. AsyncView, EmptyState and
        // TutoringMaterialRow are intentionally absent from this list.
        BrandPageHeader: true,
        NavIcon: true,
      },
    },
  });
  await flushPromises();
  return w;
}

describe('ParentTutoring2MaterialsView', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(MaterialsService.list).mockResolvedValue({
      items: [GROUP_MATERIAL, PROGRAM_MATERIAL],
      pagination: undefined,
    });
  });

  describe('loading the list', () => {
    it('calls the materials endpoint', async () => {
      await mountView();
      expect(MaterialsService.list).toHaveBeenCalledTimes(1);
    });

    /**
     * The flat-screen decision, pinned as behaviour rather than as a
     * comment. The server scopes the list to this wali's children
     * already; sending a `learning_group_id` on top would narrow it to
     * ONE group and silently hide every programme-pinned row.
     */
    it('sends no group or student filter, so programme-pinned rows survive', async () => {
      await mountView();
      const params = vi.mocked(MaterialsService.list).mock.calls[0][0];
      expect(params).not.toHaveProperty('learning_group_id');
      expect(params).not.toHaveProperty('student_id');
    });

    it('renders one row per material', async () => {
      const w = await mountView();
      expect(w.findAllComponents(TutoringMaterialRow)).toHaveLength(2);
    });

    it('renders the material titles', async () => {
      const w = await mountView();
      expect(w.text()).toContain('Ringkasan Trigonometri');
      expect(w.text()).toContain('Jadwal Try Out');
    });
  });

  describe('the row role', () => {
    /**
     * Asserted as a PROP, not as rendered output, because the cost of
     * getting it wrong is a control that should not exist: the
     * "Terkirim ke wali" / "Belum dikirim" pill is gated on
     * `role === 'tutor'`. Every row a wali can see was published by
     * definition — the index filters unsent rows out for them — so the
     * badge would read a constant "Terkirim" on every row.
     */
    it('passes role="parent" to every row', async () => {
      const w = await mountView();
      const rows = w.findAllComponents(TutoringMaterialRow);
      expect(rows).toHaveLength(2);
      for (const row of rows) {
        expect(row.props('role')).toBe('parent');
      }
    });

    it('offers no tutor-only write controls', async () => {
      const w = await mountView();
      for (const row of w.findAllComponents(TutoringMaterialRow)) {
        expect(row.props('canDelete')).toBe(false);
        expect(row.props('canEdit')).toBe(false);
      }
    });

    /**
     * The consequence of the above, proven through the REAL row rather
     * than through its props: the tutor-only share pill must not render.
     * `TutoringMaterialRow` tags it `data-testid="material-share-state"`.
     */
    it('does not render the tutor-only sent/not-sent badge', async () => {
      const w = await mountView();
      expect(w.find('[data-testid="material-share-state"]').exists()).toBe(false);
    });
  });

  describe('empty state', () => {
    /**
     * The common case at launch, not an edge case: until the tutor
     * "Kirim ke wali" action shipped, nothing had ever been sent, so the
     * honest answer for most wali is an empty list. A blank screen would
     * read as a broken one.
     */
    it('renders an explicit message when nothing has been sent', async () => {
      vi.mocked(MaterialsService.list).mockResolvedValue({
        items: [],
        pagination: undefined,
      });
      const w = await mountView();

      expect(w.findAllComponents(TutoringMaterialRow)).toHaveLength(0);
      expect(w.text()).toContain(id.tutoring2.parent.materials.emptyTitle);
      expect(w.text()).toContain(id.tutoring2.parent.materials.emptyDesc);
    });

    /** Guards the guard: the copy above must not be an empty string. */
    it('has non-empty empty-state copy', () => {
      expect(id.tutoring2.parent.materials.emptyTitle.trim().length).toBeGreaterThan(0);
      expect(id.tutoring2.parent.materials.emptyDesc.trim().length).toBeGreaterThan(0);
    });
  });

  describe('grouping', () => {
    it('labels each section when materials span more than one source', async () => {
      const w = await mountView();
      expect(w.findAll('[data-testid="material-bucket"]')).toHaveLength(2);
      expect(w.text()).toContain('UTBK Pagi A');
      expect(w.text()).toContain('Intensif SNBT');
    });

    /** One section needs no header — the page title already says it. */
    it('renders a single unlabelled section when they share one source', async () => {
      vi.mocked(MaterialsService.list).mockResolvedValue({
        items: [GROUP_MATERIAL, { ...GROUP_MATERIAL, id: 'mat-3', title: 'Latihan Soal' }],
        pagination: undefined,
      });
      const w = await mountView();
      expect(w.findAll('[data-testid="material-bucket"]')).toHaveLength(1);
      expect(w.findAllComponents(TutoringMaterialRow)).toHaveLength(2);
    });
  });

  describe('opening a material', () => {
    /**
     * A blocked popup must be reported. Telling a wali the file opened
     * when no tab exists sends them hunting for it — the silent dead end
     * this screen was written to avoid.
     */
    it('warns when the browser blocks the new tab', async () => {
      const open = vi.spyOn(window, 'open').mockReturnValue(null);
      const w = await mountView();

      w.findAllComponents(TutoringMaterialRow)[0].vm.$emit('open', GROUP_MATERIAL);
      await flushPromises();

      expect(open).toHaveBeenCalledWith(
        GROUP_MATERIAL.file_url,
        '_blank',
        'noopener',
      );
      expect(toastError).toHaveBeenCalledWith(
        id.tutoring2.parent.materials.openBlocked,
      );
      open.mockRestore();
    });

    it('stays silent when the tab actually opens', async () => {
      const open = vi
        .spyOn(window, 'open')
        .mockReturnValue({} as unknown as Window);
      const w = await mountView();

      w.findAllComponents(TutoringMaterialRow)[0].vm.$emit('open', GROUP_MATERIAL);
      await flushPromises();

      expect(toastError).not.toHaveBeenCalled();
      open.mockRestore();
    });

    /**
     * An externally-hosted link has nothing to save, so "Unduh" opens it
     * rather than attempting a blob fetch that cannot succeed.
     * `PROGRAM_MATERIAL` is one: kind LINK, and the null file_* triple.
     */
    it('opens an external link on download instead of fetching it', async () => {
      const open = vi
        .spyOn(window, 'open')
        .mockReturnValue({} as unknown as Window);
      const fetchSpy = vi.spyOn(globalThis, 'fetch');
      const w = await mountView();

      w.findAllComponents(TutoringMaterialRow)[1].vm.$emit(
        'download',
        PROGRAM_MATERIAL,
      );
      await flushPromises();

      expect(open).toHaveBeenCalledWith(
        PROGRAM_MATERIAL.file_url,
        '_blank',
        'noopener',
      );
      expect(fetchSpy).not.toHaveBeenCalled();
      open.mockRestore();
      fetchSpy.mockRestore();
    });
  });
});
