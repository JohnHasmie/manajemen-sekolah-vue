// Dialog form for AI-generating a lesson plan (RPP).
// Extracted from teacher_lesson_plan_screen.dart to reduce file size.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/academic_year_utils.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/filter_chip_grid.dart';
import 'package:manajemensekolah/core/widgets/filter_section_header.dart';
import 'package:manajemensekolah/core/widgets/form_field_section.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/generate_lesson_plan_api_mixin.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/generate_lesson_plan_data_mixin.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/generate_lesson_plan_form_mixin.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/generate_lesson_plan_layout_mixin.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/generate_lesson_plan_ui_mixin.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/generate_lesson_plan_utils_mixin.dart';
import 'package:manajemensekolah/features/subjects/domain/models/subject.dart';

class GenerateLessonPlanFormDialog extends ConsumerStatefulWidget {
  final String teacherId;
  final VoidCallback onSaved;

  const GenerateLessonPlanFormDialog({
    super.key,
    required this.teacherId,
    required this.onSaved,
  });

  @override
  ConsumerState<GenerateLessonPlanFormDialog> createState() =>
      _GenerateLessonPlanFormDialogState();
}

class _GenerateLessonPlanFormDialogState
    extends ConsumerState<GenerateLessonPlanFormDialog>
    with
        GenerateLessonPlanUtilsMixin,
        GenerateLessonPlanDataMixin,
        GenerateLessonPlanApiMixin,
        GenerateLessonPlanUiMixin,
        GenerateLessonPlanFormMixin,
        GenerateLessonPlanLayoutMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _academicYearController = TextEditingController();

  String? _selectedSubjectId;
  String? _selectedClassId;
  String? _selectedChapterId;
  String? _selectedSubChapterId;
  String? _selectedSemester = 'Ganjil';
  bool _isAutoGenerating = false;
  String _generationStatus = '';

  List<dynamic> _subjectList = [];
  List<dynamic> _classList = [];
  List<dynamic> _chapterList = [];
  List<dynamic> _subChapterList = [];

  /// Chip options for tahun ajaran — same window the manual form uses.
  late final List<String> _academicYearOptions;
  late String _selectedAcademicYear;

  @override
  void initState() {
    super.initState();
    loadSubjectsByTeacher();
    _academicYearOptions = academicYearChipOptions();
    _selectedAcademicYear = currentAcademicYearString();
    _academicYearController.text = _selectedAcademicYear;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _academicYearController.dispose();
    super.dispose();
  }

  // Getters for mixin requirements
  @override
  GlobalKey<FormState> get formKey => _formKey;
  @override
  TextEditingController get titleController => _titleController;
  @override
  TextEditingController get academicYearController => _academicYearController;
  @override
  String? get selectedSubjectId => _selectedSubjectId;
  @override
  String? get selectedClassId => _selectedClassId;
  @override
  String? get selectedChapterId => _selectedChapterId;
  @override
  String? get selectedSubChapterId => _selectedSubChapterId;
  @override
  String? get selectedSemester => _selectedSemester;
  @override
  bool get isAutoGenerating => _isAutoGenerating;
  @override
  set isAutoGenerating(bool value) => _isAutoGenerating = value;
  @override
  String get generationStatus => _generationStatus;
  @override
  set generationStatus(String value) => _generationStatus = value;
  @override
  List<dynamic> get subjectList => _subjectList;
  @override
  set subjectList(List<dynamic> value) => _subjectList = value;
  @override
  List<dynamic> get classList => _classList;
  @override
  set classList(List<dynamic> value) => _classList = value;
  @override
  List<dynamic> get chapterList => _chapterList;
  @override
  set chapterList(List<dynamic> value) => _chapterList = value;
  @override
  List<dynamic> get subChapterList => _subChapterList;
  @override
  set subChapterList(List<dynamic> value) => _subChapterList = value;

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
    final primaryColor = ColorUtils.getRoleColor('guru');
    final mediaHeight = MediaQuery.of(context).size.height;

    // isScrollControlled: true on the parent showModalBottomSheet handles
    // keyboard avoidance automatically — no manual Padding(bottom: keyboardInset).
    return Container(
      constraints: BoxConstraints(maxHeight: mediaHeight * 0.92),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              buildHeaderSection(languageProvider, primaryColor),
              _buildFormSection(languageProvider, primaryColor),
              buildFooterSection(languageProvider, primaryColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormSection(
    LanguageProvider languageProvider,
    Color primaryColor,
  ) {
    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              FormTextField(
                label: languageProvider.getTranslatedText({
                  'en': 'Title',
                  'id': 'Judul',
                }),
                isRequired: true,
                controller: _titleController,
                hintText: languageProvider.getTranslatedText({
                  'en': 'Enter RPP title',
                  'id': 'Masukkan judul RPP',
                }),
                prefixIcon: Icons.title_rounded,
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Judul harus diisi'
                    : null,
              ),

              // Subject (chip select)
              FilterSectionHeader(
                title: languageProvider.getTranslatedText({
                  'en': 'Subject',
                  'id': 'Mata Pelajaran',
                }),
                icon: Icons.book_outlined,
                primaryColor: primaryColor,
                padding: const EdgeInsets.only(top: 8, bottom: 12),
              ),
              if (_subjectList.isEmpty)
                _buildLoadingChip(
                  languageProvider.getTranslatedText({
                    'en': 'Loading subjects...',
                    'id': 'Memuat mata pelajaran...',
                  }),
                )
              else
                FilterChipGrid<String>(
                  options: _subjectList.map((mp) {
                    final subj = Subject.fromJson(mp as Map<String, dynamic>);
                    return FilterOption(value: subj.id, label: subj.name);
                  }).toList(),
                  selectedValue: _selectedSubjectId,
                  onSelected: (value) {
                    setState(() {
                      _selectedSubjectId = value;
                      _selectedClassId = null;
                      _selectedChapterId = null;
                      _selectedSubChapterId = null;
                      _classList = [];
                      _chapterList = [];
                      _subChapterList = [];
                    });
                    if (value != null) {
                      loadClassesBySubject(value);
                      loadChaptersBySubject(value);
                    }
                  },
                  selectedColor: primaryColor,
                ),

              // Class (chip select, shown after subject selected)
              if (_selectedSubjectId != null) ...[
                FilterSectionHeader(
                  title: languageProvider.getTranslatedText({
                    'en': 'Class',
                    'id': 'Kelas',
                  }),
                  icon: Icons.class_outlined,
                  primaryColor: primaryColor,
                  padding: const EdgeInsets.only(top: 16, bottom: 12),
                ),
                if (_classList.isEmpty)
                  _buildLoadingChip(
                    languageProvider.getTranslatedText({
                      'en': 'Loading classes...',
                      'id': 'Memuat kelas...',
                    }),
                  )
                else
                  FilterChipGrid<String>(
                    options: _classList.map((c) {
                      final map = c as Map<String, dynamic>;
                      final id = map['id']?.toString() ?? '';
                      final name =
                          (map['name'] ??
                                  map['nama'] ??
                                  map['class_name'] ??
                                  'Tanpa Nama')
                              .toString();
                      return FilterOption(value: id, label: name);
                    }).toList(),
                    selectedValue: _selectedClassId,
                    onSelected: (value) {
                      setState(() {
                        _selectedClassId = value;
                      });
                    },
                    selectedColor: primaryColor,
                  ),
              ],

              // Semester (chip select)
              FilterSectionHeader(
                title: languageProvider.getTranslatedText({
                  'en': 'Semester',
                  'id': 'Semester',
                }),
                icon: Icons.event_note_rounded,
                primaryColor: primaryColor,
                padding: const EdgeInsets.only(top: 16, bottom: 12),
              ),
              FilterChipGrid<String>(
                options: const [
                  FilterOption(
                    value: 'Ganjil',
                    label: 'Ganjil',
                    icon: Icons.looks_one_rounded,
                  ),
                  FilterOption(
                    value: 'Genap',
                    label: 'Genap',
                    icon: Icons.looks_two_rounded,
                  ),
                ],
                selectedValue: _selectedSemester,
                onSelected: (value) {
                  setState(() {
                    _selectedSemester = value ?? 'Ganjil';
                  });
                },
                selectedColor: primaryColor,
              ),

              // Chapter (chip select, shown after subject selected)
              if (_selectedSubjectId != null) ...[
                FilterSectionHeader(
                  title: languageProvider.getTranslatedText({
                    'en': 'Chapter',
                    'id': 'Bab',
                  }),
                  icon: Icons.bookmark_border_rounded,
                  primaryColor: primaryColor,
                  padding: const EdgeInsets.only(top: 16, bottom: 12),
                ),
                if (_chapterList.isEmpty)
                  _buildLoadingChip(
                    languageProvider.getTranslatedText({
                      'en': 'Loading chapters...',
                      'id': 'Memuat bab...',
                    }),
                  )
                else
                  FilterChipGrid<String>(
                    options: _chapterList.map((c) {
                      final map = c as Map<String, dynamic>;
                      final id = map['id']?.toString() ?? '';
                      final name =
                          (map['judul_bab'] ??
                                  map['title'] ??
                                  map['judul'] ??
                                  'Tanpa Nama')
                              .toString();
                      return FilterOption(value: id, label: name);
                    }).toList(),
                    selectedValue: _selectedChapterId,
                    onSelected: (value) {
                      setState(() {
                        _selectedChapterId = value;
                        _selectedSubChapterId = null;
                        _subChapterList = [];
                      });
                      if (value != null) {
                        loadSubChaptersByChapter(value);
                      }
                    },
                    selectedColor: primaryColor,
                  ),
              ],

              // Sub Chapter (chip select, shown after chapter selected)
              if (_selectedChapterId != null && _subChapterList.isNotEmpty) ...[
                FilterSectionHeader(
                  title: languageProvider.getTranslatedText({
                    'en': 'Sub Chapter (optional)',
                    'id': 'Sub Bab (opsional)',
                  }),
                  icon: Icons.bookmark_add_outlined,
                  primaryColor: primaryColor,
                  padding: const EdgeInsets.only(top: 16, bottom: 12),
                ),
                FilterChipGrid<String>(
                  options: _subChapterList.map((s) {
                    final map = s as Map<String, dynamic>;
                    final id = map['id']?.toString() ?? '';
                    final name =
                        (map['judul_sub_bab'] ??
                                map['title'] ??
                                map['judul'] ??
                                'Tanpa Nama')
                            .toString();
                    return FilterOption(value: id, label: name);
                  }).toList(),
                  selectedValue: _selectedSubChapterId,
                  onSelected: (value) {
                    setState(() {
                      _selectedSubChapterId = value;
                    });
                  },
                  selectedColor: primaryColor,
                ),
              ],

              // Academic Year (chip select — default = current tahun ajaran)
              FilterSectionHeader(
                title: languageProvider.getTranslatedText({
                  'en': 'Academic Year',
                  'id': 'Tahun Ajaran',
                }),
                icon: Icons.calendar_today_rounded,
                primaryColor: primaryColor,
                padding: const EdgeInsets.only(top: 16, bottom: 12),
              ),
              FilterChipGrid<String>(
                options: _academicYearOptions
                    .map((y) => FilterOption(value: y, label: y))
                    .toList(),
                selectedValue: _selectedAcademicYear,
                onSelected: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedAcademicYear = value;
                    // Mirror into controller — the submit mixin reads
                    // `academicYearController.text` to build the payload.
                    _academicYearController.text = value;
                  });
                },
                selectedColor: primaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Loading indicator chip for async data.
  Widget _buildLoadingChip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: ColorUtils.slate400,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            text,
            style: TextStyle(fontSize: 12, color: ColorUtils.slate400),
          ),
        ],
      ),
    );
  }
}
