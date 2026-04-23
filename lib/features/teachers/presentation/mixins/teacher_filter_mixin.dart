import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/teachers/presentation/widgets/teacher_filter_sheet.dart';
import 'package:manajemensekolah/features/teachers/presentation/screens/admin_teacher_management_screen.dart';

mixin TeacherFilterMixin on ConsumerState<TeacherAdminScreen> {
  // Abstract bridge to state
  String? get selectedClassId;
  set selectedClassId(String? v);

  String? get selectedHomeroomFilter;
  set selectedHomeroomFilter(String? v);

  String? get selectedGender;
  set selectedGender(String? v);

  String? get selectedEmploymentStatus;
  set selectedEmploymentStatus(String? v);

  String? get selectedTeachingClassId;
  set selectedTeachingClassId(String? v);

  bool get hasActiveFilter;
  set hasActiveFilter(bool v);

  bool get showAllTeachers;
  set showAllTeachers(bool v);

  int get currentPage;
  set currentPage(int v);

  List<dynamic> get availableClass;
  List<dynamic> get availableGenders;
  List<dynamic> get availableEmploymentStatus;

  Future<void> loadData({bool resetPage = true, bool useCache = true});

  void checkActiveFilter() {
    setState(() {
      hasActiveFilter =
          selectedHomeroomFilter != null ||
          selectedClassId != null ||
          selectedGender != null ||
          selectedEmploymentStatus != null ||
          selectedTeachingClassId != null;
    });
  }

  void clearAllFilters() {
    setState(() {
      selectedClassId = null;
      selectedHomeroomFilter = null;
      selectedGender = null;
      selectedEmploymentStatus = null;
      selectedTeachingClassId = null;
      currentPage = 1;
      hasActiveFilter = false;
    });
    loadData();
  }

  List<Map<String, dynamic>> buildFilterChips(
    LanguageProvider languageProvider,
  ) {
    final List<Map<String, dynamic>> filterChips = [];
    _addHomeroomFilterChip(filterChips, languageProvider);
    _addGenderFilterChip(filterChips, languageProvider);
    _addEmploymentStatusFilterChip(filterChips, languageProvider);
    _addTeachingClassFilterChip(filterChips, languageProvider);
    return filterChips;
  }

  void _addHomeroomFilterChip(
    List<Map<String, dynamic>> chips,
    LanguageProvider languageProvider,
  ) {
    if (selectedHomeroomFilter == null) return;
    final statusText = selectedHomeroomFilter == 'wali_kelas'
        ? languageProvider.getTranslatedText({
            'en': 'Homeroom Teacher',
            'id': 'Wali Kelas',
          })
        : languageProvider.getTranslatedText({
            'en': 'Regular Teacher',
            'id': 'Guru Biasa',
          });
    chips.add({
      'label':
          '${languageProvider.getTranslatedText({'en': 'Status', 'id': 'Status'})}: $statusText',
      'onRemove': () {
        setState(() {
          selectedHomeroomFilter = null;
        });
        checkActiveFilter();
        loadData();
      },
    });
  }

  void _addGenderFilterChip(
    List<Map<String, dynamic>> chips,
    LanguageProvider languageProvider,
  ) {
    if (selectedGender == null) return;
    final genderText = selectedGender == 'L'
        ? languageProvider.getTranslatedText({'en': 'Male', 'id': 'Laki-laki'})
        : languageProvider.getTranslatedText({
            'en': 'Female',
            'id': 'Perempuan',
          });
    chips.add({
      'label':
          '${languageProvider.getTranslatedText({'en': 'Gender', 'id': 'Jenis Kelamin'})}: $genderText',
      'onRemove': () {
        setState(() {
          selectedGender = null;
        });
        checkActiveFilter();
        loadData();
      },
    });
  }

  void _addEmploymentStatusFilterChip(
    List<Map<String, dynamic>> chips,
    LanguageProvider languageProvider,
  ) {
    if (selectedEmploymentStatus == null) return;
    final statusLabel = availableEmploymentStatus.firstWhere(
      (s) => s['value'].toString() == selectedEmploymentStatus,
      orElse: () => {'label': selectedEmploymentStatus},
    )['label'];
    chips.add({
      'label':
          '${languageProvider.getTranslatedText({'en': 'Employment', 'id': 'Status Kepegawaian'})}: $statusLabel',
      'onRemove': () {
        setState(() {
          selectedEmploymentStatus = null;
        });
        checkActiveFilter();
        loadData();
      },
    });
  }

  void _addTeachingClassFilterChip(
    List<Map<String, dynamic>> chips,
    LanguageProvider languageProvider,
  ) {
    if (selectedTeachingClassId == null) return;
    final className = availableClass.firstWhere(
      (c) => c['id'].toString() == selectedTeachingClassId,
      orElse: () => {'name': selectedTeachingClassId},
    )['name'];
    chips.add({
      'label':
          '${languageProvider.getTranslatedText({'en': 'Teaching', 'id': 'Kelas Ajar'})}: $className',
      'onRemove': () {
        setState(() {
          selectedTeachingClassId = null;
        });
        checkActiveFilter();
        loadData();
      },
    });
  }

  void showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TeacherFilterSheet(
        initialHomeroom: selectedHomeroomFilter,
        initialGender: selectedGender,
        initialEmploymentStatus: selectedEmploymentStatus,
        initialTeachingClass: selectedTeachingClassId,
        initialShowAll: showAllTeachers,
        availableGenders: availableGenders,
        availableEmploymentStatus: availableEmploymentStatus,
        availableClass: availableClass,
        languageProvider: ref.read(languageRiverpod),
        onApply: (homeroom, gender, employment, teachingClass, showAll) {
          setState(() {
            selectedHomeroomFilter = homeroom;
            selectedGender = gender;
            selectedEmploymentStatus = employment;
            selectedTeachingClassId = teachingClass;
            showAllTeachers = showAll;
          });
          checkActiveFilter();
          loadData();
        },
      ),
    );
  }
}
