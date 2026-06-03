// ClassroomCard — single classroom row in the admin list (v3 — SS2 layout).
//
// Top row: meta (Tingkat · Wali Kelas name) + "Detail →" CTA.
// Title:   bold class name.
// Status:  inline green-dot when homeroom assigned, amber otherwise.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;

import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_list_row.dart';
import 'package:manajemensekolah/core/widgets/initials_avatar.dart';
import 'package:manajemensekolah/features/classrooms/domain/models/classroom.dart';

class ClassroomCard extends ConsumerWidget {
  const ClassroomCard({
    super.key,
    required this.classData,
    required this.index,
    required this.gradeText,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.onLongPress,
    this.selected = false,
  });

  final Map<String, dynamic> classData;
  final int index;
  final String gradeText;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onLongPress;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.read(languageRiverpod);
    final isReadOnly = ref.read(academicYearRiverpod).isReadOnly;
    final accent = ColorUtils.getRoleColor('admin');
    final model = Classroom.fromJson(classData);
    final className = model.name.isNotEmpty ? model.name : 'Class';
    final teacherName = _resolveTeacherName(model, lang);

    final hasHomeroom = (model.homeroomTeacherName ?? '').isNotEmpty;
    final studentsWord = lang.getTranslatedText(const {
      'en': 'students',
      'id': 'siswa',
    });
    final topMeta = '$gradeText · ${model.studentCount} $studentsWord';

    final homeroomWord = lang.getTranslatedText(const {
      'en': 'Homeroom',
      'id': 'Wali',
    });
    final status = hasHomeroom
        ? BrandRowStatus.success('$homeroomWord: $teacherName')
        : BrandRowStatus.warning(
            lang.getTranslatedText(const {
              'en': 'No homeroom yet',
              'id': 'Belum ada wali',
            }),
          );

    return BrandListRow(
      leading: InitialsAvatar(
        name: className,
        size: 44,
        color: accent,
        borderRadius: 12,
      ),
      topMeta: topMeta,
      title: className,
      status: status,
      trailingActionLabel: selected
          ? null
          : lang.getTranslatedText(const {'en': 'Detail', 'id': 'Detail'}),
      trailingActionColor: accent,
      onTap: onTap,
      onLongPress: onLongPress ?? (isReadOnly ? null : onEdit),
      selected: selected,
    );
  }

  String _resolveTeacherName(
    Classroom model,
    LanguageProvider languageProvider,
  ) {
    final resolved = model.homeroomTeacherName;
    if (resolved != null && resolved.isNotEmpty) return resolved;
    return languageProvider.getTranslatedText({
      'en': 'Not Assigned',
      'id': 'Belum Ditugaskan',
    });
  }
}
