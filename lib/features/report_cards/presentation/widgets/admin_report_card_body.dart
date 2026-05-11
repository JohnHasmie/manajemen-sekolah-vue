// Body widget for AdminReportCardScreen — v3 redesign.
//
// Two states:
//   • selectedClass == null  → list of class cards (drill targets)
//   • selectedClass != null  → "Daftar siswa" section header +
//                              compact "Ganti kelas" pill + v3 student
//                              rows with status-coloured edge

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

class AdminReportCardBody extends StatelessWidget {
  final List<dynamic> classes;
  final Map<String, dynamic>? selectedClass;
  final List<dynamic> students;
  final bool isLoadingStudents;
  final Color primaryColor;
  final GlobalKey selectClassKey;
  final GlobalKey studentListKey;
  final void Function(Map<String, dynamic>? cls) onClassChanged;
  final void Function(Map<String, dynamic> student) onViewDetail;
  final void Function(Map<String, dynamic> student) onDownloadPdf;

  const AdminReportCardBody({
    super.key,
    required this.classes,
    required this.selectedClass,
    required this.students,
    required this.isLoadingStudents,
    required this.primaryColor,
    required this.selectClassKey,
    required this.studentListKey,
    required this.onClassChanged,
    required this.onViewDetail,
    required this.onDownloadPdf,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedClass == null) {
      return _buildClassList(context);
    }
    return _buildStudentList(context);
  }

  // ── Class picker (no selection yet) ────────────────────────────────

  Widget _buildClassList(BuildContext context) {
    if (classes.isEmpty) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ColorUtils.slate200),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.class_outlined, size: 36, color: ColorUtils.slate400),
              const SizedBox(height: 10),
              Text(
                'Tidak ada kelas tersedia',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.slate900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Kelas akan muncul di sini setelah dibuat di Manajemen Kelas.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  color: ColorUtils.slate500,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Row(
            children: [
              Text(
                'PILIH KELAS',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: ColorUtils.slate500,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '· ${classes.length} KELAS',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: ColorUtils.slate300,
                ),
              ),
            ],
          ),
        ),
        ...classes.map(
          (cls) => _ClassCard(
            data: cls as Map<String, dynamic>,
            navy: primaryColor,
            onTap: () => onClassChanged(cls),
          ),
        ),
      ],
    );
  }

  // ── Student list (class selected) ──────────────────────────────────

  Widget _buildStudentList(BuildContext context) {
    return Column(
      children: [
        // Compact header row with section label + change-class chip
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      'DAFTAR SISWA',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: ColorUtils.slate500,
                      ),
                    ),
                    if (!isLoadingStudents) ...[
                      const SizedBox(width: 6),
                      Text(
                        '· ${students.length} SISWA',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: ColorUtils.slate300,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (classes.length > 1)
                _GantiKelasChip(
                  fieldKey: selectClassKey,
                  navy: primaryColor,
                  onTap: () => _openClassPickerSheet(context),
                ),
            ],
          ),
        ),
        Expanded(
          child: isLoadingStudents
              ? const Center(child: CircularProgressIndicator())
              : students.isEmpty
              ? Center(
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: ColorUtils.slate200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          color: ColorUtils.slate400,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Belum ada siswa pada kelas ini.',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: ColorUtils.slate500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  key: studentListKey,
                  padding: const EdgeInsets.only(top: 4, bottom: 16),
                  itemCount: students.length,
                  itemBuilder: (context, index) => _StudentRow(
                    data: students[index] as Map<String, dynamic>,
                    navy: primaryColor,
                    onTap: () =>
                        onViewDetail(students[index] as Map<String, dynamic>),
                    onPdf: () =>
                        onDownloadPdf(students[index] as Map<String, dynamic>),
                  ),
                ),
        ),
      ],
    );
  }

  void _openClassPickerSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _ClassPickerSheet(
        classes: classes,
        selectedId: selectedClass?['id']?.toString(),
        navy: primaryColor,
        onPick: (cls) {
          Navigator.of(sheetCtx).pop();
          onClassChanged(cls);
        },
      ),
    );
  }
}

// =====================================================================
// Class card (no-selection state)
// =====================================================================

