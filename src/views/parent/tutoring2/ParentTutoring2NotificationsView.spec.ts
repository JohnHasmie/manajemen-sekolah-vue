/**
 * The wali notifications inbox must show real notifications.
 *
 * It shipped rendering a hardcoded list — "Nadia hadir sesi 16:00",
 * "SPP Jan jatuh tempo 25 Jan" — fabricated attendance for a fabricated
 * child, and a bill date a parent could act on. Mark-all-read was a
 * `notAvailable` toast.
 *
 * `NotificationService` had existed the whole time, and the legacy view
 * this screen replaced was already using it.
 */
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import { createPinia, setActivePinia } from 'pinia';
import NotificationsView from './ParentTutoring2NotificationsView.vue';
import { NotificationService } from '@/services/notification.service';
import type { AppNotification } from '@/types/notification';

vi.mock('@/services/notification.service', () => ({
  NotificationService: { list: vi.fn(), markAllRead: vi.fn(), markRead: vi.fn(), unreadCount: vi.fn() },
}));
vi.mock('@/composables/useAcademicYearWatcher', () => ({ useAcademicYearWatcher: () => {} }));
vi.mock('@/composables/useLocaleWatcher', () => ({ useLocaleWatcher: () => {} }));
vi.mock('@/composables/useToast', () => ({
  useToast: () => ({ success: vi.fn(), error: vi.fn(), info: vi.fn() }),
}));

function notif(o: Partial<AppNotification> = {}): AppNotification {
  return {
    id: 'n-1',
    title: 'Tagihan SPP terbit',
    body: '',
    category: 'billing' as AppNotification['category'],
    read_at: null,
    created_at: new Date(Date.now() - 30 * 60_000).toISOString(),
    ...o,
  };
}

async function mountView(items: AppNotification[] = [notif()]) {
  setActivePinia(createPinia());
  vi.mocked(NotificationService.list).mockResolvedValue({ items } as never);
  vi.mocked(NotificationService.markAllRead).mockResolvedValue(undefined as never);

  const w = mount(NotificationsView, {
    global: {
      plugins: [
        createI18n({
          legacy: false,
          locale: 'id',
          messages: { id: { tutoring2: { parent: { notifications: {
            minutesAgo: '{n} mnt lalu', hoursAgo: '{n} jam lalu', daysAgo: '{n} hari lalu',
            meta: '{count} belum dibaca',
          } } } } },
          missingWarn: false,
          fallbackWarn: false,
        }),
      ],
      stubs: {
        // Exposes `meta`, where the unread COUNT is rendered. A `true`
        // stub swallows it, and an assertion on the row dots below would
        // silently stop covering the count.
        BrandPageHeader: {
          props: ['role', 'kicker', 'title', 'meta'],
          template: '<div data-testid="hdr">{{ meta }}</div>',
        },
        NavIcon: true,
        Button: { template: '<button v-bind="$attrs"><slot /></button>' },
        AsyncView: {
          props: ['state'],
          template: '<div><slot v-if="state?.status === \'content\'" :data="state.data" /></div>',
        },
      },
    },
  });
  await flushPromises();
  return w;
}

describe('ParentTutoring2NotificationsView', () => {
  beforeEach(() => vi.clearAllMocks());

  it('renders the SERVER feed, not a hardcoded sample', async () => {
    const w = await mountView([notif({ title: 'Tagihan Agustus terbit' })]);

    expect(NotificationService.list).toHaveBeenCalledTimes(1);
    expect(w.text()).toContain('Tagihan Agustus terbit');
    // The fabricated rows that used to ship.
    expect(w.text()).not.toContain('Nadia hadir');
    expect(w.text()).not.toContain('SPP Jan');
  });

  it('derives the age from created_at instead of carrying it as data', async () => {
    // The samples hardcoded "2j" and "kemarin", which is why they never
    // went stale — they were never times.
    const w = await mountView([
      notif({ created_at: new Date(Date.now() - 30 * 60_000).toISOString() }),
    ]);
    expect(w.text()).toContain('30 mnt lalu');
  });

  it('marks all read against the API and re-reads the result', async () => {
    const w = await mountView();
    const buttons = w.findAll('button');
    await buttons[buttons.length - 1].trigger('click');
    await flushPromises();

    expect(NotificationService.markAllRead).toHaveBeenCalledTimes(1);
    // Re-read rather than flipping badges locally: a local flip would
    // show every badge cleared even if the request had failed.
    expect(NotificationService.list).toHaveBeenCalledTimes(2);
  });

  it('counts unread from read_at, which is what the API actually sends', async () => {
    const w = await mountView([
      notif({ id: 'a', read_at: null }),
      notif({ id: 'b', read_at: new Date().toISOString() }),
    ]);

    // The header count — one unread of two, not "2 notifications".
    expect(w.get('[data-testid="hdr"]').text()).toContain('1');
    expect(w.get('[data-testid="hdr"]').text()).not.toContain('2');
    // …and the per-row dot agrees with it.
    expect(w.findAll('.bg-brand-azure').length).toBe(1);
  });
});
