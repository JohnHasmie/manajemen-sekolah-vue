// Add / Edit activity form sheet — Frames B & C from
// `_design/teacher_class_activity_mockup.html`.
//
// One sheet, two modes:
//   • Add (Frame B): all fields editable, primary = "Simpan".
//   • Edit (Frame C): kelas + mapel rendered as locked pills (history
//     consistency); the rest editable; primary = "Simpan".
//
// Wraps the shared AppBottomSheet so the brand chrome (gradient
// header + title + close + Samsung-safe footer) comes for free.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';
import 'package:manajemensekolah/core/widgets/modern_date_picker.dart';
import 'package:manajemensekolah/features/class_activity/data/activity_schedule_options.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_material_selector.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';

class ActivityFormResult {
  final Map<String, dynamic> payload;
  const ActivityFormResult(this.payload);
}

/// Public entrypoint. Returns the saved payload (with the user's
/// inputs merged on top of `initial`) when the teacher taps Simpan,
/// or null when the sheet is dismissed.
///
/// [schedules] is the teacher's own teaching schedule (the raw list the
/// teacher-summary endpoint returns). When provided, the Mapel picker
/// is scoped to subjects the teacher actually teaches (in the selected
/// class, when one is chosen) and the WAKTU field becomes a
/// lesson-hour ("Jam ke-N") picker for the selected class + day instead
/// of a free clock. This is the same per-class / per-day / lesson-hour
/// source the Jadwal screen uses — see [ActivityScheduleOptions].
Future<ActivityFormResult?> showActivityFormSheet({
  required BuildContext context,
  Map<String, dynamic>? initial,
  required List<Map<String, dynamic>> classes,
  required List<Map<String, dynamic>> subjects,
  required Future<void> Function(Map<String, dynamic> payload) onSave,
  List<dynamic> schedules = const [],
}) {
  final isEdit =
      initial != null && (initial['id']?.toString().isNotEmpty ?? false);
  return AppBottomSheet.show<ActivityFormResult>(
    context: context,
    title: isEdit ? kClaActEditActivity.tr : kClaActAddActivity.tr,
    subtitle: isEdit
        ? kClaActEditActivitySubtitle.tr
        : kClaActAddActivitySubtitle.tr,
    icon: isEdit ? Icons.edit_rounded : Icons.add_circle_outline_rounded,
    primaryColor: ColorUtils.getRoleColor('guru'),
    contentPadding: EdgeInsets.zero,
    content: _ActivityFormBody(
      initial: initial ?? const {},
      isEdit: isEdit,
      classes: classes,
      subjects: subjects,
      schedules: schedules,
      onSave: onSave,
    ),
  );
}

class _ActivityFormBody extends StatefulWidget {
  final Map<String, dynamic> initial;
  final bool isEdit;
  final List<Map<String, dynamic>> classes;
  final List<Map<String, dynamic>> subjects;

  /// Teacher's teaching schedule — drives the scoped Mapel + Jam
  /// pickers. Empty when the caller has no schedule context (the form
  /// then falls back to the passed-in [subjects] list and the legacy
  /// free clock so it never hard-breaks).
  final List<dynamic> schedules;
  final Future<void> Function(Map<String, dynamic> payload) onSave;

  const _ActivityFormBody({
    required this.initial,
    required this.isEdit,
    required this.classes,
    required this.subjects,
    required this.schedules,
    required this.onSave,
  });

  @override
  State<_ActivityFormBody> createState() => _ActivityFormBodyState();
}

class _ActivityFormBodyState extends State<_ActivityFormBody> {
  late String? _classId;
  late String? _subjectId;
  late String _type;
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late DateTime _date;
  late TimeOfDay? _time;

  /// Exact `lesson_hour_id` UUID of the picked jam-pelajaran slot.
  /// Carried into the payload so the schedule screen can track
  /// per-hour fill state. Null when the teacher hasn't picked a slot
  /// (or no schedule context was supplied).
  String? _lessonHourId;
  bool _saving = false;

