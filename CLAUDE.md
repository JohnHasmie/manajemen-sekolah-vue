# KamilEdu Web — Vue Working Guide

Contract for how Claude adds, edits, or refactors code in this Vue port.
Mirrors `../CLAUDE.md` (the Flutter working guide) — same rules, different
syntax.

Companion docs:
- `README.md` — tech stack, getting started, directory layout.
- `../CLAUDE.md` — the Flutter source-of-truth conventions.
- `TERMINOLOGY.md` — canonical Indonesian wording (Kehadiran vs Absensi Sesi, siswa/peserta, guru/tutor).

## The one rule

**Satu implementasi, tiga role.** Every admin / teacher / parent screen
reaches for the same shared components, modals, filters, and dialogs. If
you're about to build a local dialog, filter, or form, stop and pick the
shared component from `src/components/` first.

## Directory layout

```
src/
├── main.ts                   # bootstrap
├── App.vue                   # rehydrates auth, mounts RouterView
├── router/                   # role-aware routes + guards
├── stores/                   # Pinia stores (auth.ts is the canonical example)
├── services/                 # API-call wrappers, one file per backend domain
├── lib/                      # http.ts (axios), storage.ts
├── composables/              # useRoleColor, mapStatus, etc.
├── types/                    # api.ts (envelope), auth.ts (User/Role)
├── components/
│   ├── ui/                   # Modal, Toast, Button — generic primitives
│   ├── data/                 # AsyncView, EmptyState, ErrorScreen, Pagination
│   ├── forms/                # AppForm, AppField, AppSelect, AppDatePicker
│   └── feature/              # Cross-feature shared bits (SchoolPill, RoleToggle, …)
└── views/
    ├── auth/                 # LoginView + step components
    ├── admin/
    ├── teacher/
    ├── parent/
    └── staff/
```

When adding a new feature, mirror this layout. Shared components live
under `src/components/`; only put a component in a feature folder if it
is genuinely local.

## Shared components — reach for these first

| You want to…                  | Use                       | Don't                          |
| ----------------------------- | ------------------------- | ------------------------------ |
| Open a modal / sheet          | `<Modal>` from `ui/`      | Hand-roll fixed-position div   |
| Show a snackbar               | `<Toast>` from `ui/`      | `alert()` or custom div        |
| Render an async list          | `<AsyncView>` (pending)   | `if (loading) … else …` blocks |
| Confirm a destructive action  | `<ConfirmationDialog>` (pending) | `window.confirm()`       |
| Show empty / error states     | `<EmptyState>` / `<ErrorScreen>` (pending) | inline `<p>Empty</p>` |
| Apply role color              | `useRoleColor(role)`      | Hard-coded hex                 |
| Format Indonesian Rupiah      | `formatRupiah()` (pending) | `toLocaleString()` ad-hoc     |
| Open a date picker            | `<AppDatePicker>` (pending) | Native `<input type="date">` |

## Don't-dos (fast checklist)

- Don't hard-code colors — go through `useRoleColor()`, the `bg-status-*`
  tokens, or the slate scale.
- Don't hard-code paddings — use Tailwind's `xs/sm/md/lg/xl` spacing.
- Don't call `axios` directly — import `api` / `aiApi` from `@/lib/http`
  so token + school-id headers are applied.
- Don't store auth state outside the Pinia auth store. The store is the
  single source of truth.
- Don't use `localStorage.setItem` directly — go through `@/lib/storage`
  so SSR-readiness stays intact.
- Don't write user-visible strings in English unless `en.json` is being
  populated. Bahasa Indonesia is the default everywhere.
- Don't map `Pending → Pending` in the UI. Always go through `mapStatus`.

## Strings, colors, navigation

- **Bahasa Indonesia** for every user-visible string. Error messages too.
- **Status vocab**: backend uses `Pending / Approved / Rejected`; the UI
  shows `Menunggu / Disetujui / Ditolak`. Always map at the boundary
  (see `mapStatus()` in `@/composables/useRoleColor.ts`).
- **Role colors**: `useRoleColor(role)` — admin=navy, teacher=teal,
  parent=violet, staff=amber. No hex literals in `<template>` blocks.
- **Navigation**: `useRouter().push(...)` / `router.replace(...)`. Do
  NOT use `window.location.assign` except inside `http.ts`'s 401 handler.

## Async data pattern (to be added)

Wrap every list-screen body in `<AsyncView>` (when implemented):

```vue
<AsyncView :state="state" :on-retry="reload" empty-title="Belum ada data">
  <MyList :items="state.data" />
</AsyncView>
```

State shape: `{ status: 'loading' | 'error' | 'empty' | 'content', data?, error? }`.

## Adding a new feature screen (checklist)

Given a new screen `views/<role>/X.vue`:

1. View component is thin (<150 lines). Heavy logic moves to a composable
   `composables/useX.ts` or a Pinia store `stores/x.ts`.
2. API calls go through `services/x.service.ts`, never directly inside
   the view.
3. List-screen body uses `<AsyncView>`.
4. Edit / create flows use `<Modal>` with a `<BottomSheetFooter>` slot.
5. Destructive actions go through `<ConfirmationDialog>`.
6. Empty / error states use `<EmptyState>` / `<ErrorScreen>`.
7. Run `npm run type-check`, `npm run lint`, `npm run format` before
   committing.

## File management inside a sandboxed session

Same caveats as the Flutter repo's `CLAUDE.md`: `rm` may fail with
`Operation not permitted` inside the bind-mount. Use `Write` to rewrite
in place when a real delete would be cleaner — call it out in the commit
message so a follow-up can clean up on a dev machine.

## Git hygiene

- **Conventional commits**:
  - `feat(auth): scaffold Vue login flow with OTP + pickers`
  - `refactor(http): centralize 401 handler in axios interceptor`
  - `fix(login): correct OTP auto-advance on paste`
- **Co-author trailer on every Claude commit**:
  `Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>`.
- **Identity via flags**, not `git config`:
  `git -c user.email=yahyahasymi@gmail.com -c user.name="Yahya Hasymi" commit …`.

## Verification before committing

1. `npm run type-check` — must pass with zero errors.
2. `npm run lint` — should pass with zero errors, warnings OK during dev.
3. `npm run build` — production build must succeed.
4. Manual smoke test if the change is visible:
   `npm run dev` → exercise the page in the browser.

## Mapping back to Flutter

When in doubt about a behaviour, the Flutter source is the spec. Common
landmarks:

| Topic               | Flutter file                                              |
| ------------------- | --------------------------------------------------------- |
| Login UI            | `lib/features/auth/presentation/screens/login_screen.dart` |
| Auth state machine  | `lib/features/auth/presentation/controllers/auth_controller.dart` |
| Auth service        | `lib/features/auth/data/auth_service.dart`                |
| Color tokens        | `lib/core/utils/color_utils.dart`                         |
| Spacing tokens      | `lib/core/constants/app_spacing.dart`                     |
| API endpoints       | `lib/core/constants/api_endpoints.dart`                   |
| Dio client          | `lib/core/network/dio_client.dart`                        |
| Shared widget rules | `lib/core/widgets/README.md`                              |
