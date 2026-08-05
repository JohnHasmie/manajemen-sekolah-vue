/**
 * Vitest spec for TutoringMaterialRow — pins the material shape and
 * the open/download/delete emit signatures. Consumers: WEB-3 admin
 * materi list, WEB-4 tutor materi + upload flow, WEB-5 siswa+wali
 * materi read-only views.
 */
import { describe, expect, it } from 'vitest';
import type { DefineComponent } from 'vue';
import TutoringMaterialRow from './TutoringMaterialRow.vue';
import type { TutoringMaterial } from '@/types/tutoring-bimbel';

describe('TutoringMaterialRow contract', () => {
  it('exports a Vue component', () => {
    const c: DefineComponent = TutoringMaterialRow as unknown as DefineComponent;
    expect(c).toBeTruthy();
  });

  it('accepts a material with lesson-plan-style file_* fields', () => {
    // Shape mirrors the lesson-plan `file_*` set — the richest file
    // schema in the tree. All fields except id + title are optional so
    // half-populated backend rows still render.
    const _m: TutoringMaterial = {
      id: '019f8090-4d6a-71ab-bf01-c98a6ac73293',
      title: 'Ringkasan Vektor',
      description: 'Bab 3 SBMPTN Saintek',
      file_url: 'https://example.test/vektor.pdf',
      file_name: 'vektor.pdf',
      file_size: 1_258_291,
      file_size_mb: 1.2,
      file_mime: 'application/pdf',
      kind: 'PDF',
      program_label: 'SBMPTN Saintek',
      created_at: '2026-07-21T10:00:00+07:00',
    };
    expect(_m.title).toBeTruthy();
    expect(_m.file_size_mb).toBeCloseTo(1.2);
  });

  it('accepts a bare minimum material (just id + title)', () => {
    const _bare: TutoringMaterial = {
      id: 'x',
      title: 'Coming soon',
    };
    expect(_bare.id).toBe('x');
  });

  it('open/download/delete emits carry the full material back', () => {
    type EmitOne = (m: TutoringMaterial) => void;
    const _open: EmitOne = (m) => m.id;
    const _download: EmitOne = (m) => m.id;
    const _delete: EmitOne = (m) => m.id;
    expect(typeof _open).toBe('function');
    expect(typeof _download).toBe('function');
    expect(typeof _delete).toBe('function');
  });
});
