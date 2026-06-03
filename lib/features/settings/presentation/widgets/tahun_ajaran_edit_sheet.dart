// Tambah / Edit Tahun Ajaran sheet — Frame D of the Pengaturan Umum
// redesign.
//
// Built on top of [AppBottomSheet] + [BottomSheetFooter] (shared brand
// components). Gradient head turns GREEN for Tambah (positive create
// action) and stays cobalt for Edit. The high-stakes "Set sebagai
// 'Saat Ini'" toggle is rendered as an amber warning row so the
// admin sees the cascade implication before flipping it.
//
// Form fields use the shared [BrandTextFormField] + [BrandReadOnlyField]
// pair so labels read as 11px-caps-above-filled-input across every
// settings sheet.
//
// Spec source: `_design/admin_tahun_ajaran_redesign.html` Frame D.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/academic_year_utils.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/date_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';
import 'package:manajemensekolah/core/widgets/modern_date_picker.dart';
import 'package:manajemensekolah/features/settings/data/academic_service.dart';
import 'package:manajemensekolah/features/settings/presentation/widgets/brand_form_field.dart';
import 'package:manajemensekolah/features/settings/presentation/widgets/tahun_ajaran_activate_dialog.dart';

class TahunAjaranEditSheet {
  /// Opens the Tambah / Edit Tahun Ajaran sheet.
  ///
  /// Pass [academicYear] to enter edit mode; omit it for create mode.
  /// [onSaved] fires after a successful save so the host screen can
  /// refresh the year list.
  static Future<void> show({
    required BuildContext context,
    required WidgetRef ref,
    Map<String, dynamic>? academicYear,
    required VoidCallback onSaved,
  }) async {
    final isCreate = academicYear == null;

    final yearController = TextEditingController(
      text: isCreate ? '' : (academicYear['year']?.toString() ?? ''),
    );

    DateTime? startDate = (academicYear?['start_date'] != null)
        ? DateTime.tryParse(academicYear!['start_date'].toString())
        : null;
    DateTime? endDate = (academicYear?['end_date'] != null)
        ? DateTime.tryParse(academicYear!['end_date'].toString())
        : null;

    final initialIsCurrent =
        !isCreate &&
        (academicYear['current'] == true || academicYear['current'] == 1);
    bool isCurrent = initialIsCurrent;
    bool isSaving = false;

    // Embedded semester from the AY row itself (post-migration source
    // of truth). Falls back to 'Ganjil' for create mode + legacy rows.
    //
    // `academic_years.semester` still uses Indonesian per backend
    // convention, but [semesterDisplayLabel] also accepts the canonical
    // `odd` / `even` encoding so the chip stays correct if a future code
    // path leaks the canonical value in here.
    String selectedSemester = () {
      final label = semesterDisplayLabel(academicYear?['semester']?.toString());
      return label ?? 'Ganjil';
    }();

    // Both Tambah and Edit use the admin brand navy. The earlier draft
    // used green for Tambah as a "positive create" cue, but per the
    // brand convention every admin sheet stays navy regardless of
    // intent — only role-specific surfaces (teacher cobalt, parent
    // azure) deviate. The Simpan footer button matches.
    final Color accent = ColorUtils.brandDarkBlue;

    await AppBottomSheet.show(
      context: context,
      title: isCreate ? 'Tambah Tahun Ajaran' : 'Edit Tahun Ajaran',
      subtitle: isCreate
          ? 'Buat tahun ajaran baru di sistem'
          : 'Perbarui data tahun ajaran',
      icon: Icons.calendar_today_rounded,
      primaryColor: accent,
      contentPadding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      content: StatefulBuilder(
        builder: (context, setSheetState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BrandTextFormField(
                label: 'Tahun Ajaran',
                controller: yearController,
                prefixIcon: Icons.calendar_today_outlined,
                hintText: '2026/2027',
                keyboardType: TextInputType.text,
                accent: accent,
              ),
              const SizedBox(height: 14),
              _SemesterChips(
                value: selectedSemester,
                accent: accent,
                onChanged: (v) => setSheetState(() => selectedSemester = v),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: BrandReadOnlyField(
                      label: 'Tanggal Mulai',
                      prefixIcon: Icons.date_range_rounded,
                      hintText: 'Pilih tanggal',
                      accent: accent,
                      value: startDate == null
                          ? null
                          : AppDateUtils.formatDateString(
                              startDate!.toIso8601String(),
                              format: 'dd MMM yyyy',
                            ),
                      onTap: () async {
                        final picked = await showModernDatePicker(
                          context: context,
                          initialDate: startDate ?? DateTime.now(),
                          title: 'Pilih Tanggal Mulai',
                          primaryColor: accent,
                        );
                        if (picked != null) {
                          setSheetState(() => startDate = picked);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: BrandReadOnlyField(
                      label: 'Tanggal Selesai',
                      prefixIcon: Icons.event_rounded,
                      hintText: 'Pilih tanggal',
                      accent: accent,
                      value: endDate == null
                          ? null
                          : AppDateUtils.formatDateString(
                              endDate!.toIso8601String(),
                              format: 'dd MMM yyyy',
                            ),
                      onTap: () async {
                        final picked = await showModernDatePicker(
                          context: context,
                          initialDate:
                              endDate ??
                              (startDate ?? DateTime.now()).add(
                                const Duration(days: 180),
                              ),
                          title: 'Pilih Tanggal Selesai',
                          primaryColor: accent,
                        );
                        if (picked != null) {
                          setSheetState(() => endDate = picked);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              BrandAmberToggleRow(
                title: "Set sebagai 'Saat Ini'",
                subtitle:
                    'Mengganti tahun ajaran aktif. Data lama otomatis diarsipkan.',
                value: isCurrent,
                onChanged: (v) => setSheetState(() => isCurrent = v),
              ),
            ],
          );
        },
      ),
      footer: StatefulBuilder(
        builder: (context, setFooterState) {
          return BottomSheetFooter(
            primaryLabel: isSaving ? 'Menyimpan…' : 'Simpan',
            primaryColor: accent,
            primaryEnabled: !isSaving,
            secondaryLabel: 'Batal',
            onPrimary: () async {
              final yearText = yearController.text.trim();
              // Validate Tahun Ajaran format
              final regex = RegExp(r'^\d{4}/\d{4}$');
              if (yearText.isEmpty) {
                SnackBarUtils.showError(
                  context,
                  'Tahun ajaran tidak boleh kosong',
                );
                return;
              }
              if (!regex.hasMatch(yearText)) {
                SnackBarUtils.showError(
                  context,
                  'Format tahun ajaran harus YYYY/YYYY (contoh: 2026/2027)',
                );
                return;
              }
              if (startDate == null || endDate == null) {
                SnackBarUtils.showError(
                  context,
                  'Tanggal mulai dan selesai harus diisi',
                );
                return;
              }
              if (endDate!.isBefore(startDate!)) {
                SnackBarUtils.showError(
                  context,
                  'Tanggal selesai tidak boleh sebelum tanggal mulai',
                );
                return;
              }

              // High-stakes flag — confirm via Frame E before save.
              bool proceedActivate = false;
              if (isCurrent && !initialIsCurrent) {
                final activeYear = ref
                    .read(academicYearRiverpod)
                    .activeAcademicYear;
                final activeYearLabel = activeYear?['year']?.toString();
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (_) => TahunAjaranActivateDialog(
                    targetYear: yearText,
                    currentActiveYear: activeYearLabel,
                  ),
                );
                if (confirmed != true) return;
                proceedActivate = true;
              }

              setFooterState(() => isSaving = true);
              try {
                final svc = getIt<ApiAcademicServices>();
                final ayProvider = ref.read(academicYearRiverpod);
                final semLower = selectedSemester.toLowerCase();
                final startIso = startDate!.toIso8601String().split('T').first;
                final endIso = endDate!.toIso8601String().split('T').first;

                Map<String, dynamic> saved;
                if (isCreate) {
                  final response = await svc.createAcademicYear(
                    yearText,
                    semester: semLower,
                    current: isCurrent,
                    status: isCurrent ? 'active' : 'inactive',
                    startDate: startIso,
                    endDate: endIso,
                  );
                  saved = Map<String, dynamic>.from(response);
                } else {
                  final response = await svc.updateAcademicYear(
                    academicYear['id'].toString(),
                    year: yearText,
                    semester: semLower,
                    current: isCurrent,
                    status: isCurrent
                        ? 'active'
                        : (academicYear['status']?.toString() ?? 'inactive'),
                    startDate: startIso,
                    endDate: endIso,
                  );
                  saved = Map<String, dynamic>.from(response);
                }

                if (proceedActivate) {
                  await svc.setCurrentAcademicYear(saved['id'].toString());
                }

                // Best-effort: sync the legacy global "current semester"
                // record so non-redesigned screens keep showing the right
                // label. Failure is non-fatal.
                //
                // Backend follow-up migration normalized `semesters.name`
                // stored values to canonical `odd` / `even`. The
                // `academic_years.semester` column we just wrote (semLower
                // = `ganjil`/`genap`) still uses Indonesian, so we
                // canonicalize it before matching against the row in
                // `/semesters`. We also defensively accept either encoding
                // in case the row hasn't been migrated yet.
                try {
                  final semList = (await dioClient.get('/semesters')).data;
                  if (semList is List) {
                    final semCanonical = canonicalSemesterName(semLower);
                    final match = semList.firstWhere((s) {
                      final name = (s['name']?.toString() ?? '')
                          .trim()
                          .toLowerCase();
                      return name == semCanonical || name == semLower;
                    }, orElse: () => null);
                    if (match != null) {
                      await dioClient.patch(
                        '/semesters/${match['id']}',
                        data: {'current': true},
                      );
                    }
                  }
                } catch (e) {
                  AppLogger.error('semester_sync', e);
                }

                await ayProvider.fetchAcademicYears();
                if (!context.mounted) return;
                AppNavigator.pop(context);
                onSaved();
                SnackBarUtils.showSuccess(
                  context,
                  isCreate
                      ? 'Tahun ajaran berhasil ditambahkan'
                      : 'Tahun ajaran berhasil diperbarui',
                );
              } catch (e) {
                AppLogger.error('academic_year_save', e);
                if (!context.mounted) return;
                SnackBarUtils.showError(
                  context,
                  'Gagal menyimpan: ${ErrorUtils.getFriendlyMessage(e)}',
                );
              } finally {
                setFooterState(() => isSaving = false);
              }
            },
            onSecondary: () => AppNavigator.pop(context),
          );
        },
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────
// Semester chip grid — Ganjil + Genap. Same Wrap-based no-truncation
// layout as the Jenjang chip grid in the Edit Informasi Sekolah sheet.
// ───────────────────────────────────────────────────────────────────────

class _SemesterChips extends StatelessWidget {
  final String value;
  final Color accent;
  final ValueChanged<String> onChanged;

  const _SemesterChips({
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SEMESTER BERJALAN',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: ColorUtils.slate600,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const ['Ganjil', 'Genap'].map((sem) {
            final selected = value == sem;
            final IconData ico = sem == 'Ganjil'
                ? Icons.wb_sunny_outlined
                : Icons.eco_outlined;
            return _SemesterChip(
              label: sem,
              icon: ico,
              selected: selected,
              accent: accent,
              onTap: () => onChanged(sem),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _SemesterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _SemesterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            color: selected ? accent : Colors.white,
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            border: Border.all(
              color: selected ? accent : ColorUtils.slate200,
              width: 1.5,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.20),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: selected ? Colors.white : ColorUtils.slate500,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : ColorUtils.slate700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
