// Empty-state + error-state cards for the admin Jadwal hub's List view.
//
// Extracted verbatim from `admin_schedule_management_screen.dart` during
// the Phase-2 readability split. Both were private `_buildX` methods on
// the screen state; they're now pure StatelessWidgets driven by plain
// flags + callbacks so the screen stays an orchestrator. No layout,
// copy, or behaviour changed.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Error card shown in any view mode when the schedule load fails.
///
/// Was the inline `Container` returned by `_buildViewBody`'s error
/// branch — surfaced as a widget so the screen's body builder reads as a
/// one-liner. [onRetry] is wired to the screen's `_onRefresh`.
class AdminScheduleErrorCard extends StatelessWidget {
  const AdminScheduleErrorCard({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ColorUtils.slate200),
        ),
        child: Column(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: ColorUtils.error600,
              size: 36,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: ColorUtils.slate700, fontSize: 13),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty-state card shown when the list (or any view mode) has zero
/// schedules.
///
/// Three flavours (TR.H):
///   * **Pristine empty** — no filters, no day tab, search cleared,
///     AY editable. Shows the "Belum ada jadwal" hero + dual CTAs
///     (Tambah Manual + Import Excel) so the admin can start
///     populating data right from the empty state without having to
///     find the FAB or hunt down the overflow menu.
///   * **Filter-empty** — at least one filter active or a day-tab
///     selected. Shows the "Tidak ada hasil" copy + a single
///     secondary button to clear filters. Hides the data-entry CTAs
///     because the issue is filtering, not lack of data.
///   * **Read-only AY** — admin is browsing a past academic year.
///     Shows the "Belum ada jadwal di tahun ajaran ini" copy with
///     no write CTAs (would 403 anyway), just a read-only pill so
///     it's clear the absence is intentional, not a missing import.
class AdminScheduleEmptyCard extends StatelessWidget {
  const AdminScheduleEmptyCard({
    super.key,
    required this.lang,
    required this.isReadOnly,
    required this.hasFilters,
    required this.onClearFilters,
    required this.onImportExcel,
    required this.onAddManually,
  });

  final LanguageProvider lang;
  final bool isReadOnly;
  final bool hasFilters;
  final VoidCallback onClearFilters;
  final VoidCallback onImportExcel;
  final VoidCallback onAddManually;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ColorUtils.slate200),
          boxShadow: [
            BoxShadow(
              color: ColorUtils.slate900.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Soft-tinted icon disc — same chrome as the empty state
            // patterns used by Buku Nilai / Raport hubs.
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ColorUtils.brandCobalt.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isReadOnly
                    ? Icons.lock_outline_rounded
                    : (hasFilters
                          ? Icons.filter_alt_off_rounded
                          : Icons.calendar_today_outlined),
                size: 26,
                color: ColorUtils.brandCobalt,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isReadOnly
                  ? lang.getTranslatedText(const {
                      'en': 'No schedules this year',
                      'id': 'Belum ada jadwal di tahun ini',
                    })
                  : (hasFilters
                        ? lang.getTranslatedText(const {
                            'en': 'No results',
                            'id': 'Tidak ada hasil',
                          })
                        : lang.getTranslatedText(const {
                            'en': 'No schedules yet',
                            'id': 'Belum ada jadwal',
                          })),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: ColorUtils.brandDarkBlue,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isReadOnly
                  ? lang.getTranslatedText(const {
                      'en':
                          'This academic year is read-only. Switch to the '
                          'current year to add or import.',
                      'id':
                          'Tahun ajaran ini hanya baca. Pindah ke tahun '
                          'berjalan untuk menambah atau import.',
                    })
                  : (hasFilters
                        ? lang.getTranslatedText(const {
                            'en':
                                'Try clearing filters or picking another day.',
                            'id': 'Coba bersihkan filter atau pilih hari lain.',
                          })
                        : lang.getTranslatedText(const {
                            'en':
                                'Add the first session manually, or import a '
                                'schedule sheet to bulk-populate.',
                            'id':
                                'Tambah sesi pertama manual, atau import '
                                'sheet jadwal sekaligus banyak.',
                          })),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: ColorUtils.slate600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // CTA row varies by flavour. Read-only AY: a single
            // status pill, no write CTAs (backend would 403 anyway).
            if (isReadOnly)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: ColorUtils.slate100,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: ColorUtils.slate200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 14,
                      color: ColorUtils.slate600,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      lang.getTranslatedText(const {
                        'en': 'Read-only year',
                        'id': 'Hanya baca',
                      }),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: ColorUtils.slate700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              )
            else if (hasFilters)
              OutlinedButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text(
                  lang.getTranslatedText(const {
                    'en': 'Clear all filters',
                    'id': 'Bersihkan semua filter',
                  }),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ColorUtils.brandCobalt,
                  side: BorderSide(color: ColorUtils.slate200),
                  minimumSize: const Size.fromHeight(40),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onImportExcel,
                      icon: const Icon(Icons.upload_file_rounded, size: 16),
                      label: Text(
                        lang.getTranslatedText(const {
                          'en': 'Import Excel',
                          'id': 'Import Excel',
                        }),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ColorUtils.brandCobalt,
                        side: BorderSide(color: ColorUtils.slate200),
                        minimumSize: const Size.fromHeight(44),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onAddManually,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: Text(
                        lang.getTranslatedText(const {
                          'en': 'Add manually',
                          'id': 'Tambah Manual',
                        }),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColorUtils.brandCobalt,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(44),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
