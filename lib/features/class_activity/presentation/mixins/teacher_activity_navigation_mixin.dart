import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/app_draggable_sheet.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/embedded_activity_list_screen.dart';
import 'package:manajemensekolah/features/class_activity/presentation/mixins/teacher_activity_ui_helpers_mixin.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/teacher_class_activity_screen.dart';

mixin TeacherActivityNavigationMixin
    on ConsumerState<TeacherClassActivityScreen>
    implements TeacherActivityUIHelpersMixin {
  final _dio = getIt<Dio>();

  void openActivityList({
    required String classId,
    required String className,
    required String subjectId,
    required String subjectName,
  }) {
    AppDraggableSheet.show<void>(
      context: context,
      builder: (_, _) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: EmbeddedActivityListScreen(
          teacherId: teacherId,
          teacherName: teacherName,
          classId: classId,
          className: className,
          subjectId: subjectId,
          subjectName: subjectName,
        ),
      ),
    );
  }

  void showAddActivityFlow(LanguageProvider lp) {
    String? pickClassId;
    String? pickClassName;
    String? pickSubjectId;
    String? pickSubjectName;
    List<dynamic> pickSubjectList = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSS) => _buildAddActivitySheet(
          ctx,
          setSS,
          lp,
          () => pickClassId,
          (v) => pickClassId = v,
          () => pickClassName,
          (v) => pickClassName = v,
          () => pickSubjectId,
          (v) => pickSubjectId = v,
          () => pickSubjectName,
          (v) => pickSubjectName = v,
          () => pickSubjectList,
          (v) => pickSubjectList = v,
        ),
      ),
    );
  }

  Widget _buildAddActivitySheet(
    BuildContext ctx,
    StateSetter setSS,
    LanguageProvider lp,
    String? Function() getClassId,
    void Function(String?) setClassId,
    String? Function() getClassName,
    void Function(String?) setClassName,
    String? Function() getSubjectId,
    void Function(String?) setSubjectId,
    String? Function() getSubjectName,
    void Function(String?) setSubjectName,
    List<dynamic> Function() getSubjectList,
    void Function(List<dynamic>) setSubjectList,
  ) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSheetHeader(ctx, lp),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildSheetSectionHeader(
                    lp.getTranslatedText({
                      'en': 'Select Class',
                      'id': 'Pilih Kelas',
                    }),
                    Icons.school_rounded,
                  ),
                  _buildClassSelection(
                    setSS,
                    lp,
                    getClassId,
                    setClassId,
                    setClassName,
                    setSubjectId,
                    setSubjectList,
                  ),
                  const SizedBox(height: 20),
                  buildSheetSectionHeader(
                    lp.getTranslatedText({
                      'en': 'Select Subject',
                      'id': 'Pilih Mapel',
                    }),
                    Icons.menu_book_rounded,
                  ),
                  _buildSubjectSelection(
                    lp,
                    getClassId,
                    getSubjectId,
                    setSubjectId,
                    setSubjectName,
                    getSubjectList,
                  ),
                ],
              ),
            ),
          ),
          _buildSheetFooter(
            ctx,
            lp,
            getClassId,
            getSubjectId,
            getClassName,
            getSubjectName,
          ),
        ],
      ),
    );
  }

  Widget _buildClassSelection(
    StateSetter setSS,
    LanguageProvider lp,
    String? Function() getClassId,
    void Function(String?) setClassId,
    void Function(String?) setClassName,
    void Function(String?) setSubjectId,
    void Function(List<dynamic>) setSubjectList,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: classList.map((c) {
        final cid = c['id']?.toString();
        final cname = c['name'] ?? c['nama'] ?? '-';
        return buildSheetChip(cname, getClassId() == cid, () async {
          setSS(() {
            setClassId(cid);
            setClassName(cname);
            setSubjectId(null);
            setSubjectList([]);
          });
          if (cid != null) {
            try {
              // Fetch only subjects THIS teacher teaches for the selected
              // class. `/teacher/:id/subjects?class_id=` merges assigned
              // subjects with scheduled subjects (see TeacherController
              // @getSubjects) and returns `{success, data: [...]}`.
              final r = await _dio.get(
                '/teacher/$teacherId/subjects',
                queryParameters: {'class_id': cid},
              );
              final raw = r.data;
              final list = raw is List
                  ? raw
                  : (raw is Map && raw['data'] is List
                        ? raw['data'] as List
                        : <dynamic>[]);
              setSS(() => setSubjectList(list));
            } catch (_) {}
          }
        });
      }).toList(),
    );
  }

  Widget _buildSubjectSelection(
    LanguageProvider lp,
    String? Function() getClassId,
    String? Function() getSubjectId,
    void Function(String?) setSubjectId,
    void Function(String?) setSubjectName,
    List<dynamic> Function() getSubjectList,
  ) {
    final subjectList = getSubjectList();
    if (subjectList.isEmpty) {
      return Text(
        getClassId() == null
            ? lp.getTranslatedText({
                'en': 'Please select a class first',
                'id': 'Pilih kelas terlebih dahulu',
              })
            : lp.getTranslatedText({
                'en': 'No subjects available',
                'id': 'Tidak ada mapel tersedia',
              }),
        style: TextStyle(
          fontSize: 13,
          color: ColorUtils.slate500,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: subjectList.map((s) {
        final sid = s['id']?.toString();
        final sname = s['name'] ?? s['nama'] ?? '-';
        return buildSheetChip(sname, getSubjectId() == sid, () {
          setSubjectId(sid);
          setSubjectName(sname);
        });
      }).toList(),
    );
  }

  Widget _buildSheetHeader(BuildContext ctx, LanguageProvider lp) {
    return buildSheetHeader(
      ctx,
      lp.getTranslatedText({'en': 'New Activity', 'id': 'Kegiatan Baru'}),
      Icons.add_rounded,
    );
  }

  Widget _buildSheetFooter(
    BuildContext ctx,
    LanguageProvider lp,
    String? Function() getClassId,
    String? Function() getSubjectId,
    String? Function() getClassName,
    String? Function() getSubjectName,
  ) {
    final isEnabled = getClassId() != null && getSubjectId() != null;
    return buildSheetFooter(
      ctx,
      lp.getTranslatedText({'en': 'Cancel', 'id': 'Batal'}),
      lp.getTranslatedText({'en': 'Continue', 'id': 'Lanjutkan'}),
      isEnabled,
      () {
        Navigator.pop(ctx);
        showActivityTypeSelector(
          getClassId()!,
          getClassName() ?? '',
          getSubjectId()!,
          getSubjectName() ?? '',
          lp,
        );
      },
    );
  }

  void showActivityTypeSelector(
    String classId,
    String className,
    String subjectId,
    String subjectName,
    LanguageProvider lp, {
    String? lessonHourId,
  });

  void showFilterDialog(LanguageProvider lp);

  List<dynamic> get classList;
  @override
  Color get primaryColor;
  String get teacherId;
  String get teacherName;
  bool get isHomeroomView;
}
