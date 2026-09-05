/**
 * Contract spec for the shared `extractError`.
 *
 * ── Why this file exists ───────────────────────────────────────────
 *
 * `extractError` was copy-pasted, byte for byte, into four tutoring2
 * admin views. Three of them (PayoutRates, PayoutRequests,
 * PayoutSettings) are MERGED and in daily use, and between them they
 * hold nine of the ten call sites. Collapsing four copies into one
 * shared implementation is only safe if the shared one still answers
 * identically for every status those screens already handle.
 *
 * So the centrepiece here is a DIFFERENTIAL test: `legacyExtractError`
 * below is the exact pre-refactor implementation, and the matrix
 * asserts new === old on every status except the two the fix
 * deliberately changes. That is a stronger proof than re-testing the
 * views, because it covers statuses those views' specs never exercise
 * (they currently have no error-path coverage of this helper at all).
 *
 * ── Anti-vacuity notes ─────────────────────────────────────────────
 *
 * a. Every fixture is AXIOS-SHAPED — `{ message, response: { status,
 *    data } }` — because that is what the http interceptor re-rejects
 *    (src/lib/http.ts returns `Promise.reject(error)` untouched). A
 *    fixture shaped like `new Error(text)` would exercise nothing.
 *
 * b. The 404 assertions check for the ABSENCE of the class path, not
 *    merely that some other string came back. Asserting "returns null"
 *    alone would still pass if a future edit returned a different
 *    leaking field.
 *
 * c. The differential matrix asserts equality with the legacy function
 *    rather than with hardcoded strings, so it cannot drift out of
 *    sync with what the old code really did.
 */
// @ts-nocheck — vitest types not installed yet
import { describe, expect, it } from 'vitest';
import { extractError } from './api-error';

/**
 * The pre-refactor implementation, frozen. This is the function that
 * shipped in all four views (byte-identical in each). Do not "improve"
 * it — its only job is to be the baseline the new one is compared to.
 */
function legacyExtractError(e: unknown): string | null {
  const err = e as {
    response?: { data?: { message?: string; errors?: Record<string, string[]> } };
  };
  const msg = err?.response?.data?.message;
  if (msg) return msg;
  const errors = err?.response?.data?.errors;
  if (errors) {
    const first = Object.values(errors)[0];
    if (Array.isArray(first) && first.length > 0) return first[0];
  }
  return null;
}

/** An axios rejection carrying an HTTP response. */
function axiosResponse(status: number, data: unknown) {
  return {
    message: `Request failed with status code ${status}`,
    response: { status, data },
  };
}

/** What Laravel returns for a missing/soft-deleted/cross-tenant row. */
const LARAVEL_404 = {
  message:
    'No query results for model [App\\Modules\\Tutoring\\Models\\Lead] 01a0f3c2-8e5b-4a11-9d77-2f6c0b1e4a55',
};

