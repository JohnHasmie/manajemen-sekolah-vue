import 'package:flutter/material.dart';
import 'package:manajemensekolah/services/api_academic_services.dart';
import 'package:manajemensekolah/services/api_class_services.dart';
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
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      // Load classes for source (current year)
      // Note: This API should respect current global year filter if applied,
      // or we might need to fetch ALL classes if we want to allow promotion from any class.
      // For now assume getClasses returns classes from active/selected year context.
      final classesData = await ApiClassService().getClass();
      final yearsData = await ApiAcademicServices.getAcademicYears();

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
    // We need an API to fetch classes by Academic Year ID specifically.
    // If ApiClassService.getClass() uses the global filter, we might need to switch context
    // or use a new endpoint. For now, let's assume we can filter client side or use a specific endpoint.
    // We'll mimic fetching.
    // TODO: Ideally ApiClassService should accept year_id param.
    // Assuming we fetch all and filter or backend endpoint support.

    // TEMPORARY: Just fetching all classes and filtering by year if possible, but
    // since we don't have direct access to "classes of random year" easily without changing global state,
    // we might need to rely on the user to CREATE a class if it's a new year with no classes.
    // OR, we assume backend `getClass` accepts `academic_year_id`. It currently respects specific logic.

    // For MVP: Let's assume we can fetch classes. If distinct endpoint needed, we add it.
    // Let's try fetching standard classes.
    setState(() => _isLoading = true);
    try {
      // Ideally: await ApiClassService.getClassesByYear(yearId);
      // Fallback: Just fetch all and filtering? No, backend filters by active year usually.
      // We might need to CREATE a new class primarily.
      // Let's leave target classes empty initially or assume none exist for new year.
      setState(() {
        _targetClasses = []; // Reset
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          languageProvider.getTranslatedText({
            'en': 'Promote Class',
            'id': 'Naik Kelas',
          }),
        ),
        backgroundColor: ColorUtils.getRoleColor('admin'),
      ),
      body: Stack(
        children: [
          Stepper(
            type: StepperType.horizontal,
            currentStep: _currentStep,
            onStepContinue: _onStepContinue,
            onStepCancel: _onStepCancel,
            steps: [
              Step(
                title: Text(
                  languageProvider.getTranslatedText({
                    'en': 'Source',
                    'id': 'Asal',
                  }),
                ),
                content: _buildSourceStep(languageProvider),
                isActive: _currentStep >= 0,
              ),
              Step(
                title: Text(
                  languageProvider.getTranslatedText({
                    'en': 'Students',
                    'id': 'Siswa',
                  }),
                ),
                content: _buildStudentsStep(languageProvider),
                isActive: _currentStep >= 1,
              ),
              Step(
                title: Text(
                  languageProvider.getTranslatedText({
                    'en': 'Target',
                    'id': 'Tujuan',
                  }),
                ),
                content: _buildTargetStep(languageProvider),
                isActive: _currentStep >= 2,
              ),
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
                title: Text(student['nama'] ?? 'Unknown'),
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
      children: [
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: languageProvider.getTranslatedText({
              'en': 'Select Target Academic Year',
              'id': 'Pilih Tahun Ajaran Tujuan',
            }),
            border: OutlineInputBorder(),
          ),
          initialValue: _selectedTargetYearId,
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
        ),
        SizedBox(height: 16),
        // Class Selection or Creation
        _targetClasses.isEmpty
            ? ElevatedButton.icon(
                icon: Icon(Icons.add),
                label: Text(
                  languageProvider.getTranslatedText({
                    'en': 'Create New Class',
                    'id': 'Buat Kelas Baru',
                  }),
                ),
                onPressed: _showCreateClassDialog,
              )
            : DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: languageProvider.getTranslatedText({
                    'en': 'Select Target Class',
                    'id': 'Pilih Kelas Tujuan',
                  }),
                  border: OutlineInputBorder(),
                ),
                initialValue: _selectedTargetClassId,
                items: _targetClasses.map<DropdownMenuItem<String>>((c) {
                  return DropdownMenuItem(
                    value: c['id'].toString(),
                    child: Text(c['name'] ?? 'Unknown'),
                  );
                }).toList(),
                onChanged: (val) =>
                    setState(() => _selectedTargetClassId = val),
              ),
      ],
    );
  }

  void _onStepContinue() async {
    if (_currentStep == 0) {
      if (_selectedSourceClassId == null) return;
      if (_students.isEmpty) await _loadStudents(_selectedSourceClassId!);
      setState(() => _currentStep++);
    } else if (_currentStep == 1) {
      if (_selectedStudentIds.isEmpty) return;
      setState(() => _currentStep++);
    } else if (_currentStep == 2) {
      // Submit
      if (_selectedTargetYearId == null) return;
      if (_selectedTargetClassId == null) {
        // Force user to create class if none selected/available
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select or create a target class')),
        );
        return;
      }

      _submitPromotion();
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _submitPromotion() async {
    setState(() => _isLoading = true);
    try {
      await ApiAcademicServices.promoteStudents(
        studentIds: _selectedStudentIds.toList(),
        targetClassId: _selectedTargetClassId!,
        academicYearId: _selectedTargetYearId!,
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Promotion Successful!')));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showCreateClassDialog() {
    // Inline create class dialog
    // Reuse existing logic or simple dialog
    // Need to confirm if we can reuse AdminClassManagementScreen dialog logic or duplicated.
    // For simplicity, implement minimal dialog here.
    final nameController = TextEditingController();
    final gradeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('New Class'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: 'Class Name'),
            ),
            TextField(
              controller: gradeController,
              decoration: InputDecoration(labelText: 'Grade Level (1-12)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // Call API create class with target Year ID
              try {
                // We need to pass academic_year_id to create class in THAT year.
                // But our addClass API usually uses global year or current context.
                // We might need to update Endpoint to accept academic_year_id explicitly.
                // Or, we assume if we create it, it attaches to active year.
                // This is a limitation.
                // Workaround: We might need to Switch Global Year -> Create Class -> Switch Back? Risky.

                // For now, let's assume we can simply create it and backend handles it,
                // OR we update `addClass` to accept `academic_year_id`.

                // Let's implement basics
                Navigator.pop(context);
              } catch (e) {
                print(e);
              }
            },
            child: Text('Create'),
          ),
        ],
      ),
    );
  }
}
