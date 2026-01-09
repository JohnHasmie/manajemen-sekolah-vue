import 'package:flutter/material.dart';
import 'package:manajemensekolah/providers/academic_year_provider.dart';
import 'package:manajemensekolah/screen/admin/components/promotion_step_indicator.dart';
import 'package:manajemensekolah/services/api_academic_services.dart';
import 'package:manajemensekolah/services/api_class_services.dart';
import 'package:manajemensekolah/services/api_settings_services.dart';
import 'package:manajemensekolah/services/api_teacher_services.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:provider/provider.dart';

class ClassPromotionWizard extends StatefulWidget {
  const ClassPromotionWizard({super.key});

  @override
  State<ClassPromotionWizard> createState() => _ClassPromotionWizardState();
}

class _ClassPromotionWizardState extends State<ClassPromotionWizard> {
  int _currentStep = 0;
  bool _isLoading = false;

  // Data
  List<dynamic> _classes = [];
  List<dynamic> _academicYears = [];
  List<dynamic> _students = [];
  List<dynamic> _targetClasses = [];
  List<dynamic> _teachers = [];
  final List<String> _availableGradeLevels = [];
  String? _schoolJenjang;

  // Selections
  String? _selectedSourceClassId;
  String? _selectedTargetYearId;
  String? _selectedTargetClassId;
  Set<String> _selectedStudentIds = {};
  bool _promoteAll = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _fetchTeachers();
    _loadSchoolSettings();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final yearsData = await ApiAcademicServices.getAcademicYears();

      // Get selected year from provider
      final academicYearProvider = Provider.of<AcademicYearProvider>(
        context,
        listen: false,
      );
      final selectedYear = academicYearProvider.selectedAcademicYear;

      List<dynamic> classesData = [];
      if (selectedYear != null) {
        // Fetch classes for selected year from dashboard
        final response = await ApiClassService.getClassPaginated(
          limit: 1000,
          academicYearId: selectedYear['id'].toString(),
        );
        classesData = response['data'] ?? [];
      } else {
        // Fallback to active year or all classes
        final activeYear = await ApiAcademicServices.getActiveAcademicYear();
        if (activeYear != null) {
          final response = await ApiClassService.getClassPaginated(
            limit: 1000,
            academicYearId: activeYear['id'].toString(),
          );
          classesData = response['data'] ?? [];
        } else {
          classesData = await ApiClassService().getClass();
        }
      }