  // Fix-AA — Bab + Sub-bab pickers. Optional; if subject picked, we
  // fetch the chapter list once and the sub-chapter list on chapter
  // tap. Both fields are nullable in the payload so legacy activities
  // without chapter linkage continue to save unchanged.
  String? _chapterId;
  String? _subChapterId;
  List<dynamic> _chapters = const [];
  List<dynamic> _subChapters = const [];
  bool _loadingChapters = false;
  bool _loadingSubChapters = false;

  static List<_TypeOption> get _types => <_TypeOption>[
    _TypeOption(
      'tugas',
      'Tugas',
      kClaActTypeAssignmentDesc.tr,
      Icons.assignment_turned_in_rounded,
    ),
    _TypeOption(
      'aktivitas',
      'Aktivitas',
      kClaActTypeActivityDesc.tr,
      Icons.groups_2_rounded,
    ),
    _TypeOption('ujian', 'Ujian', kClaActTypeExamDesc.tr, Icons.science_rounded),
    _TypeOption(
      'catatan',
      'Catatan',
      kClaActTypeNoteDesc.tr,
      Icons.sticky_note_2_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _classId = (i['class_id'] ?? i['kelas_id'])?.toString();
    _subjectId = (i['subject_id'] ?? i['mata_pelajaran_id'])?.toString();
    _type = _normalizeType(i['type'] ?? i['tipe'] ?? i['jenis']);
    _titleCtrl = TextEditingController(
      text: (i['title'] ?? i['judul'] ?? '').toString(),
    );
    _descCtrl = TextEditingController(
      text: (i['description'] ?? i['deskripsi'] ?? '').toString(),
    );
    final d = DateTime.tryParse((i['date'] ?? '').toString()) ?? DateTime.now();
    _date = d;
    final t = (i['time'] ?? i['jam'] ?? '').toString();
    _time = _parseTime(t);
    _lessonHourId = (i['lesson_hour_id'] ?? i['jam_pelajaran_id'])?.toString();

    // Hydrate chapter / sub-chapter from initial payload (edit mode).
    _chapterId = (i['chapter_id'] ?? i['bab_id'])?.toString();
    _subChapterId = (i['sub_chapter_id'] ?? i['sub_bab_id'])?.toString();
    if (_subjectId != null && _subjectId!.isNotEmpty) {
      // Schedule the first fetch after build so setState is safe.
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadChapters());
    }
  }

  /// Fetches chapters for the currently selected subject. Single-shot;
  /// re-runs whenever `_subjectId` changes via `_pickSubject`. Resets
  /// the selected chapter/sub-chapter when called for a new subject.
  Future<void> _loadChapters() async {
    final subjectId = _subjectId;
    if (subjectId == null || subjectId.isEmpty) return;
    setState(() => _loadingChapters = true);
    try {
      final chapters = await getIt<ApiSubjectService>().getChapterMaterials(
        subjectId: subjectId,
      );
      if (!mounted) return;
      setState(() {
        _chapters = chapters;
        _loadingChapters = false;
      });
      // If edit mode preselected a chapter, fetch its sub-chapter list.
      if (_chapterId != null && _chapterId!.isNotEmpty) {
        _loadSubChapters();
      }
    } catch (e) {
      AppLogger.error('class_activity', 'load chapters: $e');
      if (!mounted) return;
      setState(() {
        _chapters = const [];
        _loadingChapters = false;
      });
    }
  }

  /// Fetches sub-chapters for the currently selected chapter. Triggered
  /// by `_onChapterSelected` and by post-load in edit mode.
  Future<void> _loadSubChapters() async {
    final chapterId = _chapterId;
    if (chapterId == null || chapterId.isEmpty) {
      setState(() => _subChapters = const []);
      return;
    }
    setState(() => _loadingSubChapters = true);
    try {
      final subs = await getIt<ApiSubjectService>().getSubChapterMaterials(
        chapterId: chapterId,
      );
      if (!mounted) return;
      setState(() {
        _subChapters = subs;
        _loadingSubChapters = false;
      });
    } catch (e) {
      AppLogger.error('class_activity', 'load sub-chapters: $e');
      if (!mounted) return;
      setState(() {
        _subChapters = const [];
        _loadingSubChapters = false;
      });
    }
  }

