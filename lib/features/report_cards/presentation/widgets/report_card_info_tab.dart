// Tab 4 (Info & Keputusan) of the report card detail form — Frame D
// of `_design/teacher_raport_isi_redesign.html`.
//
// Three stacked sections:
//   • Kehadiran Semester Ini — 3-cell KPI (Sakit amber / Izin cobalt /
//     Alpha red) sitting in a slate-tinted card, plus an autofill note
//     summarising "X hari hadir. Otomatis dari Presensi · ubah manual".
//   • Catatan Wali Kelas — slate desc-input.
//   • Keputusan Akhir Tahun — 2-chip radio (Naik Kelas green /
//     Tinggal Kelas red) so the wali kelas confirms the year-end call.
import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/utils/color_utils.dart';

class ReportCardInfoTab extends StatefulWidget {
  final TextEditingController sickCtrl;
  final TextEditingController permitCtrl;
  final TextEditingController absentCtrl;
  final TextEditingController notesCtrl;
  final String promotionDecision;
  final List<String> decisions;
  final void Function(String? value) onPromotionChanged;

  const ReportCardInfoTab({
    super.key,
    required this.sickCtrl,
    required this.permitCtrl,
    required this.absentCtrl,
    required this.notesCtrl,
    required this.promotionDecision,
    required this.decisions,
    required this.onPromotionChanged,
  });

  @override
  State<ReportCardInfoTab> createState() => _ReportCardInfoTabState();
}

class _ReportCardInfoTabState extends State<ReportCardInfoTab> {
  @override
  void initState() {
    super.initState();
    widget.sickCtrl.addListener(_onChange);
    widget.permitCtrl.addListener(_onChange);
    widget.absentCtrl.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.sickCtrl.removeListener(_onChange);
    widget.permitCtrl.removeListener(_onChange);
    widget.absentCtrl.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  int _parse(TextEditingController c) {
    return int.tryParse(c.text.trim()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final cobalt = ColorUtils.brandCobalt;
    final sick = _parse(widget.sickCtrl);
    final permit = _parse(widget.permitCtrl);
    final absent = _parse(widget.absentCtrl);
    final totalAbsent = sick + permit + absent;
    // Coarse hadir hint — ~92 school days / semester baseline. The
    // autofill note doesn't claim authority, just nudges the wali to
    // sanity-check the count.
    const baselineDays = 92;
    final hadir = (baselineDays - totalAbsent).clamp(0, baselineDays);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
      children: [
        // ── Kehadiran 3-cell KPI ──
        _SectCard(
          icon: Icons.event_available_rounded,
          iconBg: ColorUtils.success600.withValues(alpha: 0.10),
          iconFg: ColorUtils.success600,
          title: 'Kehadiran Semester Ini',
          chip: 'Total $baselineDays hari',
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ColorUtils.slate200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _Kpi3Cell(
                      controller: widget.sickCtrl,
                      label: 'Sakit',
                      color: ColorUtils.warning600,
                    ),
                  ),
                  Container(width: 1, height: 28, color: ColorUtils.slate100),
                  Expanded(
                    child: _Kpi3Cell(
                      controller: widget.permitCtrl,
                      label: 'Izin',
                      color: cobalt,
                    ),
                  ),
                  Container(width: 1, height: 28, color: ColorUtils.slate100),
                  Expanded(
                    child: _Kpi3Cell(
                      controller: widget.absentCtrl,
                      label: 'Alpha',
                      color: ColorUtils.error600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: cobalt.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.5,
                    color: ColorUtils.slate500,
                    fontWeight: FontWeight.w600,
                  ),
                  children: [
                    TextSpan(
                      text: '$hadir hari hadir. ',
                      style: TextStyle(
                        color: cobalt,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const TextSpan(
                      text:
                          'Otomatis terisi dari Presensi · ubah manual jika perlu.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ── Catatan Wali Kelas ──
        _SectCard(
          icon: Icons.chat_rounded,
          iconBg: cobalt.withValues(alpha: 0.10),
          iconFg: cobalt,
          title: 'Catatan Wali Kelas',
          chip: 'Opsional',
          children: [
            _DescInput(
              controller: widget.notesCtrl,
              hint: 'Catatan, saran, atau motivasi untuk siswa dan orang tua…',
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ── Keputusan Akhir Tahun ──
        _SectCard(
          icon: Icons.check_circle_rounded,
          iconBg: ColorUtils.violet700.withValues(alpha: 0.10),
          iconFg: ColorUtils.violet700,
          title: 'Keputusan Akhir Tahun',
          chip: 'Wajib',
          children: [
            Row(
              children: [
                Expanded(
                  child: _KeputusanChip(
                    selected: widget.promotionDecision == 'Naik Kelas',
                    icon: Icons.check_rounded,
                    color: ColorUtils.success600,
                    title: 'Naik Kelas',
                    subtitle: 'Lanjut ke tingkat berikutnya',
                    onTap: () => widget.onPromotionChanged('Naik Kelas'),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _KeputusanChip(
                    selected:
                        widget.promotionDecision == 'Tinggal di Kelas' ||
                        widget.promotionDecision == 'Tinggal Kelas',
                    icon: Icons.close_rounded,
                    color: ColorUtils.error600,
                    title: 'Tinggal Kelas',
                    subtitle: 'Mengulang tingkat ini',
                    onTap: () => widget.onPromotionChanged('Tinggal di Kelas'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Sub-widgets ────────────────────────────────────────────────────

class _Kpi3Cell extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final Color color;

  const _Kpi3Cell({
    required this.controller,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 60,
          height: 30,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: -0.4,
              height: 1.0,
            ),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              hintText: '0',
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: ColorUtils.slate500,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

class _DescInput extends StatelessWidget {
  final TextEditingController controller;
  final String? hint;

  const _DescInput({required this.controller, this.hint});

  @override
  Widget build(BuildContext context) {
    final cobalt = ColorUtils.brandCobalt;
    return TextField(
      controller: controller,
      maxLines: 4,
      minLines: 3,
      keyboardType: TextInputType.multiline,
      style: TextStyle(fontSize: 12.5, color: ColorUtils.slate700, height: 1.5),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: ColorUtils.slate50,
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 12.5,
          color: ColorUtils.slate400,
          height: 1.5,
        ),
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
          borderSide: BorderSide(color: cobalt, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
    );
  }
}

class _KeputusanChip extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _KeputusanChip({
    required this.selected,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : ColorUtils.slate200,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: ColorUtils.slate900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: ColorUtils.slate500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String title;
  final String? chip;
  final List<Widget> children;

  const _SectCard({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.title,
    required this.children,
    this.chip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 14, color: iconFg),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: ColorUtils.slate900,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
              if (chip != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: ColorUtils.slate100,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    chip!,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: ColorUtils.slate600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}