      setState(() {
        _classes = classesData;
        _academicYears = yearsData;
      });
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStudents(String classId) async {
    setState(() => _isLoading = true);
    try {
      final students = await ApiClassService().getStudentsByClassId(classId);
      setState(() {
        _students = students;
        _selectedStudentIds = students
            .map((s) => s['id'].toString())
            .toSet(); // Default select all
      });
    } catch (e) {
      print('Error loading students: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTargetClasses(String yearId) async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiClassService.getClassPaginated(
        limit: 1000,
        academicYearId: yearId,
      );

      setState(() {
        if (response['data'] != null && response['data'] is List) {
          _targetClasses = response['data'];
        } else {
          _targetClasses = [];
        }
      });
    } catch (e) {
      print('Error loading target classes: $e');
      setState(() => _targetClasses = []);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchTeachers() async {
    try {
      final response = await ApiTeacherService.getTeachersPaginated(
        limit: 1000,
      );
      if (!mounted) return;
      setState(() {
        _teachers = response['data'] ?? [];
      });
    } catch (e) {
      print('Error loading teachers: $e');
    }
  }

  Future<void> _loadSchoolSettings() async {
    try {
      final settings = await ApiSettingsService.getSchoolSettings();
      if (!mounted) return;
      setState(() {
        _schoolJenjang = settings['jenjang'];
        _generateGradeLevels();
      });
    } catch (e) {
      print('Error loading school settings: $e');
      setState(() {
        _generateGradeLevels();
      });
    }
  }

  void _generateGradeLevels() {
    _availableGradeLevels.clear();
    int start = 1;
    int end = 12;

    if (_schoolJenjang != null) {
      final jenjang = _schoolJenjang!.toUpperCase();
      if (jenjang == 'SD') {
        start = 1;
        end = 6;
      } else if (jenjang == 'SMP') {
        start = 7;
        end = 9;
      } else if (jenjang == 'SMA' || jenjang == 'SMK') {
        start = 10;
        end = 12;
      }
    }

    for (int i = start; i <= end; i++) {
      _availableGradeLevels.add(i.toString());
    }
  }

  final PageController _pageController = PageController();

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();
    final steps = [
      languageProvider.getTranslatedText({'en': 'Source', 'id': 'Asal'}),
      languageProvider.getTranslatedText({'en': 'Students', 'id': 'Siswa'}),
      languageProvider.getTranslatedText({'en': 'Target', 'id': 'Tujuan'}),
      languageProvider.getTranslatedText({'en': 'Summary', 'id': 'Ringkasan'}),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          languageProvider.getTranslatedText({
            'en': 'Promote Class',
            'id': 'Naik Kelas',
          }),
        ),
        backgroundColor: ColorUtils.getRoleColor('admin'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            if (_currentStep > 0) {
              _onStepCancel();
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              PromotionStepIndicator(
                currentStep: _currentStep,
                totalSteps: steps.length,
                steps: steps,
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: NeverScrollableScrollPhysics(),
                  children: [
                    _buildStepContainer(_buildSourceStep(languageProvider)),
                    _buildStepContainer(_buildStudentsStep(languageProvider)),
                    _buildStepContainer(_buildTargetStep(languageProvider)),
                    _buildStepContainer(_buildSummaryStep(languageProvider)),
                  ],
                ),
              ),
              _buildBottomControls(languageProvider),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildStepContainer(Widget child) {
    return SingleChildScrollView(padding: EdgeInsets.all(16), child: child);
  }

  Widget _buildBottomControls(LanguageProvider languageProvider) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: Offset(0, -4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _onStepCancel,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  languageProvider.getTranslatedText({
                    'en': 'Back',
                    'id': 'Kembali',
                  }),
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
            ),
          if (_currentStep > 0) SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _onStepContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorUtils.getRoleColor('admin'),
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _currentStep == 3
                    ? languageProvider.getTranslatedText({
                        'en': 'Finish',
                        'id': 'Selesai',
                      })
                    : languageProvider.getTranslatedText({
                        'en': 'Continue',
                        'id': 'Lanjut',
                      }),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceStep(LanguageProvider languageProvider) {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: languageProvider.getTranslatedText({
              'en': 'Select Source Class',
              'id': 'Pilih Kelas Asal',
            }),
            border: OutlineInputBorder(),
          ),
          initialValue: _selectedSourceClassId,
          items: _classes.map<DropdownMenuItem<String>>((c) {
            return DropdownMenuItem(
              value: c['id'].toString(),
              child: Text(c['name'] ?? 'Unknown'),
            );
          }).toList(),
          onChanged: (val) {
            setState(() {
              _selectedSourceClassId = val;
            });
            if (val != null) _loadStudents(val);
          },
        ),
      ],
    );
  }

  Widget _buildStudentsStep(LanguageProvider languageProvider) {
    return Column(
      children: [
        CheckboxListTile(
          title: Text(
            languageProvider.getTranslatedText({
              'en': 'Select All',
              'id': 'Pilih Semua',
            }),
          ),
          value: _promoteAll,
          onChanged: (val) {
            setState(() {
              _promoteAll = val ?? true;
              if (_promoteAll) {
                _selectedStudentIds = _students
                    .map((s) => s['id'].toString())
                    .toSet();
              } else {
                _selectedStudentIds.clear();
              }
            });
          },
        ),
        Divider(),
        SizedBox(
          height: 300,
          child: ListView.builder(
            itemCount: _students.length,
            itemBuilder: (context, index) {
              final student = _students[index];
              final id = student['id'].toString();
              return CheckboxListTile(
                title: Text(student['name'] ?? 'Unknown'),
                value: _selectedStudentIds.contains(id),
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedStudentIds.add(id);
                    } else {
                      _selectedStudentIds.remove(id);
                      _promoteAll = false;
                    }
                  });
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTargetStep(LanguageProvider languageProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            // Adjust width based on screen size
            double cardWidth = constraints.maxWidth;
            if (cardWidth > 600) cardWidth = 600;

            return Container(
              width: cardWidth,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _buildDropdown(
                    label: languageProvider.getTranslatedText({
                      'en': 'Target Academic Year',
                      'id': 'Tahun Ajaran Tujuan',
                    }),
                    value: _selectedTargetYearId,
                    items: _academicYears.map<DropdownMenuItem<String>>((y) {
                      return DropdownMenuItem(
                        value: y['id'].toString(),
                        child: Text(y['year'] ?? 'Unknown'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedTargetYearId = val;
                        _selectedTargetClassId = null;
                      });
                      if (val != null) _loadTargetClasses(val);
                    },
                    icon: Icons.calendar_today,
                  ),
                  SizedBox(height: 20),
                  _buildDropdown(
                    label: languageProvider.getTranslatedText({
                      'en': 'Target Class',
                      'id': 'Kelas Tujuan',
                    }),
                    value: _selectedTargetClassId,
                    items: _targetClasses.isEmpty
                        ? []
                        : _targetClasses.map<DropdownMenuItem<String>>((c) {
                            return DropdownMenuItem(
                              value: c['id'].toString(),
                              child: Text(c['name'] ?? 'Unknown'),
                            );
                          }).toList(),
                    onChanged: (val) =>
                        setState(() => _selectedTargetClassId = val),
                    hint: _targetClasses.isEmpty
                        ? languageProvider.getTranslatedText({
                            'en': 'No classes found',
                            'id': 'Tidak ada kelas',
                          })
                        : null,
                    icon: Icons.class_,
                  ),

                  SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.add, color: Colors.white),
                      label: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Create New Class',
                          'id': 'Buat Kelas Baru',
                        }),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColorUtils.getRoleColor('admin'),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      onPressed: _showCreateClassDialog,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>>? items,
    required Function(String?) onChanged,
    String? hint,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
              items: items,
              onChanged: onChanged,
              hint: hint != null
                  ? Text(hint, style: TextStyle(color: Colors.grey))
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  void _onStepContinue() async {
    final languageProvider = context.read<LanguageProvider>();
    if (_currentStep == 0) {
      if (_selectedSourceClassId == null) return;
      if (_students.isEmpty) await _loadStudents(_selectedSourceClassId!);
      _goToStep(1);
    } else if (_currentStep == 1) {
      if (_selectedStudentIds.isEmpty) return;

      // Auto-select next academic year logic
      if (_selectedSourceClassId != null && _academicYears.isNotEmpty) {
        final sourceClass = _classes.firstWhere(
          (c) => c['id'].toString() == _selectedSourceClassId,
          orElse: () => null,
        );
        if (sourceClass != null) {
          String? sourceYearId = sourceClass['academic_year_id']?.toString();
          if (sourceYearId == null && sourceClass['academic_year'] != null) {
            sourceYearId = sourceClass['academic_year']['id']?.toString();
          }
          if (sourceYearId != null) {
            final currentIndex = _academicYears.indexWhere(
              (y) => y['id'].toString() == sourceYearId,
            );
            if (currentIndex != -1 &&
                currentIndex < _academicYears.length - 1) {
              final currentYearData = _academicYears[currentIndex];
              final String currentYearName = currentYearData['year'] ?? '';
              final startYearStr = currentYearName.split('/').first;
              final startYear = int.tryParse(startYearStr);

              if (startYear != null) {
                final nextYearNameStart = (startYear + 1).toString();
                final nextYear = _academicYears.firstWhere(
                  (y) => (y['year'] as String).startsWith(nextYearNameStart),
                  orElse: () => null,
                );
                if (nextYear != null) {
                  setState(() {
                    _selectedTargetYearId = nextYear['id'].toString();
                  });
                  await _loadTargetClasses(_selectedTargetYearId!);
                }
              }
            }
          }
        }
      }

      _goToStep(2);
    } else if (_currentStep == 2) {
      if (_selectedTargetYearId == null) return;
      if (_selectedTargetClassId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.getTranslatedText({
                'en': 'Please select or create a target class',
                'id': 'Silakan pilih atau buat kelas tujuan',
              }),
            ),
          ),
        );
        return;
      }
      _goToStep(3);
    } else if (_currentStep == 3) {
      // Submit
      _submitPromotion();
    }
  }

  Future<void> _submitPromotion() async {
    final languageProvider = context.read<LanguageProvider>();
    setState(() => _isLoading = true);
    try {
      final data = {
        'source_class_id': _selectedSourceClassId,
        'target_class_id': _selectedTargetClassId,
        'student_ids': _selectedStudentIds.toList(),
        'academic_year_id': _selectedTargetYearId,
      };

      await ApiClassService().promoteStudents(data);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageProvider.getTranslatedText({
              'en': 'Promotion successful',
              'id': 'Kenaikan kelas berhasil',
            }),
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      print('Promotion error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildSummaryStep(LanguageProvider languageProvider) {
    // Find names
    final sourceClass = _classes.firstWhere(
      (c) => c['id'].toString() == _selectedSourceClassId,
      orElse: () => {'name': 'Unknown'},
    );
    final targetClass = _targetClasses.firstWhere(
      (c) => c['id'].toString() == _selectedTargetClassId,
      orElse: () => {'name': 'Unknown'},
    );

    final selectedStudentsList = _students
        .where((s) => _selectedStudentIds.contains(s['id'].toString()))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummaryItem(
          languageProvider.getTranslatedText({
            'en': 'Source Class',
            'id': 'Kelas Asal',
          }),
          sourceClass['name'] ?? '-',
        ),
        Divider(),
        _buildSummaryItem(
          languageProvider.getTranslatedText({
            'en': 'Target Class',
            'id': 'Kelas Tujuan',
          }),
          targetClass['name'] ?? '-',
        ),
        Divider(),
        Text(
          languageProvider.getTranslatedText({
            'en': 'Selected Students (${selectedStudentsList.length})',
            'id': 'Siswa Terpilih (${selectedStudentsList.length})',
          }),
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        SizedBox(height: 8),
        Container(
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.separated(
            padding: EdgeInsets.all(8),
            itemCount: selectedStudentsList.length,
            separatorBuilder: (ctx, i) => Divider(height: 1),
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '${index + 1}. ${selectedStudentsList[index]['name'] ?? '-'}',
                  style: TextStyle(fontSize: 14),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  void _showCreateClassDialog() {
    final languageProvider = context.read<LanguageProvider>();
    final nameController = TextEditingController();
    String? selectedGradeLevel;
    String? selectedHomeroomTeacherId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          ColorUtils.getRoleColor('admin'),
                          ColorUtils.getRoleColor('admin').withOpacity(0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.add, color: Colors.white, size: 20),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            languageProvider.getTranslatedText({
                              'en': 'Add Class',
                              'id': 'Buat Kelas Baru',
                            }),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: languageProvider.getTranslatedText({
                              'en': 'Class Name',
                              'id': 'Nama Kelas',
                            }),
                            prefixIcon: Icon(
                              Icons.school,
                              color: ColorUtils.getRoleColor('admin'),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        SizedBox(height: 12),
                        _buildGradeLevelDropdown(
                          value: selectedGradeLevel,
                          onChanged: (val) {
                            setDialogState(() {
                              selectedGradeLevel = val;
                            });
                          },
                          languageProvider: languageProvider,
                        ),
                        SizedBox(height: 12),
                        _buildHomeroomTeacherDropdown(
                          value: selectedHomeroomTeacherId,
                          onChanged: (val) {
                            setDialogState(() {
                              selectedHomeroomTeacherId = val;
                            });
                          },
                          languageProvider: languageProvider,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Cancel',
                                'id': 'Batal',
                              }),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              if (nameController.text.isEmpty ||
                                  selectedGradeLevel == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Please fill required fields',
                                    ),
                                  ),
                                );
                                return;
                              }

                              try {
                                final data = {
                                  'name': nameController.text.trim(),
                                  'grade_level': int.parse(selectedGradeLevel!),
                                  'homeroom_teacher_id':
                                      selectedHomeroomTeacherId,
                                  // Pass academic year if API supports it, or it defaults to active
                                  'academic_year_id': _selectedTargetYearId,
                                };
                                await ApiClassService().addClass(data);
                                Navigator.pop(context);
                                if (_selectedTargetYearId != null) {
                                  _loadTargetClasses(_selectedTargetYearId!);
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Class Created')),
                                );
                              } catch (e) {
                                print(e);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ColorUtils.getRoleColor('admin'),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Create',
                                'id': 'Buat',
                              }),
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGradeLevelDropdown({
    required String? value,
    required Function(String?) onChanged,
    required LanguageProvider languageProvider,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: languageProvider.getTranslatedText({
            'en': 'Grade Level',
            'id': 'Tingkat Kelas',
          }),
          prefixIcon: Icon(
            Icons.grade,
            color: ColorUtils.getRoleColor('admin'),
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12),
        ),
        items: _availableGradeLevels.map((gradeStr) {
          final grade = int.tryParse(gradeStr) ?? 0;
          String gradeText;
          if (grade <= 6) {
            gradeText = 'Kelas $grade SD';
          } else if (grade <= 9) {
            gradeText = 'Kelas $grade SMP';
          } else {
            gradeText = 'Kelas $grade SMA';
          }

          return DropdownMenuItem<String>(
            value: gradeStr,
            child: Text(gradeText),
          );
        }).toList(),
        onChanged: onChanged,
        style: TextStyle(fontSize: 14, color: Colors.grey.shade800),
      ),
    );
  }

  Widget _buildHomeroomTeacherDropdown({
    required String? value,
    required Function(String?) onChanged,
    required LanguageProvider languageProvider,
  }) {
    final uniqueTeachers = <String, Map<String, dynamic>>{};
    for (var teacher in _teachers) {
      if (teacher['id'] != null) {
        uniqueTeachers[teacher['id'].toString()] = teacher;
      }
    }
    // Validate value
    String? validValue = value;
    if (validValue != null && !uniqueTeachers.containsKey(validValue)) {
      validValue = null;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: validValue,
        decoration: InputDecoration(
          labelText: languageProvider.getTranslatedText({
            'en': 'Homeroom Teacher',
            'id': 'Wali Kelas',
          }),
          prefixIcon: Icon(
            Icons.person,
            color: ColorUtils.getRoleColor('admin'),
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        items: [
          DropdownMenuItem<String>(
            value: null,
            child: Text(
              languageProvider.getTranslatedText({
                'en': 'No Homeroom Teacher',
                'id': 'Tidak ada wali kelas',
              }),
            ),
          ),
          ...uniqueTeachers.values.map((teacher) {
            final teacherName = teacher['name'] ?? 'Unknown';
            final teacherNip = teacher['nip']?.toString() ?? '';
            final displayText = teacherNip.isNotEmpty
                ? '$teacherName (NIP: $teacherNip)'
                : teacherName;
            return DropdownMenuItem<String>(
              value: teacher['id'].toString(),
              child: Text(displayText, overflow: TextOverflow.ellipsis),
            );
          }),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
