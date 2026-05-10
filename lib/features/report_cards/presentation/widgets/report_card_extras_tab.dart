// Tab 3 (Tambahan) of the report card detail form — Frame C of
// `_design/teacher_raport_isi_redesign.html`.
//
// Two stacked sections:
//   • Ekstrakurikuler — extra-row cards (teal icon + name + grade pill
//     + delete) ending in a dashed "+ Tambah Ekstrakurikuler" card.
//   • Prestasi — same row pattern with amber accent, ending in a
//     dashed "+ Tambah Prestasi" add card.
//
// Each row opens an inline edit sheet via [showDialog] so the wali
// kelas can fill name + grade/level + description. The list state is
// owned by the parent screen; this tab surfaces every mutation
// through callbacks.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

class ReportCardExtrasTab extends StatelessWidget {
  final List<Map<String, dynamic>> extras;
  final List<Map<String, dynamic>> achievements;
  final VoidCallback onAddExtra;
  final VoidCallback onAddAchievement;
  final void Function(int index, String field, String value) onExtraChanged;
  final void Function(int index) onDeleteExtra;
  final void Function(int index, String field, String value)
  onAchievementChanged;
  final void Function(int index) onDeleteAchievement;
  final VoidCallback onMarkUnsaved;

  const ReportCardExtrasTab({
    super.key,
    required this.extras,
    required this.achievements,
    required this.onAddExtra,
    required this.onAddAchievement,
    required this.onExtraChanged,
    required this.onDeleteExtra,
    required this.onAchievementChanged,
    required this.onDeleteAchievement,
    required this.onMarkUnsaved,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
      children: [
        _SectCard(
          icon: Icons.sports_soccer_rounded,
          iconBg: ColorUtils.success600.withValues(alpha: 0.10),
          iconFg: ColorUtils.success600,
          title: 'Ekstrakurikuler',
          chip: '${extras.length} aktif',
          children: [
            for (var i = 0; i < extras.length; i++)
              _ExtraRow(
                icon: Icons.star_rounded,
                accent: ColorUtils.success600,
                title: extras[i]['name']?.toString() ?? '(Tanpa nama)',
                subtitle: extras[i]['description']?.toString() ?? '',
                gradeLabel: extras[i]['score']?.toString(),
                onTap: () => _editExtra(context, i),
                onDelete: () {
                  onDeleteExtra(i);
                  onMarkUnsaved();
                },
              ),
            _AddCard(
              title: 'Tambah Ekstrakurikuler',
              subtitle: 'Catat kegiatan rutin & nilai',
              onTap: () {
                onAddExtra();
                onMarkUnsaved();
                // Opens the row in edit mode after the parent setState.
                Future.microtask(() {
                  final newIdx = extras.length; // after append
                  if (newIdx > 0 && context.mounted) {
                    _editExtra(context, newIdx - 1);
                  }
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        _SectCard(
          icon: Icons.emoji_events_rounded,
          iconBg: ColorUtils.warning600.withValues(alpha: 0.10),
          iconFg: ColorUtils.warning600,
          title: 'Prestasi',
          chip: '${achievements.length} prestasi',
          children: [
            for (var i = 0; i < achievements.length; i++)
              _ExtraRow(
                icon: Icons.workspace_premium_rounded,
                accent: ColorUtils.warning600,
                title: achievements[i]['name']?.toString() ?? '(Tanpa nama)',
                subtitle:
                    achievements[i]['type']?.toString() ??
                    achievements[i]['description']?.toString() ??
                    '',
                gradeLabel: null,
                onTap: () => _editAchievement(context, i),
                onDelete: () {
                  onDeleteAchievement(i);
                  onMarkUnsaved();
                },
              ),
            _AddCard(
              title: 'Tambah Prestasi',
              subtitle: 'Akademik / Non-akademik',
              onTap: () {
                onAddAchievement();
                onMarkUnsaved();
                Future.microtask(() {
                  final newIdx = achievements.length;
                  if (newIdx > 0 && context.mounted) {
                    _editAchievement(context, newIdx - 1);
                  }
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _editExtra(BuildContext context, int index) async {
    final result = await _showEditSheet(
      context,
      title: 'Ekstrakurikuler',
      initialName: extras[index]['name']?.toString() ?? '',
      initialGrade: extras[index]['score']?.toString() ?? '',
      initialNote: extras[index]['description']?.toString() ?? '',
      gradeLabel: 'Nilai',
    );
    if (result != null) {
      onExtraChanged(index, 'name', result.name);
      onExtraChanged(index, 'score', result.grade);
      onExtraChanged(index, 'description', result.note);
      onMarkUnsaved();
    }
  }

  Future<void> _editAchievement(BuildContext context, int index) async {
    final result = await _showEditSheet(
      context,
      title: 'Prestasi',
      initialName: achievements[index]['name']?.toString() ?? '',
      initialGrade: achievements[index]['type']?.toString() ?? '',
      initialNote: achievements[index]['description']?.toString() ?? '',
      gradeLabel: 'Jenis',
    );
    if (result != null) {
      onAchievementChanged(index, 'name', result.name);
      onAchievementChanged(index, 'type', result.grade);
      onAchievementChanged(index, 'description', result.note);
      onMarkUnsaved();
    }
  }

  Future<_ExtraEditResult?> _showEditSheet(
    BuildContext context, {
    required String title,
    required String initialName,
    required String initialGrade,
    required String initialNote,
    required String gradeLabel,
  }) {
    final nameCtrl = TextEditingController(text: initialName);
    final gradeCtrl = TextEditingController(text: initialGrade);
    final noteCtrl = TextEditingController(text: initialNote);

    return showModalBottomSheet<_ExtraEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cobalt = ColorUtils.brandCobalt;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ColorUtils.slate200,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: ColorUtils.slate900,
                  ),
                ),
                const SizedBox(height: 14),
                _SheetField(label: 'Nama', controller: nameCtrl),
                const SizedBox(height: 10),
                _SheetField(label: gradeLabel, controller: gradeCtrl),
                const SizedBox(height: 10),
                _SheetField(
                  label: 'Keterangan',
                  controller: noteCtrl,
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: ColorUtils.slate100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Batal',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: ColorUtils.slate700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(
                          ctx,
                          _ExtraEditResult(
                            name: nameCtrl.text.trim(),
                            grade: gradeCtrl.text.trim(),
                            note: noteCtrl.text.trim(),
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: cobalt,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: cobalt.withValues(alpha: 0.30),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Simpan',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ExtraEditResult {
  final String name;
  final String grade;
  final String note;

  _ExtraEditResult({
    required this.name,
    required this.grade,
    required this.note,
  });
}

class _SheetField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int maxLines;

  const _SheetField({
    required this.label,
    required this.controller,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final cobalt = ColorUtils.brandCobalt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: ColorUtils.slate700,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(fontSize: 12.5, color: ColorUtils.slate700),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: ColorUtils.slate50,
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
        ),
      ],
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

class _ExtraRow extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final String? gradeLabel;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ExtraRow({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.gradeLabel,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: ColorUtils.slate200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 14, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: ColorUtils.slate900,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
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
                  ],
                ),
              ),
              if (gradeLabel != null && gradeLabel!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    gradeLabel!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onDelete,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: ColorUtils.slate400,
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

class _AddCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AddCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cobalt = ColorUtils.brandCobalt;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: DottedBorder(
          color: ColorUtils.slate300,
          radius: 14,
          child: Container(
            padding: const EdgeInsets.all(14),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: cobalt.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.add_rounded, size: 18, color: cobalt),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: cobalt,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: ColorUtils.slate500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lightweight dashed-border container — avoids pulling in the
/// external `dotted_border` package for a single use.
class DottedBorder extends StatelessWidget {
  final Color color;
  final double radius;
  final Widget child;

  const DottedBorder({
    super.key,
    required this.color,
    required this.radius,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRRectPainter(color: color, radius: radius),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: child,
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;

  _DashedRRectPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final path = Path()..addRRect(rrect);

    final dashed = Path();
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        dashed.addPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          Offset.zero,
        );
        distance = next + dashSpace;
      }
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(dashed, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) {
    return old.color != color || old.radius != radius;
  }
}
