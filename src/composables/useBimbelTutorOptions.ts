/**
 * useBimbelTutorOptions — the ONE tutor option list the admin
 * learning-group forms pick from.
 *
 * Two surfaces now assign a tutor to a group — the create sheet
 * (`POST /tutoring-v2/learning-groups`) and the group detail's
 * "Ubah tutor" sheet (`PUT …/{id}`) — and both need the same three
 * things: the tenant's ACTIVE tutors, an id→name option list, and an
 * honest answer when that list could not be fetched. Keeping the
 * fetch here means the two forms cannot offer different tutors.
 *
 * SOURCE. `TutoringTutorsService.list`, the same wrapper the Tutor
 * filter chip on AdminTutoring2GroupsView already reads. Nothing new is
 * invented; `GET /tutoring-v2/tutors` is the admin-side tutor list.
 *
 * ACTIVE ONLY. `active: true` narrows to tutors whose tenant pivot AND
 * TEACHER role row are both live. Handing a new group to a deactivated
 * tutor is not a thing an admin means to do, and the backend would not
 * stop them: `tutor_id` is validated as `uuid` with no `exists:` rule
 * behind it. A form that already holds an INACTIVE tutor (the group was
 * assigned before the tutor was deactivated) must still render that
 * choice — see the caller, which prepends it rather than silently
 * showing "no tutor" for a group that has one.
 *
 * FAILURE IS A STATE, NOT A BLANK. `tutoring.tutor.view` is a separate
 * key from the `tutoring.group.manage` that gates the write, so an
 * admin can hold the write and be refused the list. `failed` lets the
 * caller say that in the field instead of rendering an empty dropdown,
 * which reads as "this tenant has no tutors".
 */
import { computed, ref } from 'vue';
import { TutoringTutorsService } from '@/services/tutoring2/tutors';
import type { Tutor } from '@/types/tutoring2/tutor';

/**
 * Read off `TutorController::index`, which does
 * `paginate(min((int) $request->input('per_page', 20), 100))` — asking
 * for more is silently capped, so asking for 100 is the honest request.
 * `truncated` below reports when even that was not the whole list.
 */
export const TUTOR_OPTIONS_PAGE_SIZE = 100;

/** Structurally compatible with `FormFieldOption` from FormField.vue. */
export interface TutorOption {
  value: string;
  label: string;
}

export function useBimbelTutorOptions() {
  const tutors = ref<Tutor[]>([]);
  const loading = ref(false);
  const failed = ref(false);
  const truncated = ref(false);

  const options = computed<TutorOption[]>(() =>
    tutors.value.map((tu) => ({ value: tu.id, label: tu.name })),
  );

  async function load(): Promise<void> {
    loading.value = true;
    failed.value = false;
    try {
      const { items, pagination } = await TutoringTutorsService.list({
        per_page: TUTOR_OPTIONS_PAGE_SIZE,
        active: true,
      });
      tutors.value = items;
      // `total_items` is absent when the envelope carried no `meta`;
      // falling back to the row count then means "nothing was cut",
      // which is the only claim that data supports.
      truncated.value = (pagination?.total_items ?? items.length) > items.length;
    } catch {
      failed.value = true;
      tutors.value = [];
      truncated.value = false;
    } finally {
      loading.value = false;
    }
  }

  return { tutors, options, loading, failed, truncated, load };
}
