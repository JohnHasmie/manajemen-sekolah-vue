import { request, type APIRequestContext } from '@playwright/test';
import type { Session } from './auth';

/**
 * A raw API client that mirrors what the app's axios interceptor sends.
 *
 * Fidelity is the whole point. `EnsureSchoolContext` rejects a request
 * with no tenant header, so a probe that forgets `X-School-ID` gets
 * denied for the wrong reason and every "expect 403" row passes while
 * proving nothing. The header set below is copied from
 * `src/lib/http.ts` — keep them in step.
 *
 * `X-Active-Role` is the subtle one: the backend's AbilityResolver
 * narrows abilities to that single role, and OMITTING it falls back to
 * the union of every role the user holds. Sending it deliberately (and
 * deliberately omitting it, in the widening test) is what makes the
 * scoping testable at all.
 */

const API_BASE = process.env.E2E_API_URL ?? 'http://localhost:8001/api';

export interface ApiClient {
  ctx: APIRequestContext;
  base: string;
  dispose(): Promise<void>;
}

export async function apiFor(
  session: Session,
  opts: { activeRole?: string | null } = {},
): Promise<ApiClient> {
  const headers: Record<string, string> = {
    Authorization: `Bearer ${session.token}`,
    Accept: 'application/json',
    'Content-Type': 'application/json',
    'X-School-ID': session.schoolId,
    'X-Tenant-ID': session.schoolId,
    'Accept-Language': 'id',
  };

  // `null` means "deliberately omit" — that is a test case, not an
  // oversight, so it has to be expressible.
  const role = opts.activeRole === undefined ? session.role : opts.activeRole;

  if (role) headers['X-Active-Role'] = role;

  const ctx = await request.newContext({ extraHTTPHeaders: headers });

  return {
    ctx,
    base: API_BASE,
    dispose: () => ctx.dispose(),
  };
}

/** Convenience: status code only, for matrix rows. */
export async function statusOf(
  client: ApiClient,
  method: 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE',
  path: string,
  body?: unknown,
): Promise<number> {
  const url = `${client.base}${path}`;

  const res = await client.ctx.fetch(url, {
    method,
    ...(body === undefined ? {} : { data: body }),
  });

  return res.status();
}
