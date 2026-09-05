/**
 * The two components that shipped the crash, mounted against the REAL
 * locale file, asserting that no message compilation error is raised
 * while they render.
 *
 * Companion to `locale-messages-compile.spec.ts`, which sweeps every
 * message in both files. That sweep is the load-bearing guard. This
 * file exists because the sweep proves a fact about DATA, and the bug
 * users hit was about a COMPONENT: `AdminTutoring2StudentCreateEditSheet`
 * and `AdminTutoring2InviteTutorModal` both bind their guardian/tutor
 * e-mail placeholder through `t(...)` in the render path, so the
 * malformed message took the whole component down — "form hilang",
 * "tombol diklik tidak terjadi apa-apa".
 *
 * ── Why the assertion is NOT `expect(mount).not.toThrow()` ──
 *
 * Because that would pass on the broken code, which makes it worse than
 * no test. Verified, not assumed: with the unfixed `id.json` this mount
 * does not throw under Vitest, it logs three `Message compilation error`
 * lines and renders the raw text anyway.
 *
 * The throw is gated on `NODE_ENV`. `@intlify/core-base`'s
 * `getCompileContext` `console.error`s the failure when
 * `NODE_ENV !== 'production'` and only `throw`s otherwise — and Vitest
 * always sets `NODE_ENV=test`. So in a test run the observable symptom
 * of a message that will crash production is the console line, and that
 * is what is asserted here.
 *
 * ── Why the messages are read from disk, not stubbed ──
 *
 * Every other mounting spec in this repo passes `messages: { id: {} }`
 * or a small hand-written subtree, which makes `t()` echo the key back
 * and means the shipped string is never compiled at all. That is
 * precisely how this defect got past ~490 green tests. These mounts use
 * the real file.
 *
 * The repo has no `@intlify/unplugin-vue-i18n`, so messages are
 * JIT-compiled at render here exactly as they are in the browser — the
 * test and the production path run the same compiler on the same input.
 *
 * ── The student sheet needs a click ──
 *
 * Its guardian e-mail field lives on the "Wali" tab, behind a `v-else`.
 * On a bare mount that branch never renders and the placeholder is never
 * compiled, so the test would be green for the wrong reason. `activate`
 * below opens the tab first, which is also what the reporting user did
 * immediately before the form vanished.
 */
import { afterEach, describe, expect, it, vi } from 'vitest';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { mount, type VueWrapper } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import AdminTutoring2InviteTutorModal from '@/views/admin/tutoring2/AdminTutoring2InviteTutorModal.vue';
import AdminTutoring2StudentCreateEditSheet from '@/views/admin/tutoring2/AdminTutoring2StudentCreateEditSheet.vue';

vi.mock('@/services/tutoring2/tutors', () => ({
  TutoringTutorsService: { invite: vi.fn() },
}));
vi.mock('@/services/tutoring2/students', () => ({
  TutoringStudentsService: { create: vi.fn(), update: vi.fn() },
}));

type Messages = Record<string, unknown>;

/**
 * Container stubs must render their default slot. Auto-stubbing
 * (`Modal: true`) drops the slot content, the FormFields are never
 * created, `t()` is never called for the placeholder, and this file
 * would go quietly vacuous. The "actually renders the placeholder"
 * cases below are the tripwire for that.
 */
const STUBS = {
  Modal: { template: '<div><slot /><slot name="footer" /></div>' },
  FormSheet: { template: '<div><slot /><slot name="footer" /></div>' },
  Button: { template: '<button><slot /></button>' },
};

function realMessages(locale: string): Messages {
  const file = join(process.cwd(), 'src', 'locales', `${locale}.json`);
  return JSON.parse(readFileSync(file, 'utf8'));
}

/** Reads a dotted-ish path out of a parsed locale tree. */
function at(tree: Messages, path: readonly string[]): string {
  let node: unknown = tree;
  for (const seg of path) node = (node as Messages)[seg];
  return String(node);
}

/** Fresh copy of the real `id` tree with one leaf overwritten. */
function withOverride(path: readonly string[], value: string): Messages {
  const tree = realMessages('id');
  let node = tree;
  for (const seg of path.slice(0, -1)) node = node[seg] as Messages;
  node[path[path.length - 1]] = value;
  return tree;
}