class _ClassCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color navy;
  final VoidCallback onTap;

  const _ClassCard({
    required this.data,
    required this.navy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = (data['name'] ?? 'Unknown').toString();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final studentCount =
        (data['student_count'] ??
                data['students_count'] ??
                data['jumlah_siswa'] ??
                0)
            .toString();
    final tingkat = data['grade_level'] ?? data['tingkat'];
    final subtitle = tingkat != null
        ? 'Tingkat $tingkat · $studentCount siswa'
        : '$studentCount siswa';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ColorUtils.slate200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  offset: const Offset(0, 4),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: navy.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    initial,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: navy,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: ColorUtils.slate500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: ColorUtils.slate400,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// Ganti kelas chip + picker sheet
// =====================================================================

class _GantiKelasChip extends StatelessWidget {
  final GlobalKey fieldKey;
  final Color navy;
  final VoidCallback onTap;
  const _GantiKelasChip({
    required this.fieldKey,
    required this.navy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      key: fieldKey,
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ColorUtils.slate200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.swap_horiz_rounded, color: navy, size: 14),
              const SizedBox(width: 5),
              Text(
                'Ganti kelas',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: navy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassPickerSheet extends StatelessWidget {
  final List<dynamic> classes;
  final String? selectedId;
  final Color navy;
  final ValueChanged<Map<String, dynamic>> onPick;

  const _ClassPickerSheet({
    required this.classes,
    required this.selectedId,
    required this.navy,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ColorUtils.slate300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.swap_horiz_rounded, color: navy, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.selectClass.tr,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: ColorUtils.slate900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: classes.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: ColorUtils.slate100),
                itemBuilder: (context, i) {
                  final cls = classes[i] as Map<String, dynamic>;
                  final id = cls['id']?.toString();
                  final isActive = id == selectedId;
                  final name = (cls['name'] ?? '-').toString();
                  final tingkat = cls['grade_level'] ?? cls['tingkat'];
                  final studentCount =
                      cls['student_count'] ?? cls['students_count'] ?? 0;

                  return ListTile(
                    onTap: () => onPick(cls),
                    leading: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: navy.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: navy,
                        ),
                      ),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    subtitle: Text(
                      tingkat != null
                          ? 'Tingkat $tingkat · $studentCount siswa'
                          : '$studentCount siswa',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: ColorUtils.slate500,
                      ),
                    ),
                    trailing: isActive
                        ? Icon(Icons.check_circle_rounded, color: navy)
                        : Icon(
                            Icons.chevron_right_rounded,
                            color: ColorUtils.slate300,
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// Student row (v3)
// =====================================================================

class _StudentRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color navy;
  final VoidCallback onTap;
  final VoidCallback onPdf;

  const _StudentRow({
    required this.data,
    required this.navy,
    required this.onTap,
    required this.onPdf,
  });

  @override
  Widget build(BuildContext context) {
    final model = Student.fromJson(data);
    final status = (data['raport_status'] ?? 'draft').toString();

    final Color edgeColor;
    final Color pillBg;
    final Color pillFg;
    final String pillLabel;
    final IconData pillIcon;

    switch (status) {
      case 'published':
        edgeColor = const Color(0xFF10B981);
        pillBg = const Color(0xFFF0FDF4);
        pillFg = const Color(0xFF166534);
        pillLabel = 'Terbit';
        pillIcon = Icons.check_circle_rounded;
        break;
      case 'final':
        edgeColor = navy;
        pillBg = const Color(0xFFEEF2FF);
        pillFg = navy;
        pillLabel = 'Diperiksa';
        pillIcon = Icons.task_alt_rounded;
        break;
      default:
        edgeColor = const Color(0xFFFCD34D);
        pillBg = const Color(0xFFFFFBEB);
        pillFg = const Color(0xFFB45309);
        pillLabel = 'Draft';
        pillIcon = Icons.edit_note_rounded;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: edgeColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),
            Expanded(
              child: InkWell(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: navy.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          model.initials,
                          style: TextStyle(
                            color: navy,
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              model.name.isNotEmpty ? model.name : 'Tanpa nama',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'NIS · ${model.studentNumber.isNotEmpty ? model.studentNumber : '-'}',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: ColorUtils.slate500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: pillBg,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(pillIcon, size: 11, color: pillFg),
                                  const SizedBox(width: 4),
                                  Text(
                                    pillLabel,
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: pillFg,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Material(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: onPdf,
                          child: const SizedBox(
                            width: 36,
                            height: 36,
                            child: Icon(
                              Icons.picture_as_pdf_rounded,
                              size: 18,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: ColorUtils.slate400,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
