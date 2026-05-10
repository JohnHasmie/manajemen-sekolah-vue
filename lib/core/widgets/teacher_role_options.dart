// Shared builders for teacher role-toggle chips.
//
// Three teacher screens (Presensi, Kegiatan Kelas, Rekap Nilai)
// surface a `RoleToggleChipRow` in their brand header that lets
// the teacher flip between "Mengajar" (their teaching schedule)
// and one chip per homeroom class they oversee. This file
// centralises the option construction so the labels, translations
// and chip ordering stay in sync — previously Rekap Nilai had a
// single aggregate "Wali" chip with no class name, while the
// other two showed "Wali 7B / Wali 8A …".
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/role_toggle_chip_row.dart';

/// Sub-label on the `Mengajar` chip — "Jadwal mengajar".
String _mengajarSubLabel(LanguageProvider lp) =>
    lp.getTranslatedText({'en': 'Teaching schedule', 'id': 'Jadwal mengajar'});

/// Sub-label on every wali chip — "Kelas perwalian".
String _waliSubLabel(LanguageProvider lp) =>
    lp.getTranslatedText({'en': 'Homeroom', 'id': 'Kelas perwalian'});

/// Builds `[Mengajar, Wali 7B, Wali 8A, …]` from a list of
/// homeroom class maps. Each map is expected to expose `id` and
/// `name`/`nama`. Used by Presensi, Kegiatan Kelas, and Rekap
/// Nilai so the three screens render identical chip strips.
List<RoleOption> buildMultiWaliRoleOptions({
  required List<dynamic> homeroomClasses,
  required LanguageProvider lp,
}) {
  return [
    RoleOption.mengajar(subLabel: _mengajarSubLabel(lp)),
    for (final hc in homeroomClasses)
      RoleOption.waliKelas(
        classId: (hc is Map ? hc['id'] : '').toString(),
        className:
            (hc is Map ? (hc['name'] ?? hc['nama']) : '').toString(),
        subLabel: _waliSubLabel(lp),
      ),
  ];
}
