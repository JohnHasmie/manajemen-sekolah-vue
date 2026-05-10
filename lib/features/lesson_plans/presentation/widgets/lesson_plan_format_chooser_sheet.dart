import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';
import 'package:manajemensekolah/features/lesson_plans/domain/models/lesson_plan_format.dart';

/// Frame B from the RPP mockup — picks one of the four lesson-plan
/// formats (K13 / RPP 1 Halaman / Modul Ajar / Upload File).
///
/// This replaces the legacy `AddLessonPlanActionSheet` two-tile picker
/// (Manual vs AI). AI vs Manual is now a sub-axis surfaced inside the
/// setup form (Frame C) for the structured formats.
///
/// Returns the picked [LessonPlanFormat] or `null` if the user dismissed.
Future<LessonPlanFormat?> showLessonPlanFormatChooserSheet(
  BuildContext context, {
  LessonPlanFormat initial = LessonPlanFormat.k13,
}) {
  // Sheet chrome (header gradient + icon tint) is cobalt — the teacher
  // role color — so the sheet reads as a teacher tool. The 4 format
  // tiles inside still carry their own brand colors to differentiate
  // K13 / 1 Hal / Modul Ajar / Upload File.
  return AppBottomSheet.show<LessonPlanFormat>(
    context: context,
    title: 'Buat RPP baru',
    subtitle:
        'Pilih format yang dipakai sekolah. AI bantu draf di tahap berikutnya.',
    icon: Icons.post_add_rounded,
    primaryColor: ColorUtils.getRoleColor('guru'),
    content: _LessonPlanFormatChooserContent(initial: initial),
  );
}

class _LessonPlanFormatChooserContent extends StatefulWidget {
  const _LessonPlanFormatChooserContent({required this.initial});

  final LessonPlanFormat initial;

  @override
  State<_LessonPlanFormatChooserContent> createState() =>
      _LessonPlanFormatChooserContentState();
}

class _LessonPlanFormatChooserContentState
    extends State<_LessonPlanFormatChooserContent> {
  late LessonPlanFormat _selected = widget.initial;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 2x2 grid of format tiles. Mockup spec: each tile shows an
        // icon-tile (28dp), title, 2-line description, and a small
        // tag pill at the bottom (DIPILIH / RINGKAS / KURMER /
        // PDF · DOCX).
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          // Aspect ratio tuned so the tag pill never wraps; matches the
          // 132dp min-height in the HTML mockup.
          childAspectRatio: 0.92,
          children: [
            _FormatTile(
              format: LessonPlanFormat.k13,
              tagLabel: 'DIPILIH',
              desc:
                  'Format Kurikulum 2013 — KI/KD, indikator, langkah pendahuluan-inti-penutup.',
              isSelected: _selected == LessonPlanFormat.k13,
              onTap: () => setState(() => _selected = LessonPlanFormat.k13),
            ),
            _FormatTile(
              format: LessonPlanFormat.rpp1Halaman,
              tagLabel: 'RINGKAS',
              desc:
                  'Versi ringkas Mendikbud — tujuan, kegiatan inti, asesmen.',
              isSelected: _selected == LessonPlanFormat.rpp1Halaman,
              onTap: () =>
                  setState(() => _selected = LessonPlanFormat.rpp1Halaman),
            ),
            _FormatTile(
              format: LessonPlanFormat.modulAjar,
              tagLabel: 'KURMER',
              desc:
                  'Kurikulum Merdeka — capaian, alur tujuan, asesmen formatif.',
              isSelected: _selected == LessonPlanFormat.modulAjar,
              onTap: () =>
                  setState(() => _selected = LessonPlanFormat.modulAjar),
            ),
            _FormatTile(
              format: LessonPlanFormat.file,
              tagLabel: 'PDF · DOCX',
              desc: 'Lampirkan PDF/DOCX yang sudah disiapkan di luar app.',
              isSelected: _selected == LessonPlanFormat.file,
              onTap: () => setState(() => _selected = LessonPlanFormat.file),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        // Lanjutkan stays cobalt regardless of which format is picked
        // — the format tiles above already communicate the choice via
        // their selected-state border + tint.
        BottomSheetFooter(
          primaryLabel: 'Lanjutkan',
          primaryColor: ColorUtils.getRoleColor('guru'),
          primaryEnabled: true,
          onPrimary: () => AppNavigator.pop(context, _selected),
          onSecondary: () => AppNavigator.pop(context),
        ),
      ],
    );
  }
}

class _FormatTile extends StatelessWidget {
  const _FormatTile({
    required this.format,
    required this.tagLabel,
    required this.desc,
    required this.isSelected,
    required this.onTap,
  });

  final LessonPlanFormat format;
  final String tagLabel;
  final String desc;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = format.brandColor;
    final tint = format.tintColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: isSelected ? tint : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? brand
                  : const Color(0xFFE2E8F0), // slate-200
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: brand.withValues(alpha: 0.10),
                      blurRadius: 0,
                      spreadRadius: 3,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon tile
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: isSelected ? brand : tint,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  format.icon,
                  size: 16,
                  color: isSelected ? Colors.white : brand,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // Title
              Text(
                format.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A), // slate-900
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 4),
              // Description (max 3 lines)
              Expanded(
                child: Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 10,
                    height: 1.4,
                    color: Color(0xFF64748B), // slate-500
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 6),
              // Tag pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isSelected && format == LessonPlanFormat.k13
                      ? 'DIPILIH'
                      : tagLabel,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: brand,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
