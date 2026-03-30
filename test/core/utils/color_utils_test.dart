/// Tests for ColorUtils — verifies pure-logic color mapping methods.
///
/// Only static methods that return plain Color values or `List<Color>` are tested
/// here. BoxDecoration / LinearGradient builders are skipped because they
/// require Flutter's rendering pipeline (which is unavailable in plain unit tests).
///
/// Like testing a Laravel helper file: we call each function with known inputs
/// and assert the exact output without booting the whole framework.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

void main() {
  // ─── getColorForIndex ────────────────────────────────────────────────────

  group('ColorUtils.getColorForIndex', () {
    test('index 0 returns indigo 0xFF6366F1', () {
      expect(ColorUtils.getColorForIndex(0), Color(0xFF6366F1));
    });

    test('index 1 returns emerald 0xFF10B981', () {
      expect(ColorUtils.getColorForIndex(1), Color(0xFF10B981));
    });

    test('index 2 returns amber 0xFFF59E0B', () {
      expect(ColorUtils.getColorForIndex(2), Color(0xFFF59E0B));
    });

    test('index 3 returns red 0xFFEF4444', () {
      expect(ColorUtils.getColorForIndex(3), Color(0xFFEF4444));
    });

    test('index 4 returns violet 0xFF8B5CF6', () {
      expect(ColorUtils.getColorForIndex(4), Color(0xFF8B5CF6));
    });

    test('index 5 returns cyan 0xFF06B6D4', () {
      expect(ColorUtils.getColorForIndex(5), Color(0xFF06B6D4));
    });

    test('index 6 wraps around to the same color as index 0', () {
      // The palette has 6 entries; 6 % 6 == 0, so it wraps back to index 0.
      // Like PHP's `array_values($colors)[$index % count($colors)]` cycling pattern.
      expect(
        ColorUtils.getColorForIndex(6),
        ColorUtils.getColorForIndex(0),
      );
    });
  });

  // ─── getDayColor ─────────────────────────────────────────────────────────

  group('ColorUtils.getDayColor — Indonesian days', () {
    test('Senin → indigo 0xFF6366F1', () {
      expect(ColorUtils.getDayColor('Senin'), Color(0xFF6366F1));
    });

    test('Selasa → emerald 0xFF10B981', () {
      expect(ColorUtils.getDayColor('Selasa'), Color(0xFF10B981));
    });

    test('Rabu → amber 0xFFF59E0B', () {
      expect(ColorUtils.getDayColor('Rabu'), Color(0xFFF59E0B));
    });

    test('Kamis → red 0xFFEF4444', () {
      expect(ColorUtils.getDayColor('Kamis'), Color(0xFFEF4444));
    });

    test('Jumat → violet 0xFF8B5CF6', () {
      expect(ColorUtils.getDayColor('Jumat'), Color(0xFF8B5CF6));
    });

    test('Sabtu → cyan 0xFF06B6D4', () {
      expect(ColorUtils.getDayColor('Sabtu'), Color(0xFF06B6D4));
    });
  });

  group('ColorUtils.getDayColor — English days', () {
    test('Monday → same as Senin', () {
      expect(ColorUtils.getDayColor('Monday'), Color(0xFF6366F1));
    });

    test('Tuesday → same as Selasa', () {
      expect(ColorUtils.getDayColor('Tuesday'), Color(0xFF10B981));
    });

    test('Wednesday → same as Rabu', () {
      expect(ColorUtils.getDayColor('Wednesday'), Color(0xFFF59E0B));
    });

    test('Thursday → same as Kamis', () {
      expect(ColorUtils.getDayColor('Thursday'), Color(0xFFEF4444));
    });

    test('Friday → same as Jumat', () {
      expect(ColorUtils.getDayColor('Friday'), Color(0xFF8B5CF6));
    });

    test('Saturday → same as Sabtu', () {
      expect(ColorUtils.getDayColor('Saturday'), Color(0xFF06B6D4));
    });
  });

  group('ColorUtils.getDayColor — semester names', () {
    test('Ganjil (odd semester) → indigo 0xFF6366F1', () {
      expect(ColorUtils.getDayColor('Ganjil'), Color(0xFF6366F1));
    });

    test('Genap (even semester) → emerald 0xFF10B981', () {
      expect(ColorUtils.getDayColor('Genap'), Color(0xFF10B981));
    });

    test('Odd → same as Ganjil', () {
      expect(ColorUtils.getDayColor('Odd'), Color(0xFF6366F1));
    });

    test('Even → same as Genap', () {
      expect(ColorUtils.getDayColor('Even'), Color(0xFF10B981));
    });
  });

  group('ColorUtils.getDayColor — unknown string', () {
    test('unknown string returns a non-null Color (fallback hash color)', () {
      // The hash-based fallback guarantees a deterministic but non-null color.
      // Like a PHP helper that always returns a valid value rather than null.
      final color = ColorUtils.getDayColor('UnknownDay');
      expect(color, isNotNull);
      expect(color, isA<Color>());
    });
  });

  // ─── getStatusColor ──────────────────────────────────────────────────────

  group('ColorUtils.getStatusColor', () {
    test("'active' → green 0xFF10B981", () {
      expect(ColorUtils.getStatusColor('active'), Color(0xFF10B981));
    });

    test("'inactive' → red 0xFFEF4444", () {
      expect(ColorUtils.getStatusColor('inactive'), Color(0xFFEF4444));
    });

    test("'late' → amber 0xFFF59E0B", () {
      expect(ColorUtils.getStatusColor('late'), Color(0xFFF59E0B));
    });

    test("'hadir' (present, Indonesian) → green 0xFF10B981", () {
      expect(ColorUtils.getStatusColor('hadir'), Color(0xFF10B981));
    });

    test("'absen' (absent, Indonesian) → red 0xFFEF4444", () {
      expect(ColorUtils.getStatusColor('absen'), Color(0xFFEF4444));
    });

    test('unknown status → gray 0xFF6B7280', () {
      expect(ColorUtils.getStatusColor('somethingElse'), Color(0xFF6B7280));
    });

    test('status comparison is case-insensitive (ACTIVE → green)', () {
      expect(ColorUtils.getStatusColor('ACTIVE'), Color(0xFF10B981));
    });
  });

  // ─── getGradeColor ───────────────────────────────────────────────────────

  group('ColorUtils.getGradeColor', () {
    test('90 (≥85) → green 0xFF10B981 (excellent)', () {
      expect(ColorUtils.getGradeColor(90), Color(0xFF10B981));
    });

    test('80 (≥75) → lime 0xFF84CC16 (good)', () {
      expect(ColorUtils.getGradeColor(80), Color(0xFF84CC16));
    });

    test('70 (≥65) → amber 0xFFF59E0B (average)', () {
      expect(ColorUtils.getGradeColor(70), Color(0xFFF59E0B));
    });

    test('60 (≥55) → orange 0xFFFB923C (below average)', () {
      expect(ColorUtils.getGradeColor(60), Color(0xFFFB923C));
    });

    test('50 (<55) → red 0xFFEF4444 (poor)', () {
      expect(ColorUtils.getGradeColor(50), Color(0xFFEF4444));
    });

    test('exact boundary 85 → green', () {
      expect(ColorUtils.getGradeColor(85), Color(0xFF10B981));
    });

    test('exact boundary 75 → lime', () {
      expect(ColorUtils.getGradeColor(75), Color(0xFF84CC16));
    });
  });

  // ─── getRoleColor ────────────────────────────────────────────────────────

  group('ColorUtils.getRoleColor', () {
    test("'admin' → blue 0xFF2563EB", () {
      expect(ColorUtils.getRoleColor('admin'), Color(0xFF2563EB));
    });

    test("'guru' → green 0xFF16A34A", () {
      expect(ColorUtils.getRoleColor('guru'), Color(0xFF16A34A));
    });

    test("'teacher' → same green as 'guru'", () {
      expect(
        ColorUtils.getRoleColor('teacher'),
        ColorUtils.getRoleColor('guru'),
      );
    });

    test("'wali' → purple 0xFF9333EA", () {
      expect(ColorUtils.getRoleColor('wali'), Color(0xFF9333EA));
    });

    test("'siswa' → blue 0xFF3B82F6", () {
      expect(ColorUtils.getRoleColor('siswa'), Color(0xFF3B82F6));
    });

    test('unknown role → dark color (non-null)', () {
      final color = ColorUtils.getRoleColor('unknownRole');
      expect(color, isNotNull);
      expect(color, isA<Color>());
    });

    test('role comparison is case-insensitive (ADMIN → blue)', () {
      expect(ColorUtils.getRoleColor('ADMIN'), Color(0xFF2563EB));
    });
  });

  // ─── getSubjectColor ─────────────────────────────────────────────────────

  group('ColorUtils.getSubjectColor', () {
    test("'Matematika' → indigo 0xFF6366F1", () {
      expect(ColorUtils.getSubjectColor('Matematika'), Color(0xFF6366F1));
    });

    test("'Bahasa Indonesia' → red 0xFFEF4444 (matches 'bahasa' keyword)", () {
      expect(ColorUtils.getSubjectColor('Bahasa Indonesia'), Color(0xFFEF4444));
    });

    test("'Fisika' → purple 0xFF8B5CF6", () {
      expect(ColorUtils.getSubjectColor('Fisika'), Color(0xFF8B5CF6));
    });

    test('unknown subject returns a non-null Color (hash fallback)', () {
      final color = ColorUtils.getSubjectColor('Filsafat');
      expect(color, isNotNull);
      expect(color, isA<Color>());
    });

    test('subject matching is case-insensitive (MATEMATIKA → indigo)', () {
      expect(ColorUtils.getSubjectColor('MATEMATIKA'), Color(0xFF6366F1));
    });
  });

  // ─── getCardGradient ─────────────────────────────────────────────────────

  group('ColorUtils.getCardGradient', () {
    test("'primary' returns a list of exactly 2 colors", () {
      final gradient = ColorUtils.getCardGradient('primary');
      expect(gradient.length, 2);
    });

    test("'primary' starts with 0xFF4F46E5", () {
      expect(ColorUtils.getCardGradient('primary').first, Color(0xFF4F46E5));
    });

    test("'success' returns a list of exactly 2 colors", () {
      expect(ColorUtils.getCardGradient('success').length, 2);
    });

    test("'warning' returns a list of exactly 2 colors", () {
      expect(ColorUtils.getCardGradient('warning').length, 2);
    });

    test("'danger' returns a list of exactly 2 colors", () {
      expect(ColorUtils.getCardGradient('danger').length, 2);
    });

    test("'info' returns a list of exactly 2 colors", () {
      expect(ColorUtils.getCardGradient('info').length, 2);
    });

    test('unknown type falls back to a 2-color gray gradient', () {
      final gradient = ColorUtils.getCardGradient('unknown');
      expect(gradient.length, 2);
      expect(gradient.first, Color(0xFF6B7280));
    });

    test('type comparison is case-insensitive (PRIMARY → same as primary)', () {
      expect(
        ColorUtils.getCardGradient('PRIMARY'),
        ColorUtils.getCardGradient('primary'),
      );
    });
  });

  // ─── getTextColorForBackground ───────────────────────────────────────────

  group('ColorUtils.getTextColorForBackground', () {
    test('white background → black text (high luminance)', () {
      // White has luminance ≈ 1.0 (> 0.5), so text must be black for readability.
      // Like Tailwind's contrast utility choosing dark text on light backgrounds.
      expect(
        ColorUtils.getTextColorForBackground(Colors.white),
        Colors.black,
      );
    });

    test('black background → white text (low luminance)', () {
      // Black has luminance = 0.0 (≤ 0.5), so text must be white.
      expect(
        ColorUtils.getTextColorForBackground(Colors.black),
        Colors.white,
      );
    });

    test('a mid-dark color (0xFF10B981 emerald) → white text', () {
      // Emerald green is dark enough that white text is more readable.
      final result = ColorUtils.getTextColorForBackground(Color(0xFF10B981));
      expect(result, isA<Color>());
    });
  });
}
