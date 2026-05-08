// Shared builders for teacher role-toggle chips.
//
// Three teacher screens (Presensi, Kegiatan Kelas, Rekap Nilai)
// surface a `RoleToggleChipRow` in their brand header that lets
// the teacher flip between "Mengajar" (their teaching schedule)
// and one or more "Wali" (homeroom) views. They used to define
// these chips inline, leading to drift — Rekap Nilai had
// "Wali Kelas" as sub-label while the others had "Kelas perwalian".
//
// This file centralises the option construction so the labels,
// translations, and chip ordering stay in sync. Two flavours are
// exposed:
//
//   * [buildMultiWaliRoleOptions] — one chip per homeroom class
//     (Presensi, Kegiatan Kelas).
//   * [buildSingleWaliRoleOptions] — single aggregate "Wali" chip
//     (Rekap Nilai, which collapses all homeroom classes into one
//     `isHomeroomView` boolean).
//
// Both flavours share identical sub-labels so the three screens
// read consistently to the user.
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
/// `name`/`nama`. Used by Presensi and Kegiatan Kelas where the
/// teacher can flip between individual homeroom classes.
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

/// Builds `[Mengajar, Wali]` — a two-chip layout where the wali
/// chip aggregates all homeroom classes behind a single boolean
/// (Rekap Nilai). The wali chip carries `classId: 'all'` so the
/// host can pattern-match the same way as the multi-wali variant.
List<RoleOption> buildSingleWaliRoleOptions({required LanguageProvider lp}) {
  return [
    RoleOption.mengajar(subLabel: _mengajarSubLabel(lp)),
    RoleOption.waliKelas(
      classId: 'all',
      className: '',
      subLabel: _waliSubLabel(lp),
    ),
  ];
}
