/// Unit tests for ColorUtils.
///
/// Covers every public static method:
/// - getColorForIndex: rotating 6-color palette with modulo wrap
/// - getDayColor: Indonesian/English days, semesters, unknown fallback
/// - getStatusColor: green/red/amber/gray semantic mapping
/// - getGradeColor: threshold-based academic color mapping
/// - getRoleColor: role → color mapping (bilingual)
/// - getSubjectColor: keyword-matched subject colors + fallback
/// - getCardGradient: 5 semantic types + unknown + case-insensitive
/// - getTextColorForBackground: BT.601 luminance black/white contrast
/// - Palette getters: primaryColor, slate*, corporateBlue*, semantic brand
// variants, colors
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // getColorForIndex
  // ─────────────────────────────────────────────────────────────────────────
  group('getColorForIndex', () {
    test('index 0 returns first palette color', () {
      expect(ColorUtils.getColorForIndex(0), equals(const Color(0xFF6366F1)));
    });

    test('index 5 returns last palette color', () {
      expect(ColorUtils.getColorForIndex(5), equals(const Color(0xFF06B6D4)));
    });

    test('index 6 wraps to first color (modulo 6)', () {
      expect(
        ColorUtils.getColorForIndex(6),
        equals(ColorUtils.getColorForIndex(0)),
      );
    });

    test('index 12 wraps to first color (modulo 6)', () {
      expect(
        ColorUtils.getColorForIndex(12),
        equals(ColorUtils.getColorForIndex(0)),
      );
    });

    test('index 7 wraps to index 1', () {
      expect(
        ColorUtils.getColorForIndex(7),
        equals(ColorUtils.getColorForIndex(1)),
      );
    });

    test('all 6 palette colors are unique', () {
      final colors = List.generate(6, ColorUtils.getColorForIndex);
      final unique = colors.toSet();
      expect(unique.length, 6);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // getDayColor
  // ─────────────────────────────────────────────────────────────────────────
  group('getDayColor', () {
    test('Indonesian day Senin returns indigo', () {
      expect(ColorUtils.getDayColor('Senin'), equals(const Color(0xFF6366F1)));
    });

    test('Indonesian day Selasa returns green', () {
      expect(ColorUtils.getDayColor('Selasa'), equals(const Color(0xFF10B981)));
    });

    test('Indonesian day Rabu returns amber', () {
      expect(ColorUtils.getDayColor('Rabu'), equals(const Color(0xFFF59E0B)));
    });

    test('Indonesian day Kamis returns red', () {
      expect(ColorUtils.getDayColor('Kamis'), equals(const Color(0xFFEF4444)));
    });

    test('Indonesian day Jumat returns violet', () {
      expect(ColorUtils.getDayColor('Jumat'), equals(const Color(0xFF8B5CF6)));
    });

    test('Indonesian day Sabtu returns cyan', () {
      expect(ColorUtils.getDayColor('Sabtu'), equals(const Color(0xFF06B6D4)));
    });

    test('English day Monday matches Senin', () {
      expect(
        ColorUtils.getDayColor('Monday'),
        equals(ColorUtils.getDayColor('Senin')),
      );
    });

    test('English day Wednesday matches Rabu', () {
      expect(
        ColorUtils.getDayColor('Wednesday'),
        equals(ColorUtils.getDayColor('Rabu')),
      );
    });

    test('English day Friday matches Jumat', () {
      expect(
        ColorUtils.getDayColor('Friday'),
        equals(ColorUtils.getDayColor('Jumat')),
      );
    });

    test('Ganjil semester returns indigo', () {
      expect(ColorUtils.getDayColor('Ganjil'), equals(const Color(0xFF6366F1)));
    });

    test('Genap semester returns green', () {
      expect(ColorUtils.getDayColor('Genap'), equals(const Color(0xFF10B981)));
    });

    test('unknown string returns a deterministic color', () {
      final color = ColorUtils.getDayColor('Minggu');
      expect(color, isA<Color>());
    });

    test('same unknown string always returns same color (determinism)', () {
      final c1 = ColorUtils.getDayColor('Unknownday');
      final c2 = ColorUtils.getDayColor('Unknownday');
      expect(c1, equals(c2));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // getStatusColor
  // ─────────────────────────────────────────────────────────────────────────
  group('getStatusColor', () {
    const green = Color(0xFF10B981);
    const red = Color(0xFFEF4444);
    const amber = Color(0xFFF59E0B);
    const gray = Color(0xFF6B7280);

    for (final status in [
      'active',
      'aktif',
      'present',
      'hadir',
      'completed',
      'selesai',
    ]) {
      test('$status → green', () {
        expect(ColorUtils.getStatusColor(status), equals(green));
      });
    }

    test('case-insensitive: ACTIVE → green', () {
      expect(ColorUtils.getStatusColor('ACTIVE'), equals(green));
    });

    test('case-insensitive: Aktif → green', () {
      expect(ColorUtils.getStatusColor('Aktif'), equals(green));
    });

    for (final status in [
      'inactive',
      'nonaktif',
      'absent',
      'absen',
      'pending',
      'menunggu',
    ]) {
      test('$status → red', () {
        expect(ColorUtils.getStatusColor(status), equals(red));
      });
    }

    for (final status in ['warning', 'peringatan', 'late', 'terlambat']) {
      test('$status → amber', () {
        expect(ColorUtils.getStatusColor(status), equals(amber));
      });
    }

    test('unknown status → gray', () {
      expect(ColorUtils.getStatusColor('unknown_xyz'), equals(gray));
    });

    test('empty string → gray', () {
      expect(ColorUtils.getStatusColor(''), equals(gray));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // getGradeColor
  // ─────────────────────────────────────────────────────────────────────────
  group('getGradeColor', () {
    test('100 → green (excellent)', () {
      expect(ColorUtils.getGradeColor(100), equals(const Color(0xFF10B981)));
    });

    test('85 → green (at threshold)', () {
      expect(ColorUtils.getGradeColor(85), equals(const Color(0xFF10B981)));
    });

    test('84 → lime (good)', () {
      expect(ColorUtils.getGradeColor(84), equals(const Color(0xFF84CC16)));
    });

    test('75 → lime (at threshold)', () {
      expect(ColorUtils.getGradeColor(75), equals(const Color(0xFF84CC16)));
    });

    test('74 → amber (average)', () {
      expect(ColorUtils.getGradeColor(74), equals(const Color(0xFFF59E0B)));
    });

    test('65 → amber (at threshold)', () {
      expect(ColorUtils.getGradeColor(65), equals(const Color(0xFFF59E0B)));
    });

    test('64 → orange (below average)', () {
      expect(ColorUtils.getGradeColor(64), equals(const Color(0xFFFB923C)));
    });

    test('55 → orange (at threshold)', () {
      expect(ColorUtils.getGradeColor(55), equals(const Color(0xFFFB923C)));
    });

    test('54 → red (poor)', () {
      expect(ColorUtils.getGradeColor(54), equals(const Color(0xFFEF4444)));
    });

    test('0 → red (poor)', () {
      expect(ColorUtils.getGradeColor(0), equals(const Color(0xFFEF4444)));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // getRoleColor
  // ─────────────────────────────────────────────────────────────────────────
  group('getRoleColor', () {
    test('admin → brand dark blue', () {
      expect(ColorUtils.getRoleColor('admin'), equals(const Color(0xFF143068)));
    });

    test('guru → brand cobalt', () {
      expect(ColorUtils.getRoleColor('guru'), equals(const Color(0xFF1B6FB8)));
    });

    test('teacher → green (same as guru)', () {
      expect(
        ColorUtils.getRoleColor('teacher'),
        equals(ColorUtils.getRoleColor('guru')),
      );
    });

    test('staff → orange', () {
      expect(ColorUtils.getRoleColor('staff'), equals(const Color(0xFFFF9F1C)));
    });

    test('wali → brand azzure blue', () {
      expect(ColorUtils.getRoleColor('wali'), equals(const Color(0xFF21AFE6)));
    });

    test('parent → purple (same as wali)', () {
      expect(
        ColorUtils.getRoleColor('parent'),
        equals(ColorUtils.getRoleColor('wali')),
      );
    });

    test('orang_tua → purple (same as wali)', () {
      expect(
        ColorUtils.getRoleColor('orang_tua'),
        equals(ColorUtils.getRoleColor('wali')),
      );
    });

    test('siswa → brand azzure blue', () {
      expect(ColorUtils.getRoleColor('siswa'), equals(const Color(0xFF21AFE6)));
    });

    test('student → blue (same as siswa)', () {
      expect(
        ColorUtils.getRoleColor('student'),
        equals(ColorUtils.getRoleColor('siswa')),
      );
    });

    test('case-insensitive: ADMIN → blue', () {
      expect(
        ColorUtils.getRoleColor('ADMIN'),
        equals(ColorUtils.getRoleColor('admin')),
      );
    });

    test('unknown role → returns a Color', () {
      expect(ColorUtils.getRoleColor('unknown_role'), isA<Color>());
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // getSubjectColor
  // ─────────────────────────────────────────────────────────────────────────
  group('getSubjectColor', () {
    test('Matematika → indigo', () {
      expect(
        ColorUtils.getSubjectColor('Matematika'),
        equals(const Color(0xFF6366F1)),
      );
    });

    test('Bahasa Indonesia → red', () {
      expect(
        ColorUtils.getSubjectColor('Bahasa Indonesia'),
        equals(const Color(0xFFEF4444)),
      );
    });

    test('Inggris → blue', () {
      expect(
        ColorUtils.getSubjectColor('Inggris'),
        equals(const Color(0xFF3B82F6)),
      );
    });

    test('Fisika → violet', () {
      expect(
        ColorUtils.getSubjectColor('Fisika'),
        equals(const Color(0xFF8B5CF6)),
      );
    });

    test('Kimia → pink', () {
      expect(
        ColorUtils.getSubjectColor('Kimia'),
        equals(const Color(0xFFEC4899)),
      );
    });

    test('Biologi → green', () {
      expect(
        ColorUtils.getSubjectColor('Biologi'),
        equals(const Color(0xFF10B981)),
      );
    });

    test('Sejarah → amber', () {
      expect(
        ColorUtils.getSubjectColor('Sejarah'),
        equals(const Color(0xFFF59E0B)),
      );
    });

    test('Geografi → lime', () {
      expect(
        ColorUtils.getSubjectColor('Geografi'),
        equals(const Color(0xFF84CC16)),
      );
    });

    test('Ekonomi → cyan', () {
      expect(
        ColorUtils.getSubjectColor('Ekonomi'),
        equals(const Color(0xFF06B6D4)),
      );
    });

    test('Seni Budaya → pink (matches "seni")', () {
      expect(
        ColorUtils.getSubjectColor('Seni Budaya'),
        equals(const Color(0xFFEC4899)),
      );
    });

    test('Pendidikan Olahraga → lime (matches "olahraga")', () {
      expect(
        ColorUtils.getSubjectColor('Pendidikan Olahraga'),
        equals(const Color(0xFF84CC16)),
      );
    });

    test('Teknologi Komputer → indigo (matches "komputer")', () {
      expect(
        ColorUtils.getSubjectColor('Teknologi Komputer'),
        equals(const Color(0xFF6366F1)),
      );
    });

    test('unknown subject → returns a Color (fallback)', () {
      expect(ColorUtils.getSubjectColor('Agama Islam'), isA<Color>());
    });

    test('same unknown subject returns same color (determinism)', () {
      final c1 = ColorUtils.getSubjectColor('Kewarganegaraan');
      final c2 = ColorUtils.getSubjectColor('Kewarganegaraan');
      expect(c1, equals(c2));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // getCardGradient
  // ─────────────────────────────────────────────────────────────────────────
  group('getCardGradient', () {
    test('primary returns 2 colors', () {
      expect(ColorUtils.getCardGradient('primary').length, 2);
    });

    test('primary gradient colors are distinct', () {
      final g = ColorUtils.getCardGradient('primary');
      expect(g[0], isNot(g[1]));
    });

    test('success returns 2 colors', () {
      expect(ColorUtils.getCardGradient('success').length, 2);
    });

    test('warning returns 2 colors', () {
      expect(ColorUtils.getCardGradient('warning').length, 2);
    });

    test('danger returns 2 colors', () {
      expect(ColorUtils.getCardGradient('danger').length, 2);
    });

    test('info returns 2 colors', () {
      expect(ColorUtils.getCardGradient('info').length, 2);
    });

    test('each type has a distinct start color', () {
      final starts = [
        'primary',
        'success',
        'warning',
        'danger',
        'info',
      ].map((t) => ColorUtils.getCardGradient(t)[0]).toList();
      expect(starts.toSet().length, 5);
    });

    test('unknown type returns gray gradient', () {
      expect(
        ColorUtils.getCardGradient('unknown')[0],
        equals(const Color(0xFF6B7280)),
      );
    });

    test('case-insensitive: PRIMARY → same as primary', () {
      expect(
        ColorUtils.getCardGradient('PRIMARY'),
        equals(ColorUtils.getCardGradient('primary')),
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // getTextColorForBackground
  // ─────────────────────────────────────────────────────────────────────────
  group('getTextColorForBackground', () {
    test('white background → black text', () {
      expect(
        ColorUtils.getTextColorForBackground(Colors.white),
        equals(Colors.black),
      );
    });

    test('black background → white text', () {
      expect(
        ColorUtils.getTextColorForBackground(Colors.black),
        equals(Colors.white),
      );
    });

    test('light yellow background → black text', () {
      expect(
        ColorUtils.getTextColorForBackground(const Color(0xFFFFFACD)),
        equals(Colors.black),
      );
    });

    test('dark blue background → white text', () {
      expect(
        ColorUtils.getTextColorForBackground(const Color(0xFF0D47A1)),
        equals(Colors.white),
      );
    });

    test('medium gray background → returns black or white', () {
      final result = ColorUtils.getTextColorForBackground(
        const Color(0xFF808080),
      );
      expect(result == Colors.black || result == Colors.white, isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Palette constants
  // ─────────────────────────────────────────────────────────────────────────
  group('primaryColor', () {
    test('is indigo', () {
      expect(ColorUtils.primaryColor, equals(const Color(0xFF4F46E5)));
    });

    test('primary alias equals primaryColor', () {
      expect(ColorUtils.primary, equals(ColorUtils.primaryColor));
    });
  });

  group('slate palette', () {
    test('slate50 is the lightest', () {
      expect(ColorUtils.slate50, equals(const Color(0xFFF8FAFC)));
    });

    test('slate950 is the darkest', () {
      expect(ColorUtils.slate950, equals(const Color(0xFF020617)));
    });

    test('slate shades darken monotonically from 50 to 950', () {
      final shades = [
        ColorUtils.slate50,
        ColorUtils.slate100,
        ColorUtils.slate200,
        ColorUtils.slate300,
        ColorUtils.slate400,
        ColorUtils.slate500,
        ColorUtils.slate600,
        ColorUtils.slate700,
        ColorUtils.slate800,
        ColorUtils.slate900,
        ColorUtils.slate950,
      ];
      for (int i = 1; i < shades.length; i++) {
        final prev = shades[i - 1].computeLuminance();
        final curr = shades[i].computeLuminance();
        expect(
          curr,
          lessThanOrEqualTo(prev),
          reason: 'slate shade $i should be darker than ${i - 1}',
        );
      }
    });
  });

  group('corporateBlue palette', () {
    test('corporateBlue50 is the lightest', () {
      expect(ColorUtils.corporateBlue50, equals(const Color(0xFFEFF6FF)));
    });

    test('corporateBlue900 is the darkest', () {
      expect(ColorUtils.corporateBlue900, equals(const Color(0xFF1E3A8A)));
    });
  });

  group('semantic color variants', () {
    test('successLight is lighter than successDark', () {
      expect(
        ColorUtils.successLight.computeLuminance(),
        greaterThan(ColorUtils.successDark.computeLuminance()),
      );
    });

    test('warningLight is lighter than warningDark', () {
      expect(
        ColorUtils.warningLight.computeLuminance(),
        greaterThan(ColorUtils.warningDark.computeLuminance()),
      );
    });

    test('errorLight is lighter than errorDark', () {
      expect(
        ColorUtils.errorLight.computeLuminance(),
        greaterThan(ColorUtils.errorDark.computeLuminance()),
      );
    });

    test('infoLight is lighter than infoDark', () {
      expect(
        ColorUtils.infoLight.computeLuminance(),
        greaterThan(ColorUtils.infoDark.computeLuminance()),
      );
    });
  });

  group('brand colors', () {
    test('kamilPrimary is deep blue', () {
      expect(ColorUtils.kamilPrimary, equals(const Color(0xFF143068)));
    });

    test('kamilAccent is vibrant teal', () {
      expect(ColorUtils.kamilAccent, equals(const Color(0xFF21AFE6)));
    });

    test('kamilPrimaryLight is lighter than kamilPrimary', () {
      expect(
        ColorUtils.kamilPrimaryLight.computeLuminance(),
        greaterThan(ColorUtils.kamilPrimary.computeLuminance()),
      );
    });

    test('kamilAccentLight is lighter than kamilAccent', () {
      expect(
        ColorUtils.kamilAccentLight.computeLuminance(),
        greaterThan(ColorUtils.kamilAccent.computeLuminance()),
      );
    });
  });
}