  void _onChapterSelected(String id) {
    if (id == _chapterId) return;
    setState(() {
      _chapterId = id;
      _subChapterId = null;
      _subChapters = const [];
    });
    _loadSubChapters();
  }

  void _onSubChapterSelected(String id) {
    setState(() {
      _subChapterId = (id == _subChapterId) ? null : id;
    });
  }

  /// Backend returns chapters under various legacy keys depending on
  /// the calling endpoint (`/bab-material` uses `chapter_title` /
  /// `judul_bab`; older callers fell back to `judul` / `title` /
  /// `name`). Match the canonical extractor in
  /// `activity_name_helper_mixin.dart` so labels never come back empty.
  String _chapterLabel(dynamic c) {
    final raw = c as Map;
    return (raw['chapter_title'] ??
            raw['judul_bab'] ??
            raw['nama'] ??
            raw['judul'] ??
            raw['title'] ??
            raw['name'] ??
            '-')
        .toString();
  }

  String _subChapterLabel(dynamic s) {
    final raw = s as Map;
    return (raw['sub_chapter_title'] ??
            raw['judul_sub_bab'] ??
            raw['nama'] ??
            raw['judul'] ??
            raw['title'] ??
            raw['name'] ??
            '-')
        .toString();
  }

  /// Maps the various legacy/EN type labels the backend may store
  /// (`assignment`, `material`, `exam`, `quiz`, …) onto the four
  /// canonical form tiles (`tugas`, `aktivitas`, `ujian`, `catatan`)
  /// so the current type pre-selects in edit mode.
  String _normalizeType(dynamic raw) {
    final s = (raw ?? '').toString().toLowerCase().trim();
    switch (s) {
      case 'tugas':
      case 'assignment':
      case 'pr':
      case 'homework':
        return 'tugas';
      case 'aktivitas':
      case 'activity':
      case 'material':
      case 'materi':
      case 'diskusi':
      case 'discussion':
        return 'aktivitas';
      case 'ujian':
      case 'exam':
      case 'quiz':
      case 'test':
      case 'kuis':
      case 'penilaian':
        return 'ujian';
      case 'catatan':
      case 'note':
      case 'notes':
      case 'umum':
        return 'catatan';
      default:
        return 'tugas';
    }
  }