describe('extractError', () => {
  describe('statuses whose body is author-written (unchanged behaviour)', () => {
    it('returns the 422 top-level message', () => {
      const text = 'Tidak dapat pindah dari new ke converted.';
      expect(
        extractError(
          axiosResponse(422, { message: text, errors: { status: [text] } }),
        ),
      ).toBe(text);
    });

    it('falls back to the first entry of the 422 bag when there is no message', () => {
      const text = 'Kelompok penuh (8 / 8).';
      expect(
        extractError(axiosResponse(422, { errors: { learning_group_id: [text] } })),
      ).toBe(text);
    });

    // 402 is why a "trust the body only on 422" rule was rejected:
    // EnsureModuleEntitled wraps the whole tutoring-v2 route group and
    // this is the single most actionable message the API produces.
    it('keeps the 402 module-not-entitled upgrade message', () => {
      const text =
        'Modul "Bimbel" belum aktif untuk sekolah Anda. Aktifkan untuk menggunakan fitur ini.';
      expect(
        extractError(
          axiosResponse(402, { error: 'module_not_entitled', message: text }),
        ),
      ).toBe(text);
    });

    // These four back the MERGED payout screens. A 422-only rule would
    // have replaced every one of them with "Aksi gagal."
    it('keeps the Indonesian 409 payout-request messages', () => {
      const text = 'Hanya pengajuan berstatus pending yang dapat disetujui.';
      expect(
        extractError(axiosResponse(409, { message: text, current_status: 'approved' })),
      ).toBe(text);
    });

    it('keeps an Indonesian abort(403) message', () => {
      const text = 'Anda tidak memiliki akses ke pengajuan honor.';
      expect(extractError(axiosResponse(403, { message: text }))).toBe(text);
    });

    it('keeps the Indonesian 400 tenant message', () => {
      const text = 'Tenant tidak terdefinisi.';
      expect(extractError(axiosResponse(400, { message: text }))).toBe(text);
    });
  });

  describe('statuses whose body describes internals (the fix)', () => {
    it('refuses the 404 ModelNotFoundException text', () => {
      const got = extractError(axiosResponse(404, LARAVEL_404));

      expect(got).toBeNull();
      // The point of the fix: the class path must not escape, by any
      // route. Asserting null alone would not catch a future edit that
      // returned some other leaking field.
      expect(got ?? '').not.toContain('App\\');
      expect(got ?? '').not.toContain('\\Models\\');
    });

    it('refuses the prod 500 body', () => {
      expect(extractError(axiosResponse(500, { message: 'Server Error' }))).toBeNull();
    });

    // APP_DEBUG=true (local, CI, some staging builds) puts the raw
    // exception text in `message`. This is the case a literal
    // blocklist of framework strings could never cover, and it is why
    // the rule keys on status instead.
    it('refuses a debug-mode 500 carrying raw exception text', () => {
      const got = extractError(
        axiosResponse(500, {
          message:
            'SQLSTATE[42S02]: Base table or view not found: 1146 Table \'edu_core.bimbel_leads\' doesn\'t exist',
          exception: 'Illuminate\\Database\\QueryException',
          file: '/var/www/html/vendor/laravel/framework/src/Illuminate/Database/Connection.php',
        }),
      );

      expect(got).toBeNull();
      expect(got ?? '').not.toContain('SQLSTATE');
    });

    it('refuses a 503 body', () => {
      expect(extractError(axiosResponse(503, { message: 'Service Unavailable' }))).toBeNull();
    });
  });

  describe('rejections with no HTTP response (the transport rung)', () => {
    // These must return null so the CALLER's next rung shows axios's
    // own message. axios builds network/timeout errors with no
    // `response` property at all (axios/lib/adapters/xhr.js passes
    // only four constructor args), so this branch is exactly the
    // offline/timeout case and nothing else.
    it('returns null for an offline rejection', () => {
      expect(extractError({ message: 'Network Error', code: 'ERR_NETWORK' })).toBeNull();
    });

    it('returns null for a timeout rejection', () => {
      expect(
        extractError({ message: 'timeout of 30000ms exceeded', code: 'ECONNABORTED' }),
      ).toBeNull();
    });

    it('returns null for a plain Error', () => {
      expect(extractError(new Error('boom'))).toBeNull();
    });

    it('returns null for null/undefined', () => {
      expect(extractError(null)).toBeNull();
      expect(extractError(undefined)).toBeNull();
    });
  });

  describe('defensive shapes', () => {
    it('survives a non-object body (nginx HTML error page)', () => {
      expect(extractError(axiosResponse(502, '<html>502 Bad Gateway</html>'))).toBeNull();
      expect(extractError(axiosResponse(422, '<html>oops</html>'))).toBeNull();
    });

    it('ignores an empty errors bag', () => {
      expect(extractError(axiosResponse(422, { errors: {} }))).toBeNull();
      expect(extractError(axiosResponse(422, { errors: { f: [] } }))).toBeNull();
    });

    // An unrecognised or missing status is TRUSTED — the rule only
    // subtracts from the old behaviour, it never invents new refusals.
    it('trusts a body whose status is missing', () => {
      const text = 'Sesuatu yang spesifik.';
      expect(extractError({ response: { data: { message: text } } })).toBe(text);
    });

    it('trusts an unrecognised status', () => {
      const text = 'Terlalu banyak percobaan.';
      expect(extractError(axiosResponse(429, { message: text }))).toBe(text);
    });
  });

  // ─────────────────────────────────────────────────────────────────
  // THE REGRESSION PROOF for the three merged payout views.
  //
  // Nine of the ten call sites live in AdminTutoring2PayoutRatesView,
  // AdminTutoring2PayoutRequestsView and AdminTutoring2PayoutSettings
  // View, all merged. Each of them reads `extractError(e) ?? <its own
  // fallback>` and none of them changed except its import line, so if
  // the shared helper answers identically to the copy they used to
  // carry, their behaviour is identical too.
  // ─────────────────────────────────────────────────────────────────
  describe('differential vs the pre-refactor implementation', () => {
    const bodies = [
      { message: 'Pesan dari server.' },
      { errors: { field: ['Pesan dari bag.'] } },
      { message: 'Keduanya.', errors: { field: ['Bag.'] } },
      { error: 'module_not_entitled', message: 'Modul belum aktif.' },
      {},
      '<html>error</html>',
    ];

    // Every status these ten call sites can actually receive, minus
    // the two the fix deliberately changes.
    const unchangedStatuses = [400, 401, 402, 403, 409, 419, 422, 429];

    it.each(unchangedStatuses)(
      'answers exactly as the old implementation on %i',
      (status) => {
        for (const body of bodies) {
          const e = axiosResponse(status, body);
          expect(extractError(e)).toBe(legacyExtractError(e));
        }
      },
    );

    it('answers as the old implementation for rejections with no response', () => {
      for (const e of [
        new Error('Network Error'),
        { message: 'timeout of 30000ms exceeded' },
        null,
        undefined,
      ]) {
        expect(extractError(e)).toBe(legacyExtractError(e));
      }
    });

    // The ONLY intended divergence, stated as an assertion so it can
    // never widen unnoticed: on 404 and 5xx the old code leaked and
    // the new code refuses.
    it.each([404, 500, 502, 503])(
      'deliberately diverges from the old implementation on %i',
      (status) => {
        const e = axiosResponse(status, LARAVEL_404);

        expect(legacyExtractError(e)).toContain('App\\Modules');
        expect(extractError(e)).toBeNull();
      },
    );
  });
});