/** Clicks the tab/button whose visible text matches `label`. */
async function clickByText(wrapper: VueWrapper, label: string): Promise<void> {
  const target = wrapper.findAll('button').find((b) => b.text().includes(label));
  if (!target) throw new Error(`no button labelled ${JSON.stringify(label)}`);
  await target.trigger('click');
}

interface MountResult {
  /** `Message compilation error: …` lines seen during render. */
  compileErrors: string[];
  html: string;
}

/**
 * Mount `component` with `messages` as the whole `id` locale, run
 * `activate` (which may render further branches), and report what the
 * compiler said. The console spy stays installed across the interaction
 * because that is when the student sheet compiles its placeholder.
 *
 * `messages` is a parameter rather than always the real file so the
 * mutation cases below can prove the detection actually fires.
 */
async function mountWith(
  component: unknown,
  messages: Messages,
  activate?: (wrapper: VueWrapper, messages: Messages) => Promise<void>,
): Promise<MountResult> {
  const compileErrors: string[] = [];
  const spy = vi.spyOn(console, 'error').mockImplementation((...args: unknown[]) => {
    const line = args.map(String).join(' ');
    if (line.includes('Message compilation error')) compileErrors.push(line);
  });
  try {
    const i18n = createI18n({
      legacy: false,
      locale: 'id',
      fallbackLocale: 'id',
      messages: { id: messages } as never,
      missingWarn: false,
      fallbackWarn: false,
    });
    const wrapper = mount(component as never, {
      global: { plugins: [i18n], stubs: STUBS },
    }) as VueWrapper;
    if (activate) await activate(wrapper, messages);
    return { compileErrors, html: wrapper.html() };
  } finally {
    spy.mockRestore();
  }
}

const CASES = [
  {
    name: 'AdminTutoring2InviteTutorModal',
    component: AdminTutoring2InviteTutorModal,
    path: ['tutoring2', 'admin', 'tutorInvite', 'emailPh'],
    /** The text a user reads. Identical before and after the fix. */
    visible: 'nama@sekolah.id',
    /** The unescaped form — what shipped, and what must be detected. */
    bare: 'nama@sekolah.id',
    activate: undefined,
  },
  {
    name: 'AdminTutoring2StudentCreateEditSheet',
    component: AdminTutoring2StudentCreateEditSheet,
    path: ['tutoring2', 'admin', 'students', 'form', 'waliEmailPlaceholder'],
    visible: 'wali@contoh.com',
    bare: 'wali@contoh.com',
    activate: async (wrapper: VueWrapper, messages: Messages) =>
      clickByText(wrapper, at(messages, ['tutoring2', 'admin', 'students', 'form', 'tabWali'])),
  },
] as const;

const EACH = CASES.map((c) => [c.name, c] as const);

afterEach(() => {
  vi.restoreAllMocks();
});

describe('components render the shipped locale messages', () => {
  it.each(EACH)('%s raises no message compilation error', async (_name, c) => {
    const { compileErrors } = await mountWith(c.component, realMessages('id'), c.activate);

    expect(
      compileErrors,
      compileErrors.length === 0
        ? ''
        : `${c.name} rendered a message vue-i18n cannot compile. In a ` +
            'production bundle this is not a console line, it is a throw ' +
            'inside render: the whole component disappears and the user sees ' +
            'an empty form or a dead button.\n\n' +
            compileErrors.join('\n\n') +
            "\n\nA bare '@' in a message value is the linked-message " +
            "operator. Write it as {'@'} — same visible text — and fix the " +
            'same key in en.json.',
    ).toEqual([]);
  });

  it.each(EACH)('%s actually renders the placeholder — the mount is not vacuous', async (_n, c) => {
    // If a stub stops rendering its default slot, or the Wali tab stops
    // opening, the FormField is never created, `t()` is never called,
    // and the test above passes for the wrong reason. This is the
    // tripwire for that.
    const { html } = await mountWith(c.component, realMessages('id'), c.activate);
    expect(html).toContain(c.visible);
  });

  it.each(EACH)('%s detection fires when the escape is removed', async (_n, c) => {
    // Puts the bare '@' back, only in this test's own copy of the
    // message tree, and asserts the detector notices. Without this a
    // future vue-i18n that stops logging the failure would leave the
    // cases above green on genuinely broken data.
    const { compileErrors } = await mountWith(
      c.component,
      withOverride(c.path, c.bare),
      c.activate,
    );

    expect(compileErrors.join('\n')).toContain('Invalid linked format');
  });
});