  TimeOfDay? _parseTime(String raw) {
    if (raw.isEmpty) return null;
    final norm = raw.replaceAll('.', ':');
    final parts = norm.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  /// True when the form has the teacher's schedule context and can
  /// therefore scope the Mapel + Jam pickers. When false the form keeps
  /// the legacy behaviour (passed-in `subjects` list + free clock) so
  /// callers without schedule context never hard-break.
  bool get _hasScheduleContext => widget.schedules.isNotEmpty;

  /// Subjects offered in the Mapel picker. With schedule context we
  /// only show subjects the teacher teaches — narrowed to the selected
  /// class when one is chosen (Bug 1a). Without it we fall back to the
  /// caller-supplied list.
  List<Map<String, dynamic>> get _scopedSubjects {
    if (!_hasScheduleContext) return widget.subjects;
    final scoped = ActivityScheduleOptions.subjectsFor(
      widget.schedules,
      classId: _classId,
    );
    // Edit mode: ensure the already-selected subject stays visible even
    // if it's not in the freshly derived list (e.g. an old assignment
    // the teacher no longer teaches), so the locked pill still labels.
    if (_subjectId != null &&
        _subjectId!.isNotEmpty &&
        !scoped.any((s) => (s['id'] ?? '').toString() == _subjectId)) {
      scoped.add({'id': _subjectId, 'name': _subjectLabel()});
    }
    return scoped;
  }

  /// Lesson-hour ("Jam ke-N") options for the selected class on the
  /// selected date's weekday (Bug 1b). Empty when no class is picked or
  /// no schedule context is available.
  List<ActivityLessonHourOption> get _lessonHourOptions {
    if (!_hasScheduleContext) return const [];
    return ActivityScheduleOptions.lessonHoursFor(
      widget.schedules,
      classId: _classId,
      date: _date,
      subjectId: _subjectId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = ColorUtils.getRoleColor('guru');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label(kClaActClassAndSubject.tr),
              Row(
                children: [
                  Expanded(
                    child: _picker(
                      icon: Icons.school_rounded,
                      label: _classLabel(),
                      enabled: !widget.isEdit && !_saving,
                      onTap: _pickClass,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _picker(
                      icon: Icons.menu_book_rounded,
                      label: _subjectLabel(),
                      enabled: !widget.isEdit && !_saving,
                      onTap: _pickSubject,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _label(kClaActActivityType.tr),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.6,
                children: _types.map((t) => _typeTile(t, primary)).toList(),
              ),
              const SizedBox(height: 12),
              // Bab + Sub-bab pickers — only shown when a Mapel has been
              // picked (otherwise the chapter list has nothing to query).
              // Both fields are optional in the payload.
              if (_subjectId != null && _subjectId!.isNotEmpty) ...[
                _label(kClaActChapterOptional.tr),
                ActivityChapterSelector(
                  chapters: _chapters,
                  isLoading: _loadingChapters,
                  selectedChapterId: _chapterId,
                  onChapterSelected: _onChapterSelected,
                  getChapterName: _chapterLabel,
                ),
                if (_chapterId != null) ...[
                  const SizedBox(height: 10),
                  _label(kClaActSubChapterOptional.tr),
                  if (_loadingSubChapters)
                    Container(
                      height: 32,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: List.generate(
                          3,
                          (_) => Container(
                            margin: const EdgeInsets.only(right: 8),
                            width: 72,
                            height: 28,
                            decoration: BoxDecoration(
                              color: ColorUtils.slate100,
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    )
                  else if (_subChapters.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                      decoration: BoxDecoration(
                        color: ColorUtils.slate50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 14,
                            color: ColorUtils.slate400,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            kClaActNoSubChaptersAvailable.tr,
                            style: TextStyle(
                              fontSize: 12,
                              color: ColorUtils.slate500,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _subChapters.map((sub) {
                        final id = (sub as Map)['id'].toString();
                        final isOn = id == _subChapterId;
                        return ChoiceChip(
                          label: Text(_subChapterLabel(sub)),
                          selected: isOn,
                          onSelected: (_) => _onSubChapterSelected(id),
                          showCheckmark: false,
                          selectedColor: primary.withValues(alpha: 0.12),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            color: isOn ? primary : ColorUtils.slate600,
                            fontWeight: isOn
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                          side: BorderSide(
                            color: isOn
                                ? primary.withValues(alpha: 0.3)
                                : ColorUtils.slate200,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 0,
                          ),
                        );
                      }).toList(),
                    ),
                ],
                const SizedBox(height: 12),
              ],
              _label(kClaActTitle.tr),
              _textField(_titleCtrl, hint: kClaActTitleHint.tr),
              const SizedBox(height: 12),
              _label(kClaActDateAndTime.tr),
              Row(
                children: [
                  Expanded(
                    child: _picker(
                      icon: Icons.calendar_today_rounded,
                      label: DateFormat('EEE, d MMM', 'id_ID').format(_date),
                      enabled: !_saving,
                      onTap: _pickDate,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _picker(
                      icon: Icons.schedule_rounded,
                      label: _timeLabel(),
                      enabled: !_saving,
                      onTap: _pickTime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _label(kClaActDescription.tr),
              _textField(
                _descCtrl,
                hint: kClaActDescriptionHint.tr,
                minLines: 3,
                maxLines: 6,
              ),
            ],
          ),
        ),
        BottomSheetFooter(
          primaryLabel: _saving ? 'Menyimpan…' : 'Simpan',
          primaryColor: primary,
          primaryEnabled: !_saving,
          onPrimary: _onSave,
          onSecondary: _saving ? () {} : () => AppNavigator.pop(context),
        ),
      ],
    );
  }

  Widget _label(String s) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      s.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: ColorUtils.slate700,
        letterSpacing: 0.4,
      ),
    ),
  );

  Widget _picker({
    required IconData icon,
    required String label,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: ColorUtils.slate200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: enabled ? ColorUtils.slate500 : ColorUtils.slate300,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: enabled ? ColorUtils.slate800 : ColorUtils.slate500,
                  ),
                ),
              ),
              if (enabled)
                Icon(Icons.arrow_drop_down_rounded, color: ColorUtils.slate400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeTile(_TypeOption t, Color primary) {
    final on = _type == t.key;
    final tint = _typeTint(t.key);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _saving ? null : () => setState(() => _type = t.key),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: on ? tint.bg : Colors.white,
            border: Border.all(
              color: on ? tint.fg : ColorUtils.slate200,
              width: on ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: on ? tint.fg : ColorUtils.slate100,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(
                  t.icon,
                  size: 16,
                  color: on ? Colors.white : ColorUtils.slate500,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: on ? tint.fg : ColorUtils.slate800,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      t.desc,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: ColorUtils.slate500,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ({Color bg, Color fg}) _typeTint(String key) {
    switch (key) {
      case 'tugas':
        return (bg: ColorUtils.corporateBlue100, fg: ColorUtils.info600);
      case 'aktivitas':
        // Tailwind violet-100 — no ColorUtils tint token at this shade yet.
        return (bg: const Color(0xFFEDE9FE), fg: ColorUtils.violet700);
      case 'ujian':
        return (bg: ColorUtils.warningLight, fg: ColorUtils.warning600);
      case 'catatan':
      default:
        return (bg: ColorUtils.slate100, fg: ColorUtils.slate600);
    }
  }

  Widget _textField(
    TextEditingController c, {
    required String hint,
    int minLines = 1,
    int maxLines = 1,
  }) {
    return TextField(
      controller: c,
      enabled: !_saving,
      minLines: minLines,
      maxLines: maxLines,
      style: TextStyle(
        fontSize: 12.5,
        color: ColorUtils.slate800,
        fontWeight: FontWeight.w500,
        height: 1.4,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 12, color: ColorUtils.slate400),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ColorUtils.slate200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ColorUtils.slate200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: ColorUtils.getRoleColor('guru'),
            width: 1.5,
          ),
        ),
      ),
    );
  }

  String _classLabel() {
    if (_classId == null) return kClaActChooseClass.tr;
    for (final c in widget.classes) {
      if ((c['id'] ?? '').toString() == _classId) {
        return (c['name'] ?? '-').toString();
      }
    }
    return (widget.initial['class_name'] ?? widget.initial['kelas_nama'] ?? '-')
        .toString();
  }

  String _subjectLabel() {
    if (_subjectId == null) return kClaActChooseSubject.tr;
    // Look in the caller-supplied list first, then the schedule-derived
    // subjects (computed inline here — NOT via `_scopedSubjects`, which
    // calls back into this method for its edit-mode fallback).
    for (final s in widget.subjects) {
      if ((s['id'] ?? '').toString() == _subjectId) {
        return (s['name'] ?? '-').toString();
      }
    }
    if (_hasScheduleContext) {
      final derived = ActivityScheduleOptions.subjectsFor(widget.schedules);
      for (final s in derived) {
        if ((s['id'] ?? '').toString() == _subjectId) {
          return (s['name'] ?? '-').toString();
        }
      }
    }
    return (widget.initial['subject_name'] ??
            widget.initial['mata_pelajaran_nama'] ??
            '-')
        .toString();
  }

  Future<void> _pickClass() async {
    final picked = await _showOptionSheet(
      title: kClaActChooseClass.tr,
      options: widget.classes,
    );
    if (picked == null || picked == _classId) return;
    setState(() {
      _classId = picked;
      // With schedule context the Mapel + Jam options are class-scoped,
      // so a subject/jam picked for the previous class is no longer
      // valid — clear them (and the dependent chapter pickers).
      if (_hasScheduleContext) {
        _subjectId = null;
        _lessonHourId = null;
        _time = null;
        _chapterId = null;
        _subChapterId = null;
        _chapters = const [];
        _subChapters = const [];
      }
    });
  }

  Future<void> _pickSubject() async {
    final options = _scopedSubjects;
    if (_hasScheduleContext && options.isEmpty) {
      // No class chosen yet, or the teacher teaches nothing in it.
      SnackBarUtils.showError(
        context,
        _classId == null
            ? kClaActPickClassFirst.tr
            : kClaActNoTaughtSubjects.tr,
      );
      return;
    }
    final picked = await _showOptionSheet(
      title: kClaActChooseSubject.tr,
      options: options,
    );
    if (picked != null && picked != _subjectId) {
      setState(() {
        _subjectId = picked;
        // Reset Bab + Sub-bab whenever the subject changes — the
        // chapter list is subject-scoped so the previous selection
        // is no longer valid.
        _chapterId = null;
        _subChapterId = null;
        _chapters = const [];
        _subChapters = const [];
        // The jam options are also subject-scoped (a slot belongs to a
        // specific class+subject pairing), so clear a previously picked
        // lesson hour that may no longer apply.
        if (_hasScheduleContext) {
          _lessonHourId = null;
          _time = null;
        }
      });
      _loadChapters();
    }
  }

  Future<String?> _showOptionSheet({
    required String title,
    required List<Map<String, dynamic>> options,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ColorUtils.slate300,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: ColorUtils.slate900,
                    ),
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (_, i) {
                    final o = options[i];
                    return ListTile(
                      title: Text((o['name'] ?? '-').toString()),
                      onTap: () =>
                          Navigator.of(context).pop((o['id'] ?? '').toString()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showModernDatePicker(
      context: context,
      initialDate: _date,
      title: kClaActChooseDate.tr,
    );
    if (picked == null) return;
    final weekdayChanged = picked.weekday != _date.weekday;
    setState(() {
      _date = picked;
      // The jam-pelajaran options are per-weekday, so a previously
      // picked "Jam ke-N" no longer applies once the weekday changes —
      // clear it so the teacher re-picks from the new day's slots.
      if (_hasScheduleContext && weekdayChanged) {
        _lessonHourId = null;
        _time = null;
      }
    });
  }

  /// Label for the WAKTU picker. With schedule context it shows the
  /// picked "Jam ke-N · HH:MM–HH:MM" (matching the chosen lesson hour),
  /// otherwise the legacy clock value.
  String _timeLabel() {
    if (_hasScheduleContext) {
      final opts = _lessonHourOptions;
      // Prefer matching by the exact lesson_hour_id so the label tracks
      // the picked slot precisely (e.g. when prefilled from a Jadwal
      // card). Fall back to matching by start time.
      ActivityLessonHourOption? match;
      for (final o in opts) {
        if (_lessonHourId != null &&
            o.lessonHourId == _lessonHourId &&
            (o.lessonHourId ?? '').isNotEmpty) {
          match = o;
          break;
        }
      }
      if (match == null && _time != null) {
        final hhmm =
            '${_time!.hour.toString().padLeft(2, '0')}:'
            '${_time!.minute.toString().padLeft(2, '0')}';
        for (final o in opts) {
          if (o.timeValue == hhmm) {
            match = o;
            break;
          }
        }
      }
      if (match != null) return match.label;
      return kClaActChooseLessonHour.tr;
    }
    return _time == null ? kClaActChooseTime.tr : _time!.format(context);
  }

  Future<void> _pickTime() async {
    // Without schedule context, keep the legacy free clock so callers
    // that don't pass schedules still work.
    if (!_hasScheduleContext) {
      final picked = await showTimePicker(
        context: context,
        initialTime: _time ?? TimeOfDay.now(),
      );
      if (picked != null) setState(() => _time = picked);
      return;
    }

    // Schedule-scoped jam-pelajaran picker (Bug 1b).
    if (_classId == null || _classId!.isEmpty) {
      SnackBarUtils.showError(context, kClaActPickClassFirst.tr);
      return;
    }
    final opts = _lessonHourOptions;
    final picked = await _showLessonHourSheet(opts);
    if (picked != null) {
      setState(() {
        _lessonHourId = picked.lessonHourId;
        _time = _parseTime(picked.timeValue);
      });
    }
  }

  /// Bottom sheet listing the "Jam ke-N" lesson-hour slots for the
  /// selected class + day. Mirrors [_showOptionSheet]'s chrome. Returns
  /// the chosen option, or null on dismiss. Shows an empty-state row
  /// when the day has no slots for that class.
  Future<ActivityLessonHourOption?> _showLessonHourSheet(
    List<ActivityLessonHourOption> options,
  ) {
    return showModalBottomSheet<ActivityLessonHourOption>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ColorUtils.slate300,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    kClaActChooseLessonHour.tr,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: ColorUtils.slate900,
                    ),
                  ),
                ),
              ),
              if (options.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: ColorUtils.slate400,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          kClaActNoLessonHoursForDay.tr,
                          style: TextStyle(
                            fontSize: 12,
                            color: ColorUtils.slate500,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (_, i) {
                      final o = options[i];
                      final selected =
                          (o.lessonHourId ?? '').isNotEmpty &&
                          o.lessonHourId == _lessonHourId;
                      return ListTile(
                        leading: Icon(
                          Icons.schedule_rounded,
                          size: 18,
                          color: selected
                              ? ColorUtils.getRoleColor('guru')
                              : ColorUtils.slate400,
                        ),
                        title: Text(o.label),
                        trailing: selected
                            ? Icon(
                                Icons.check_rounded,
                                size: 18,
                                color: ColorUtils.getRoleColor('guru'),
                              )
                            : null,
                        onTap: () => Navigator.of(context).pop(o),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onSave() async {
    if (_saving) return;
    if (_classId == null || _subjectId == null) {
      SnackBarUtils.showError(context, 'Pilih kelas dan mapel terlebih dahulu');
      return;
    }
    if (_titleCtrl.text.trim().isEmpty) {
      SnackBarUtils.showError(context, 'Judul tidak boleh kosong');
      return;
    }
    setState(() => _saving = true);
    final payload = <String, dynamic>{
      ...widget.initial,
      'class_id': _classId,
      'subject_id': _subjectId,
      'type': _type,
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'date': DateFormat('yyyy-MM-dd').format(_date),
      if (_time != null)
        'time':
            '${_time!.hour.toString().padLeft(2, '0')}:'
            '${_time!.minute.toString().padLeft(2, '0')}',
      // Tag the activity with the picked jam-pelajaran slot so the
      // schedule screen can track per-hour fill state.
      if (_lessonHourId != null && _lessonHourId!.isNotEmpty)
        'lesson_hour_id': _lessonHourId,
      // Bab + Sub-bab are optional. Send `null` when cleared so the
      // backend treats it as "remove the link" on update.
      'chapter_id': _chapterId,
      'sub_chapter_id': _subChapterId,
    };
    try {
      await widget.onSave(payload);
      if (mounted) AppNavigator.pop(context, ActivityFormResult(payload));
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, 'Gagal menyimpan: $e');
        setState(() => _saving = false);
      }
    }
  }
}

class _TypeOption {
  final String key;
  final String label;
  final String desc;
  final IconData icon;
  const _TypeOption(this.key, this.label, this.desc, this.icon);
}
