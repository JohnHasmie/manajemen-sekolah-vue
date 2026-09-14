/**
 * useBimbelChildren — the wali's bimbel children, loaded once per
 * session and shared by every screen that needs to know how many there
 * are.
 *
 * ── Why not `useChildPicker` ──
 *
 * `useChildPicker` is the SCHOOL parent surface's composable: it reads
 * `dashboard.stats.slices`, falls back to `ParentService.listChildren`
 * (the school-side `/student` endpoint), and owns an `activeChildId`
 * persisted to storage. None of the twelve views that use it are
 * `parent/tutoring2/*`.
 *
 * The bimbel surface does not need an active-child selection at all —
 * every per-child screen is addressed by `:studentId` in the URL, so the
 * route already IS the selection. What it needs is a COUNT, and the
 * count has to agree with the list `ParentTutoring2PickChildView`
 * renders, because that is where the "Ganti anak" link leads. Counting
 * from a different source would let the link appear for a wali whose
 * picker then shows one row. So this reads the same
 * `GET /tutoring-v2/enrollments` the picker reads, through the same
 * `deriveBimbelChildren`.
 *
 * ── Why module-level state ──
 *
 * The link sits in the header of eight screens; a wali moving between
 * them must not re-fetch their children each time. Same shape as
 * `useChildPicker`: the refs live at module scope, `ensureLoaded` is
 * idempotent, and concurrent callers share one in-flight request rather
 * than racing.
 *
 * ── Why a failure is silent ──
 *
 * `children` stays empty when the request fails, so `hasMultipleChildren`
 * is false and the link does not render. That is the correct direction
 * to fail: we show the switcher only when we have POSITIVE evidence of
 * more than one child. A toast here would also be wrong — nothing the
 * wali did caused it, and the page they are reading is unaffected.
 */
import { computed, ref } from 'vue';
import {
  deriveBimbelChildren,
  type BimbelChildRow,
} from '@/lib/bimbel-parent-children';
import { TutoringBimbelService } from '@/services/tutoring-bimbel.service';

/**
 * One page of 100 enrollments. A wali's own children are a handful of
 * rows; the picker uses the same bound.
 */
const ENROLLMENT_PAGE_SIZE = 100;

const children = ref<BimbelChildRow[]>([]);
const loaded = ref(false);
/** Shared so eight headers mounting at once make ONE request. */
let inFlight: Promise<void> | null = null;

async function fetchChildren(): Promise<void> {
  try {
    const { items } = await TutoringBimbelService.listEnrollments({
      per_page: ENROLLMENT_PAGE_SIZE,
    });
    children.value = deriveBimbelChildren(items);
    loaded.value = true;
  } catch {
    // Leave `loaded` false so a later screen can retry, and `children`
    // empty so nothing renders on a guess. See the header block.
    children.value = [];
  } finally {
    inFlight = null;
  }
}

export function useBimbelChildren() {
  /** Load once. Subsequent calls resolve immediately. */
  async function ensureLoaded(): Promise<void> {
    if (loaded.value) return;
    inFlight ??= fetchChildren();
    await inFlight;
  }

  /**
   * Drop the cached list without re-reading it.
   *
   * Module-level state outlives a component, so it also outlives a
   * SESSION: without this, signing out and back in as a different wali
   * would leave the previous parent's children in memory until a hard
   * reload. Also how the suite puts the module back in its pre-load
   * state between cases.
   */
  function invalidate(): void {
    loaded.value = false;
    inFlight = null;
    children.value = [];
  }

  /** Re-read after the child set may have changed (a new enrollment). */
  async function refresh(): Promise<void> {
    invalidate();
    await ensureLoaded();
  }

  return {
    children,
    /**
     * The gate for the "Ganti anak" affordance. Strictly greater than
     * one: a wali with a single child would be offered a control that
     * opens a one-item list, which is clutter rather than a way through.
     */
    hasMultipleChildren: computed(() => children.value.length > 1),
    ensureLoaded,
    invalidate,
    refresh,
  };
}
