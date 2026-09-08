/**
 * Bridge between `<MoneyInput>` (model `number | null`) and a form field
 * declared as a plain, non-nullable `number`.
 *
 * `MoneyInput` emits `null` for an empty field on purpose — an amount
 * that is `min:1` server-side must not quietly become `0` when the user
 * clears it. Several of the forms it plugs into predate that and type
 * their field as `number` (`UpsertPayoutRatePayload.value`,
 * `DiscountCodePayload.min_amount_monthly`, …). Widening those payload
 * types would push `null` all the way into the service layer for no
 * benefit, so the nullability is absorbed here instead, in one tested
 * place rather than as a hand-rolled `computed` in every view:
 *
 *     const priceModel = useMoneyModel(
 *       () => form.price,
 *       (n) => { form.price = n; },
 *     );
 *
 * `0` reads back as an empty field, which is what these forms already
 * showed for an unset amount, and every call site's own validation
 * ("nominal harus lebih dari 0") still rejects the zero on submit.
 */
import { computed, type WritableComputedRef } from 'vue';

export function useMoneyModel(
  read: () => number | null | undefined,
  write: (value: number) => void,
): WritableComputedRef<number | null> {
  return computed<number | null>({
    get: () => {
      const current = read();
      return current ? current : null;
    },
    set: (next) => write(next ?? 0),
  });
}
