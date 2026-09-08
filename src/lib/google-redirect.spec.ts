/**
 * Spec for the Google "redirect mode" return leg.
 *
 * The two things that must never regress:
 *   1. the Sanctum PAT is out of the URL before anything can record it
 *   2. a `kg_error=` return is reported, not swallowed
 *
 * plus the tenant-scope teardown that keeps a previous session's
 * `X-Tenant-ID` from being replayed onto a brand-new token.
 */
// @ts-nocheck — repo convention for spec files
import { beforeEach, describe, expect, it } from 'vitest';
import {
  clearTenantScope,
  consumeGoogleRedirectFragment,
  googleRedirectErrorMessage,
  takeGoogleRedirect,
} from './google-redirect';
import { StorageKeys } from './storage';

function setHash(hash: string) {
  window.history.replaceState(null, '', '/login' + hash);
}

describe('consumeGoogleRedirectFragment', () => {
  beforeEach(() => {
    window.localStorage.clear();
    window.sessionStorage.clear();
    window.history.replaceState(null, '', '/login');
  });

  it('reports "none" when there is no auth fragment', () => {
    expect(consumeGoogleRedirectFragment()).toEqual({ kind: 'none' });
  });

  it('ignores a fragment that carries neither kg_token nor kg_error', () => {
    setHash('#section=pricing');
    expect(consumeGoogleRedirectFragment()).toEqual({ kind: 'none' });
    // A non-auth fragment is none of our business — leave it alone.
    expect(window.location.hash).toBe('#section=pricing');
  });

  it('persists the token and reports success', () => {
    setHash('#kg_token=pat-123');
    const result = consumeGoogleRedirectFragment();

    expect(result).toEqual({ kind: 'token', canCreateDemo: false });
    expect(window.sessionStorage.getItem(StorageKeys.token)).toBe('pat-123');
  });

  it('SECURITY: strips the PAT out of the URL', () => {
    setHash('#kg_token=pat-123&kg_dapat_buat_demo=1');
    consumeGoogleRedirectFragment();

    expect(window.location.hash).toBe('');
    expect(window.location.href).not.toContain('kg_token');
    expect(window.location.href).not.toContain('pat-123');
  });

  it('preserves the path and query while stripping the fragment', () => {
    window.history.replaceState(
      null,
      '',
      '/subscribe?returnTo=%2Fbilling#kg_token=pat-123',
    );
    consumeGoogleRedirectFragment();

    expect(window.location.pathname).toBe('/subscribe');
    expect(window.location.search).toBe('?returnTo=%2Fbilling');
    expect(window.location.hash).toBe('');
  });

  it('picks up the demo-eligibility flag', () => {
    setHash('#kg_token=pat-123&kg_dapat_buat_demo=1');
    expect(consumeGoogleRedirectFragment()).toEqual({
      kind: 'token',
      canCreateDemo: true,
    });
  });

  it('reports a kg_error return with a user-facing message', () => {
    setHash('#kg_error=login_rejected');
    const result = consumeGoogleRedirectFragment();

    expect(result.kind).toBe('error');
    expect(result.code).toBe('login_rejected');
    expect(result.message.length).toBeGreaterThan(0);
    // The error leg must clear the fragment too, or a reload replays it.
    expect(window.location.hash).toBe('');
    // No half-session left behind.
    expect(window.sessionStorage.getItem(StorageKeys.token)).toBeNull();
  });

  it('still produces a message for an error code it has never seen', () => {
    setHash('#kg_error=some_future_backend_code');
    const result = consumeGoogleRedirectFragment();
    expect(result.kind).toBe('error');
    expect(result.message.length).toBeGreaterThan(0);
  });

  it('cannot be replayed: a second read finds nothing', () => {
    setHash('#kg_token=pat-123');
    expect(consumeGoogleRedirectFragment().kind).toBe('token');
    expect(consumeGoogleRedirectFragment()).toEqual({ kind: 'none' });
  });
});

describe('takeGoogleRedirect', () => {
  beforeEach(() => {
    window.localStorage.clear();
    window.sessionStorage.clear();
    window.history.replaceState(null, '', '/login');
  });

  it('hands the boot-time outcome over exactly once', () => {
    setHash('#kg_token=pat-123');
    consumeGoogleRedirectFragment();

    expect(takeGoogleRedirect()).toEqual({
      kind: 'token',
      canCreateDemo: false,
    });
    expect(takeGoogleRedirect()).toEqual({ kind: 'none' });
  });
});

describe('clearTenantScope', () => {
  beforeEach(() => {
    window.localStorage.clear();
    window.sessionStorage.clear();
  });

  it('drops every cached tenant key but keeps the token', () => {
    window.sessionStorage.setItem(StorageKeys.token, 'pat-123');
    window.localStorage.setItem(StorageKeys.schoolId, 'sch-old');
    window.localStorage.setItem(StorageKeys.role, 'admin');
    window.localStorage.setItem(StorageKeys.user, '{"id":"u-old"}');
    window.localStorage.setItem(StorageKeys.teacherProfile, '{"id":"t-old"}');
    window.localStorage.setItem(StorageKeys.parentActiveChild, 'child-old');
    window.localStorage.setItem('kamiledu.academicYearId', 'ay-old');

    clearTenantScope();

    expect(window.localStorage.getItem(StorageKeys.schoolId)).toBeNull();
    expect(window.localStorage.getItem(StorageKeys.role)).toBeNull();
    expect(window.localStorage.getItem(StorageKeys.user)).toBeNull();
    expect(window.localStorage.getItem(StorageKeys.teacherProfile)).toBeNull();
    expect(
      window.localStorage.getItem(StorageKeys.parentActiveChild),
    ).toBeNull();
    expect(window.localStorage.getItem('kamiledu.academicYearId')).toBeNull();
    // The freshly-minted token is the one thing that must survive.
    expect(window.sessionStorage.getItem(StorageKeys.token)).toBe('pat-123');
  });
});

describe('googleRedirectErrorMessage', () => {
  it('never returns an empty string', () => {
    for (const code of [
      'missing_credential',
      'malformed_token',
      'invalid_token',
      'no_token',
      'login_rejected',
      'login_failed',
      '',
    ]) {
      expect(googleRedirectErrorMessage(code).length).toBeGreaterThan(0);
    }
  });
});
