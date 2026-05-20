// Admin "Kembalikan ke guru" sheet — Mockup Frame C2.
//
// The middle option between Setujui (accept) and Tolak (reject). Status
// stays Pending but `revision_requested_at` + `revision_areas` are set
// so the guru sees a revision banner on their detail screen and can
// fix the highlighted sections in place.
//
// NOTE — Admin does NOT dictate edit-vs-regen. The guru decides how to
// fix the RPP themselves (edit manually or regen via AI). The admin
// only flags WHICH sections need work.
//
// Returns a [LessonPlanSendBackResult] on confirm or null on cancel.
import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';

class LessonPlanSendBackResult {
  final String note;
  final List<String> areas;
  const LessonPlanSendBackResult({required this.note, required this.areas});
}

/// Maps each LessonPlanFormat to its canonical section labels —
/// mirrors what AI detail screens already use. Falls back to a
/// shared K13 set when the format string doesn't match anything.
List<_AreaOption> _areasForFormat(String format) {
  switch (format) {
    case 'rpp_1_halaman':
    case 'rpp1Halaman':
      return const [
        _AreaOption('tujuan', 'Tujuan Pembelajaran'),
        _AreaOption('kegiatan', 'Kegiatan Pembelajaran'),
        _AreaOption('asesmen', 'Asesmen'),
      ];
    case 'modul_ajar':
    case 'modulAjar':
      return const [
        _AreaOption('info_umum', 'Informasi Umum'),
        _AreaOption('capaian', 'Capaian Pembelajaran'),
        _AreaOption('tujuan', 'Tujuan Pembelajaran'),
        _AreaOption('pemahaman_pemantik', 'Pemahaman & Pemantik'),
        _AreaOption('kegiatan', 'Kegiatan Pembelajaran'),
        _AreaOption('asesmen_refleksi', 'Asesmen & Refleksi'),
      ];
    case 'file':
      // Upload-format RPP has no section editor — the guru just
      // re-uploads. Show a single "Lampiran" area chip so the admin's
      // intent is still recorded.
      return const [_AreaOption('lampiran', 'Lampiran')];
    case 'k13':
    default:
      return const [
        _AreaOption('identitas', 'Identitas'),
        _AreaOption('kd_indikator', 'KD & Indikator'),
        _AreaOption('tujuan', 'Tujuan Pembelajaran'),
        _AreaOption('langkah_kegiatan', 'Langkah Kegiatan'),
        _AreaOption('penilaian', 'Penilaian'),
      ];
  }
}

class _AreaOption {
  final String key;
  final String label;
  const _AreaOption(this.key, this.label);
}

Future<LessonPlanSendBackResult?> showLessonPlanAdminSendBackSheet({
  required BuildContext context,
  required String title,
  required String format,
  required String formatLabel,
  required String subjectLabel,
  required String classLabel,
  required String teacherName,
  String? initialNote,
  List<String>? initialAreas,
}) {
  return AppBottomSheet.show<LessonPlanSendBackResult>(
    context: context,
    title: 'Kembalikan ke guru',
    subtitle:
        'Status tetap Menunggu — guru menerima notifikasi & catatan revisi.',
    icon: Icons.reply_rounded,
    primaryColor: ColorUtils.warningDark,
    content: _SendBackSheetBody(
      title: title,
      format: format,
      formatLabel: formatLabel,
      subjectLabel: subjectLabel,
      classLabel: classLabel,
      teacherName: teacherName,
      initialNote: initialNote,
      initialAreas: initialAreas,
    ),
  );
}

class _SendBackSheetBody extends StatefulWidget {
  final String title;
  final String format;
  final String formatLabel;
  final String subjectLabel;
  final String classLabel;
  final String teacherName;
  final String? initialNote;
  final List<String>? initialAreas;

  const _SendBackSheetBody({
    required this.title,
    required this.format,
    required this.formatLabel,
    required this.subjectLabel,
    required this.classLabel,
    required this.teacherName,
    this.initialNote,
    this.initialAreas,
  });

  @override
  State<_SendBackSheetBody> createState() => _SendBackSheetBodyState();
}

class _SendBackSheetBodyState extends State<_SendBackSheetBody> {
  late final TextEditingController _ctrl;
  late final Set<String> _selectedAreas;
  late final List<_AreaOption> _availableAreas;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialNote ?? '');
    _selectedAreas = (widget.initialAreas ?? const <String>[]).toSet();
    _availableAreas = _areasForFormat(widget.format);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _canSubmit => _ctrl.text.trim().length >= 3;

  void _toggleArea(String key) {
    setState(() {
      if (_selectedAreas.contains(key)) {
        _selectedAreas.remove(key);
      } else {
        _selectedAreas.add(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _summaryCard(),
        const SizedBox(height: 14),
        _areaSection(),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              'Catatan untuk guru',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: ColorUtils.slate700,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '*',
              style: TextStyle(
                fontSize: 11,
                color: ColorUtils.error600,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _ctrl,
          maxLines: 4,
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            hintText: 'Tuliskan poin yang perlu diperbaiki…',
            hintStyle: TextStyle(color: ColorUtils.slate400, fontSize: 12),
            filled: true,
            fillColor: ColorUtils.slate50,
            contentPadding: const EdgeInsets.all(12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: ColorUtils.slate200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: ColorUtils.slate200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: ColorUtils.warningDark, width: 1.4),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _hintNotice(),
        const SizedBox(height: 14),
        BottomSheetFooter(
          primaryLabel: 'Kembalikan',
          secondaryLabel: 'Batal',
          primaryColor: ColorUtils.warningDark,
          primaryEnabled: _canSubmit,
          onPrimary: () => Navigator.of(context).pop(
            LessonPlanSendBackResult(
              note: _ctrl.text.trim(),
              areas: _selectedAreas.toList(),
            ),
          ),
          onSecondary: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _summaryCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.formatLabel.toUpperCase()} · ${widget.subjectLabel}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: ColorUtils.slate500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            widget.title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate900,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.classLabel} · ${widget.teacherName}',
            style: TextStyle(
              fontSize: 11,
              color: ColorUtils.slate500,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _areaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Bagian yang perlu diperbaiki',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: ColorUtils.slate700,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: ColorUtils.slate100,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'MULTI',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.slate500,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _availableAreas
              .map(
                (a) => _AreaChip(
                  label: a.label,
                  selected: _selectedAreas.contains(a.key),
                  onTap: () => _toggleArea(a.key),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _hintNotice() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        border: Border.all(color: const Color(0xFFFDE68A)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: ColorUtils.warningDark,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Guru akan menerima notifikasi dan catatan revisi muncul di '
              'kartu RPP mereka. Guru bebas memperbaiki manual atau '
              'regen ulang via AI.',
              style: TextStyle(
                fontSize: 11,
                color: ColorUtils.warningDark,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AreaChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AreaChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFEF3C7) : ColorUtils.slate50,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? const Color(0xFFFDE68A)
                  : ColorUtils.slate300,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(
                  Icons.check_rounded,
                  size: 12,
                  color: ColorUtils.warningDark,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? ColorUtils.warningDark : ColorUtils.slate600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
