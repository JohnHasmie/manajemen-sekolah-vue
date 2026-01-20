import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/providers/academic_year_provider.dart';
import 'package:manajemensekolah/screen/admin/admin_announcement.dart';
import 'package:manajemensekolah/screen/admin/admin_class_activity.dart';
import 'package:manajemensekolah/screen/admin/admin_class_management.dart';
import 'package:manajemensekolah/screen/admin/admin_presence_report.dart';
import 'package:manajemensekolah/screen/admin/admin_rpp_screen.dart';
import 'package:manajemensekolah/screen/admin/finance.dart';
import 'package:manajemensekolah/screen/admin/school_settings_screen.dart';
import 'package:manajemensekolah/screen/admin/settings_screen.dart';
import 'package:manajemensekolah/screen/admin/student_management.dart';
import 'package:manajemensekolah/screen/admin/subject_management.dart';
import 'package:manajemensekolah/screen/admin/teacher_admin.dart';
import 'package:manajemensekolah/screen/admin/teaching_schedule_management.dart';
import 'package:manajemensekolah/screen/guru/class_activity.dart';
import 'package:manajemensekolah/screen/guru/input_grade_teacher.dart';
import 'package:manajemensekolah/screen/guru/materi_screen.dart';
import 'package:manajemensekolah/screen/guru/presence_teacher.dart';
import 'package:manajemensekolah/screen/guru/rpp_screen.dart';
import 'package:manajemensekolah/screen/guru/teaching_schedule.dart';
import 'package:manajemensekolah/screen/walimurid/announcement_screen.dart';
import 'package:manajemensekolah/screen/walimurid/parent_billing.dart';
import 'package:manajemensekolah/screen/walimurid/parent_class_activity.dart';
import 'package:manajemensekolah/screen/walimurid/parent_grade_screen.dart';
import 'package:manajemensekolah/screen/walimurid/presence_parent.dart';
import 'package:manajemensekolah/services/api_class_services.dart';
import 'package:manajemensekolah/services/api_schedule_services.dart';
import 'package:manajemensekolah/services/api_services.dart';
import 'package:manajemensekolah/services/api_student_services.dart';
import 'package:manajemensekolah/services/api_subject_services.dart';
import 'package:manajemensekolah/services/api_teacher_services.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Dashboard extends StatefulWidget {
  final String role;

  const Dashboard({super.key, required this.role});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard>
    with SingleTickerProviderStateMixin {
  String get _effectiveRole {
    if (widget.role == 'teacher') return 'guru';
    if (widget.role == 'parent') return 'wali';
    return widget.role;
  }

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  Map<String, dynamic> _userData = {};
  List<dynamic> _accessibleSchools = [];
  bool _isLoadingSchools = false;
  List<dynamic> _availableRoles = [];
  bool _isLoadingRoles = false;
  String? _currentSemesterLabel;

  // Data statistik
  Map<String, dynamic> _stats = {
    'total_siswa': 0,
    'total_guru': 0,
    'total_kelas': 0,
    'total_mapel': 0,
    'kelas_hari_ini': 0,
    'total_materi': 0,
    'total_rpp': 0,
    'anak_terdaftar': 0,
    'pengumuman_terbaru': 0,
  };

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadUserData();
    await _loadAccessibleSchools();
    await _loadAvailableRoles();
    // Fetch academic years
    if (mounted) {
      await Provider.of<AcademicYearProvider>(
        context,
        listen: false,
      ).fetchAcademicYears();
    }

    // Listen for changes
    if (mounted) {
      Provider.of<AcademicYearProvider>(
        context,
        listen: false,
      ).addListener(_onYearChanged);
    }

    await _loadStats(); // Pastikan dipanggil setelah user data dimuat
    _loadSemesterLabel();
  }

  Future<void> _loadSemesterLabel() async {
    try {
      final result = await ApiScheduleService.getDateBasedSemester();
      if (mounted && result.containsKey('label')) {
        setState(() {
          _currentSemesterLabel = result['label'];
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading semester label: $e');
      }
    }
  }

  void _onYearChanged() {
    _loadStats();
    _loadUserData();
  }

  Future<void> _loadAvailableRoles() async {
    if (!mounted) return;
    setState(() {
      _isLoadingRoles = true;
    });

    try {
      final roles = await ApiService.getUserRoles();
      if (!mounted) return;
      setState(() {
        _availableRoles = roles;
        _isLoadingRoles = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error loading roles: $e');
      }
      if (!mounted) return;
      setState(() {
        _isLoadingRoles = false;
      });
    }
  }

  Future<void> _switchRole(String role) async {
    try {
      final response = await ApiService.switchRole(role);

      // Update token dan user data
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', response['token']);

      // Update user data dengan role baru
      final updatedUserData = Map<String, dynamic>.from(_userData);
      updatedUserData['role'] = role;

      await prefs.setString('user', json.encode(updatedUserData));

      if (!mounted) return;

      // Navigate ke dashboard dengan role baru
      Navigator.pushReplacementNamed(context, '/$role');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Berhasil pindah ke role ${_getRoleDisplayName(role)}'),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal pindah role: $e')));
      }
    }
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString('user');
    if (userString != null) {
      if (!mounted) return;

      final localUserData = json.decode(userString);
      setState(() {
        _userData = localUserData;
      });

      // If teacher, fetch fresh data with academic year context
      if (_effectiveRole == 'guru') {
        String? academicYearId;
        // Need to wait for provider if called early, or access it if available
        // safe to access here if initState called _initializeData
        if (mounted) {
          try {
            final academicYearProvider = Provider.of<AcademicYearProvider>(
              context,
              listen: false,
            );
            academicYearId = academicYearProvider.selectedAcademicYear?['id']
                ?.toString();
          } catch (e) {
            // Provider might not be ready or found in context if too early?
            // Normally safe in initState + postFrame or later.
          }
        }

        if (academicYearId != null) {
          final userId = localUserData['id']?.toString();

          if (userId != null) {
            final teacherData = await ApiTeacherService.getGuruByUserId(
              userId,
              academicYearId: academicYearId,
            );

            if (teacherData != null && mounted) {
              setState(() {
                _userData = {..._userData, ...teacherData};
              });
              if (kDebugMode) {
                print('✅ Updated teacher data for year $academicYearId');
                if (teacherData['homeroom_class'] != null) {
                  print('✅ Homeroom: ${teacherData['homeroom_class']['name']}');
                } else {
                  print('ℹ️ No homeroom class for this year');
                }
              }
            }
          }
        }
      }
    }
  }

  Future<void> _loadAccessibleSchools() async {
    if (!mounted) return;
    setState(() {
      _isLoadingSchools = true;
    });

    try {
      final schools = await ApiService.getUserSchools();
      if (!mounted) return;
      setState(() {
        _accessibleSchools = schools;
        _isLoadingSchools = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error loading schools: $e');
      }
      if (!mounted) return;
      setState(() {
        _isLoadingSchools = false;
      });
    }
  }

  Future<void> _loadStats() async {
    try {
      if (_effectiveRole == 'guru') {
        // Load data untuk guru
        final userData = _userData;
        if (userData['id'] == null) {
          if (kDebugMode) {
            print('❌ Guru ID tidak ditemukan');
          }
          return;
        }

        if (kDebugMode) {
          print('👤 Loading stats untuk guru: ${userData['id']}');
        }

        String? academicYearId;
        if (mounted) {
          final academicYearProvider = Provider.of<AcademicYearProvider>(
            context,
            listen: false,
          );
          academicYearId = academicYearProvider.selectedAcademicYear?['id']
              ?.toString();
        }

        final schedule = await ApiScheduleService.getCurrentUserSchedule(
          academicYear: academicYearId,
        );
        if (kDebugMode) {
          print('📅 Jadwal ditemukan: ${schedule.length}');
        }

        final subjects = await ApiSubjectService.getMateri(
          teacherId: userData['id'],
        );
        if (kDebugMode) {
          print('📚 Materi ditemukan: ${subjects.length}');
        }

        final rpp = await ApiService.getRPP(teacherId: userData['id']);
        if (kDebugMode) {
          print('📋 RPP ditemukan: ${rpp.length}');
        }

        final totalStudentsTaught = await _getTotalStudentsTaught(
          academicYearId,
        );
        final totalClassesTaught = await _getTotalClassesTaught(academicYearId);
        final todaysClasses = _getTodaysClasses(schedule);

        if (kDebugMode) {
          print(
            '📊 Stats Guru - Siswa: $totalStudentsTaught, Kelas: $totalClassesTaught, Hari Ini: $todaysClasses',
          );
        }

        if (!mounted) return;

        setState(() {
          _stats = {
            'total_siswa': totalStudentsTaught,
            'total_kelas': totalClassesTaught,
            'kelas_hari_ini': todaysClasses,
            'total_materi': subjects.length,
            'total_rpp': rpp.length,
          };
        });
      } else if (_effectiveRole == 'admin') {
        // Load data untuk admin
        if (kDebugMode) {
          print('👤 Loading stats untuk admin');
        }

        final academicYearProvider = Provider.of<AcademicYearProvider>(
          context,
          listen: false,
        );
        final selectedYearId = academicYearProvider.selectedAcademicYear?['id']
            ?.toString();

        final student = await ApiStudentService.getStudent();
        // Note: Generic getStudent might need filtering by year if we want "Active Students in Year".
        // For now, let's keep it simple or check if getStudent supports filtering.
        // Usually "Total Students" is global, but "Total Classes" IS year-specific.

        final teacher = await ApiTeacherService().getTeacher();

        // Filter classes by active year
        final classes = await ApiClassService.getClassPaginated(
          limit: 1000,
          academicYearId: selectedYearId,
        );
        final classesList = classes['data'] as List? ?? [];

        final subjects = await ApiSubjectService().getSubject();

        if (!mounted) return;
        setState(() {
          _stats = {
            'total_siswa': student.length,
            'total_guru': teacher.length,
            'total_kelas': classesList.length,
            'total_mapel': subjects.length,
          };
        });
      } else if (_effectiveRole == 'wali') {
        // Load data untuk wali murid
        final userData = _userData;
        if (kDebugMode) {
          print('👤 Loading stats untuk wali: ${userData['id']}');
        }

        final studentsData = await _getStudentDataForParent(
          userData['id'] ?? '',
        );
        if (kDebugMode) {
          print('👶 Data siswa untuk wali: ${studentsData.length}');
        }

        // Untuk pengumuman, kita gunakan fallback dulu
        final announcements = await _getAnnouncements();
        if (kDebugMode) {
          print('📢 Pengumuman untuk wali: ${announcements.length}');
        }

        if (!mounted) return;
        setState(() {
          _stats = {
            'anak_terdaftar': studentsData.length,
            'pengumuman_terbaru': announcements.length,
          };
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading stats: $e');
      }
      // Fallback data dengan logging
      if (kDebugMode) {
        print('🔄 Menggunakan fallback data');
      }
      if (!mounted) return;
      setState(() {
        if (_effectiveRole == 'guru') {
          _stats = {
            'total_siswa': 24,
            'total_kelas': 1,
            'kelas_hari_ini': 2,
            'total_materi': 5,
            'total_rpp': 3,
          };
        } else if (_effectiveRole == 'admin') {
          _stats = {
            'total_siswa': 150,
            'total_guru': 25,
            'total_kelas': 12,
            'total_mapel': 15,
          };
        } else if (_effectiveRole == 'wali') {
          _stats = {'anak_terdaftar': 2, 'pengumuman_terbaru': 3};
        }
      });
    }
  }

  Future<int> _getTotalStudentsTaught(String? academicYearId) async {
    try {
      final classesTaught = await _getClassesTaught(academicYearId);
      if (classesTaught.isEmpty) {
        return 0;
      }

      int total = 0;
      for (var classes in classesTaught) {
        try {
          final students = await ApiClassService().getStudentsByClassId(
            classes['id']?.toString() ?? '',
            // Assuming getStudentsByClassId might also support academic year if classStudents table is time-bound?
            // But usually classId is unique per year if classes are not reused.
            // If classes are reused, we might need filtering students by year status.
            // For now, assume class ID is sufficient.
          );
          total += students.length;
          if (kDebugMode) {
            print('`Siswa di kelas ${classes['nama']}: ${students.length}`');
          }
        } catch (e) {
          if (kDebugMode) {
            print('❌ Error getting students for class ${classes['id']}: $e');
          }
        }
      }

      if (kDebugMode) {
        print('`📊 Total siswa diampu: $total`');
      }
      return total;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error in _getTotalStudentsTaught: $e');
      }
      return 0;
    }
  }

  Future<int> _getTotalClassesTaught(String? academicYearId) async {
    try {
      final classesTaught = await _getClassesTaught(academicYearId);
      return classesTaught.length;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error in _getTotalClassesTaught: $e');
      }
      return 0;
    }
  }

  Future<List<dynamic>> _getClassesTaught(String? academicYearId) async {
    try {
      final schedule = await ApiScheduleService.getCurrentUserSchedule(
        academicYear: academicYearId,
      );
      if (kDebugMode) {
        print('📅 Total jadwal: ${schedule.length}');
      }

      if (schedule.isEmpty) {
        if (kDebugMode) {
          print('⚠️ Tidak ada jadwal ditemukan');
        }
        return [];
      }

      final classIds = schedule
          .map((s) => s['class_id']?.toString())
          .where((id) => id != null)
          .toSet()
          .toList();
      if (kDebugMode) {
        print('🎯 Kelas IDs unik: $classIds');
      }

      List<dynamic> classes = [];
      for (var classId in classIds) {
        try {
          final classData = await ApiClassService().getClassById(classId!);
          if (classData != null) {
            classes.add(classData);
            if (kDebugMode) {
              print('✅ Kelas $classId ditemukan');
            }
          } else {
            if (kDebugMode) {
              print('❌ Kelas $classId tidak ditemukan');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('❌ Error getting class $classId: $e');
          }
        }
      }

      if (kDebugMode) {
        print('🏫 Total kelas diampu: ${classes.length}');
      }
      return classes;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error in _getClassesTaught: $e');
      }
      return [];
    }
  }

  int _getTodaysClasses(List<dynamic> schedule) {
    try {
      if (schedule.isEmpty) return 0;

      final today = DateTime.now();
      final dayNames = [
        'Minggu',
        'Senin',
        'Selasa',
        'Rabu',
        'Kamis',
        'Jumat',
        'Sabtu',
      ];

      // Adjust index: DateTime.weekday returns 1-7, but our list is 0-6
      // So we need to subtract 1, but also handle Sunday (7 -> 0)
      final todayIndex = today.weekday % 7; // This will convert 7 (Sunday) to 0
      final todayName = dayNames[todayIndex];

      if (kDebugMode) {
        print(
          '📅 Hari ini: $todayName (index: $todayIndex, weekday: ${today.weekday})',
        );
      }

      final todayClasses = schedule.where((s) {
        final nameDay = s['hari_nama']?.toString() ?? '';
        return nameDay == todayName;
      }).toList();

      if (kDebugMode) {
        print('🎯 Kelas hari ini: ${todayClasses.length}');
      }
      return todayClasses.length;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error in _getTodaysClasses: $e');
      }
      return 0;
    }
  }

  // Method untuk mendapatkan data siswa untuk parent/wali murid
  Future<List<dynamic>> _getStudentDataForParent(String parentId) async {
    try {
      if (kDebugMode) {
        print('👤 Mencari data siswa untuk parent: $parentId');
      }

      final userData = _userData;
      final guardianEmail = userData['email'];

      final allStudents = await ApiStudentService.getStudent(
        userId: parentId,
        guardianEmail: guardianEmail,
      );

      if (kDebugMode) {
        print(
          '🎒 Total siswa ditemukan untuk user $parentId (Email: $guardianEmail): ${allStudents.length}',
        );
      }

      if (kDebugMode) {
        print(
          '📧 Email wali: ${userData['email']}, Nama wali: ${userData['name']}',
        );
      }

      // Cek berdasarkan siswa_id di user data
      if (userData['siswa_id'] != null && userData['siswa_id'].isNotEmpty) {
        if (kDebugMode) {
          print('🔍 Mencari siswa dengan ID: ${userData['siswa_id']}');
        }
        final student = allStudents.firstWhere(
          (student) => student['id'] == userData['siswa_id'],
          orElse: () => null,
        );
        if (student != null) {
          if (kDebugMode) {
            print('✅ Siswa ditemukan via siswa_id: ${student['nama']}');
          }
          return [student];
        }
      }

      // Cek berdasarkan email atau nama wali atau user_id (Parent User)
      final studentsWithThisParent = allStudents.where((student) {
        final emailMatch = student['guardian_email'] == userData['email'];
        // Fix: Use 'name' instead of 'nama' (based on debug logs)
        final nameMatch = student['guardian_name'] == userData['name'];
        final userIdMatch = student['user_id'].toString() == parentId;

        if (kDebugMode) {
          // Verbose debug only if needed, or just log matches
          if (emailMatch || nameMatch || userIdMatch) {
            print(
              '✅ Siswa cocok: ${student['name']} (By: ${emailMatch ? 'Email' : ''} ${nameMatch ? 'Name' : ''} ${userIdMatch ? 'UserID' : ''})',
            );
          } else {
            // print('❌ Skip: ${student['name']} (GuardEmail: ${student['guardian_email']}, GuardName: ${student['guardian_name']}, UserID: ${student['user_id']})');
          }
        }

        return emailMatch || nameMatch || userIdMatch;
      }).toList();

      if (studentsWithThisParent.isNotEmpty) {
        return studentsWithThisParent;
      }

      if (kDebugMode) {
        print('⚠️ Tidak ada data siswa ditemukan untuk parent ini');
      }
      return []; // Fix: Return empty list instead of allStudents for security/correctness
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting student data for parent: $e');
      }
      return [];
    }
  }

  Future<List<dynamic>> _getAnnouncements() async {
    try {
      // Sama seperti di PengumumanScreen - langsung ambil dari API
      // Backend sudah melakukan filtering berdasarkan role user
      if (kDebugMode) {
        print('🔄 Memuat data pengumuman untuk role: $_effectiveRole');
      }

      final announcementData = await ApiService().get(
        '/announcement/user/current',
      );

      if (kDebugMode) {
        print('✅ Response dari API:');
        print('Type: ${announcementData.runtimeType}');
        print(
          'Length: ${announcementData is List ? announcementData.length : 'N/A'}',
        );
      }

      // Backend sudah filter berdasarkan role, jadi langsung return aja
      if (announcementData is List) {
        if (kDebugMode) {
          print(
            '📊 Data pengumuman berhasil dimuat: ${announcementData.length} pengumuman',
          );
        }
        return announcementData;
      }

      return [];
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading pengumuman: $e');
      }
      return [];
    }
  }

  Future<void> _switchSchool(Map<String, dynamic> school) async {
    // Show Loading Indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await ApiService.switchSchool(school['school_id']);

      // Close Loading Indicator
      if (mounted) Navigator.pop(context);

      // 1. Check for Multiple Roles (`pilih_role`)
      if (response['pilih_role'] == true && response['role_list'] is List) {
        final roleList = List<String>.from(response['role_list']);

        if (!mounted) return;

        final selectedRole = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (context) => SimpleDialog(
            title: Text('Pilih Peran Anda'),
            children: roleList.map((role) {
              // Normalize for display
              final normalizedForDisplay = role == 'parent'
                  ? 'wali'
                  : (role == 'teacher' ? 'guru' : role);
              return SimpleDialogOption(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                onPressed: () => Navigator.pop(
                  context,
                  role,
                ), // Return original string 'parent'/'admin'
                child: Row(
                  children: [
                    _buildRoleIcon(normalizedForDisplay),
                    SizedBox(width: 12),
                    Text(
                      _getRoleDisplayName(normalizedForDisplay),
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );

        if (selectedRole == null) return;

        // Proceed with selectedRole
        await _processSchoolSwitch(response, school, selectedRole);
        return;
      }

      // 2. Single Role Case (Backend assigned role automatically)
      await _processSchoolSwitch(response, school, null);
    } catch (e) {
      // Close Loading Indicator if error occurs
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal pindah sekolah: $e')));
      }
    }
  }

  Future<void> _processSchoolSwitch(
    Map<String, dynamic> response,
    Map<String, dynamic> schoolInfo,
    String? selectedRole,
  ) async {
    // Update token
    final prefs = await SharedPreferences.getInstance();
    if (response['token'] != null) {
      await prefs.setString('token', response['token']);
    }

    // Update user data from backend response
    Map<String, dynamic> updatedUserData;

    if (response['user'] != null) {
      final backendUser = Map<String, dynamic>.from(response['user']);
      updatedUserData = {..._userData, ...backendUser};

      // If "pilih_role" case (selectedRole != null), we must construct some fields manually
      // because backend raw user object in this case might not have 'role' set,
      // nor 'nama_sekolah' (which comes in 'school' object).
      if (selectedRole != null) {
        updatedUserData['role'] = selectedRole;

        // Backend sends 'school' object in pilih_role response
        if (response['school'] != null) {
          final schoolObj = response['school'];
          updatedUserData['school_id'] = schoolObj['id'];
          updatedUserData['nama_sekolah'] =
              schoolObj['school_name'] ?? schoolObj['nama_sekolah'];
          updatedUserData['sekolah_alamat'] =
              schoolObj['address'] ?? schoolObj['alamat'];
          // ... other fields if needed
        }
      }
    } else {
      // Fallback manual update (should not happen with correct backend)
      updatedUserData = Map<String, dynamic>.from(_userData);
      updatedUserData['school_id'] = schoolInfo['school_id'];
      updatedUserData['nama_sekolah'] =
          schoolInfo['school_name'] ?? schoolInfo['nama_sekolah'];
    }

    await prefs.setString('user', json.encode(updatedUserData));

    if (!mounted) return;

    var newRole = updatedUserData['role'];

    // Normalize role values
    if (newRole == 'teacher') newRole = 'guru';
    if (newRole == 'parent') newRole = 'wali';

    // Update 'role' in userData to normalized value?
    // Better to strictly use normalized for Frontend routing.
    updatedUserData['role'] = newRole;
    await prefs.setString(
      'user',
      json.encode(updatedUserData),
    ); // Save normalized

    final currentRole = _effectiveRole;

    if (newRole != null) {
      // Always navigate to new dashboard to refresh state completely
      Navigator.pushNamedAndRemoveUntil(context, '/$newRole', (route) => false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Berhasil pindah ke ${updatedUserData['nama_sekolah']} sebagai ${_getRoleDisplayName(newRole!)}',
          ),
        ),
      );
    } else {
      // Role same, just reload data
      await _initializeData();
      setState(() {
        _userData = updatedUserData;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Berhasil pindah ke ${updatedUserData['nama_sekolah']}',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Scaffold(
          backgroundColor: _getBackgroundColor(),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Modern Header dengan gradient seperti Duolingo
                _buildModernHeader(context, languageProvider),
                SizedBox(height: 16),

                // Welcome Section dengan animasi
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: _buildWelcomeSection(),
                  ),
                ),
                SizedBox(height: 20),

                // Dashboard Stats Cards
                _buildStatsSection(),
                SizedBox(height: 20),

                // Search Bar dengan design modern
                _buildModernSearchBar(),
                SizedBox(height: 20),

                // Grid Menu dengan animasi bertahap
                Expanded(child: _buildAnimatedGridMenu(context)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModernHeader(
    BuildContext context,
    LanguageProvider languageProvider,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: _getHeaderGradient(),
        boxShadow: [
          BoxShadow(
            color: _getPrimaryColor().withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Logo dengan animasi
          ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.school, color: _getPrimaryColor(), size: 24),
            ),
          ),
          SizedBox(width: 12),

          // App Title dan Nama Sekolah
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userData['nama_sekolah'] ?? AppLocalizations.appTitle.tr,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      _getRoleTitle(),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Action Icons
          Row(
            children: [
              _buildIconButton(
                icon: Icons.language,
                color: Colors.white,
                onPressed: () => _showLanguageDialog(context, languageProvider),
              ),
              _buildIconButton(
                icon: Icons.notifications_none,
                color: Colors.white,
                onPressed: () {},
              ),
              _buildIconButton(
                icon: Icons.account_circle,
                color: Colors.white,
                onPressed: () => _showAccountBottomSheet(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    if (_effectiveRole == 'guru') {
      return _buildTeacherStats();
    } else if (_effectiveRole == 'admin') {
      return _buildAdminStats();
    } else if (_effectiveRole == 'wali') {
      return _buildParentStats();
    }
    return SizedBox.shrink();
  }

  Widget _buildTeacherStats() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildStatCard(
            title:
                "${AppLocalizations.totalStudents.tr}\n${AppLocalizations.supervised.tr}",
            value: _stats['total_siswa'].toString(),
            subtitle:
                "${AppLocalizations.all.tr} ${AppLocalizations.class_.tr.toLowerCase()}",
            icon: Icons.people_alt_outlined,
            iconColor: Color(0xFF4361EE),
            backgroundColor: Color(0xFF4361EE).withOpacity(0.1),
          ),
          SizedBox(width: 12),
          _buildStatCard(
            title: AppLocalizations.totalClasses.tr,
            value: _stats['total_kelas'].toString(),
            subtitle: "✓ ${AppLocalizations.active.tr}",
            icon: Icons.class_outlined,
            iconColor: Color(0xFF2EC4B6),
            backgroundColor: Color(0xFF2EC4B6).withOpacity(0.1),
          ),
          SizedBox(width: 12),
          _buildStatCard(
            title: AppLocalizations.todaysClasses.tr,
            value: _stats['kelas_hari_ini'].toString(),
            subtitle: AppLocalizations.ongoing.tr,
            icon: Icons.schedule_outlined,
            iconColor: Color(0xFFFF9F1C),
            backgroundColor: Color(0xFFFF9F1C).withOpacity(0.1),
          ),
          SizedBox(width: 12),
          _buildStatCard(
            title: "RPP",
            value: "${_stats['total_rpp']}",
            // valueStyle: TextStyle(
            //   fontSize: 12,
            //   fontWeight: FontWeight.w600,
            //   color: Colors.grey.shade700,
            // ),
            subtitle: AppLocalizations.submitted.tr,
            icon: Icons.description_outlined,
            iconColor: Color(0xFF7209B7),
            backgroundColor: Color(0xFF7209B7).withOpacity(0.1),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminStats() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildStatCard(
            title: AppLocalizations.totalStudents.tr,
            value: _stats['total_siswa'].toString(),
            subtitle: "✓ ${AppLocalizations.registered.tr}",
            icon: "👨‍🎓",
            iconColor: Color(0xFF4361EE),
            backgroundColor: Color(0xFF4361EE).withOpacity(0.1),
          ),
          SizedBox(width: 12),
          _buildStatCard(
            title: AppLocalizations.totalTeachers.tr,
            value: _stats['total_guru'].toString(),
            subtitle: "✓ ${AppLocalizations.active.tr}",
            icon: "👨‍🏫",
            iconColor: Color(0xFF2EC4B6),
            backgroundColor: Color(0xFF2EC4B6).withOpacity(0.1),
          ),
          SizedBox(width: 12),
          _buildStatCard(
            title: AppLocalizations.totalClasses.tr,
            value: _stats['total_kelas'].toString(),
            subtitle: AppLocalizations.available.tr,
            icon: "🏫",
            iconColor: Color(0xFFFF9F1C),
            backgroundColor: Color(0xFFFF9F1C).withOpacity(0.1),
          ),
          SizedBox(width: 12),
          _buildStatCard(
            title: AppLocalizations.subjects.tr,
            value: _stats['total_mapel'].toString(),
            subtitle: "✓ ${AppLocalizations.available.tr}",
            icon: "📚",
            iconColor: Color(0xFF7209B7),
            backgroundColor: Color(0xFF7209B7).withOpacity(0.1),
          ),
        ],
      ),
    );
  }

  Widget _buildParentStats() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildStatCard(
            title: AppLocalizations.announcements.tr,
            value: _stats['pengumuman_terbaru'].toString(),
            subtitle: AppLocalizations.latestInfo.tr,
            icon: Icons.announcement_outlined,
            iconColor: Color(0xFF4361EE),
            backgroundColor: Color(0xFF4361EE).withOpacity(0.1),
          ),
          SizedBox(width: 12),
          _buildStatCard(
            title: AppLocalizations.childrenData.tr,
            value: _stats['anak_terdaftar'].toString(),
            subtitle: AppLocalizations.registeredChildren.tr,
            icon: Icons.child_care_outlined,
            iconColor: Color(0xFF2EC4B6),
            backgroundColor: Color(0xFF2EC4B6).withOpacity(0.1),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required dynamic icon,
    required Color iconColor,
    required Color backgroundColor,
    TextStyle? valueStyle,
  }) {
    return Container(
      width: 140,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: icon is IconData
                    ? Icon(icon, color: iconColor, size: 18)
                    : Center(
                        child: Text(
                          icon is String ? icon : "👨‍🎓",
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            value,
            style:
                valueStyle ??
                TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
              height: 1.3,
            ),
          ),
          SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      margin: EdgeInsets.only(left: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: _getCardGradient(),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _getPrimaryColor().withOpacity(0.3),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background Pattern
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(Icons.person, color: _getPrimaryColor(), size: 28),
              ),
              SizedBox(width: 16),

              // Text Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppLocalizations.welcome.tr,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      _userData['nama'] ?? _getRoleTitle(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8),

                    // Academic Info (Moved here, below Name)
                    Consumer<AcademicYearProvider>(
                      builder: (context, provider, child) {
                        if (provider.isLoading) {
                          return SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          );
                        }

                        return Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: provider.selectedAcademicYear?['id']
                                      .toString(),
                                  dropdownColor: _getPrimaryColor(),
                                  icon: Padding(
                                    padding: EdgeInsets.only(left: 4),
                                    child: Icon(
                                      Icons.keyboard_arrow_down,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  isDense: true,
                                  items: provider.academicYears.map((year) {
                                    final isCurrent =
                                        year['current'] == true ||
                                        year['status'] == 'active';
                                    return DropdownMenuItem<String>(
                                      value: year['id'].toString(),
                                      child: Text(
                                        '${year['year']}${isCurrent ? ' (Active)' : ''}',
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      provider.setSelectedYear(val);
                                    }
                                  },
                                ),
                              ),
                            ),
                            if (_currentSemesterLabel != null)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  _currentSemesterLabel!,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white.withOpacity(0.95),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          decoration: InputDecoration(
            hintText: AppLocalizations.searchHint.tr,
            hintStyle: TextStyle(color: Colors.grey.shade500),
            prefixIcon: Icon(Icons.search_rounded, color: _getPrimaryColor()),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 15),
          ),
          style: TextStyle(color: Colors.grey.shade700),
          onChanged: (value) {
            // Implement search functionality
          },
        ),
      ),
    );
  }

  Widget _buildAnimatedGridMenu(BuildContext context) {
    final cards = _getDashboardCards(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 1.1,
        ),
        itemCount: cards.length,
        itemBuilder: (context, index) {
          return AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              final delay = (index * 0.1).clamp(0.0, 0.8);
              final animation = CurvedAnimation(
                parent: _animationController,
                curve: Interval(delay, 1.0, curve: Curves.easeOut),
              );

              return FadeTransition(
                opacity: animation,
                child: Transform.translate(
                  offset: Offset(0, 50 * (1 - animation.value)),
                  child: child,
                ),
              );
            },
            child: cards[index],
          );
        },
      ),
    );
  }

  Widget _buildDashboardCard(String title, dynamic icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                blurRadius: 5,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Strip biru di pinggir kiri
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 6,
                  decoration: BoxDecoration(
                    color: _getPrimaryColor(), // Warna biru sesuai role
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),
              ),

              // Background pattern effect
              Positioned(
                right: -8,
                top: -8,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              // Content - di tengah dengan icon di atas text
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Icon Container
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _getPrimaryColor().withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _buildIconWidget(icon),
                      ),
                      SizedBox(height: 12),
                      // Title - di bawah icon
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                          height: 1.3,
                        ),
                        textAlign: TextAlign.center, // Text di tengah
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method untuk render icon dynamic
  Widget _buildIconWidget(dynamic icon) {
    if (icon is IconData) {
      return Icon(
        icon,
        color: _getPrimaryColor(), // Warna icon sesuai dengan primary color
        size: 24, // Sedikit lebih besar
      );
    } else if (icon is String) {
      // Untuk emoji - tetap gunakan emoji asli tanpa warna
      return Center(
        child: Text(
          icon,
          style: TextStyle(fontSize: 20), // Sedikit lebih besar untuk emoji
        ),
      );
    } else if (icon is Widget) {
      // Jika langsung passing Widget
      return icon;
    } else {
      // Fallback default icon
      return Icon(Icons.error, color: _getPrimaryColor(), size: 24);
    }
  }

  void _showLanguageDialog(
    BuildContext context,
    LanguageProvider languageProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          AppLocalizations.chooseLanguage.tr,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _getPrimaryColor(),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageOption(
              context,
              languageProvider,
              'Indonesia',
              'id',
              Colors.green,
            ),
            SizedBox(height: 12),
            _buildLanguageOption(
              context,
              languageProvider,
              'English',
              'en',
              Colors.blue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(
    BuildContext context,
    LanguageProvider languageProvider,
    String language,
    String code,
    Color color,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          Navigator.pop(context);
          await languageProvider.setLanguage(code);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.language, color: color),
              SizedBox(width: 12),
              Text(
                language,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
              Spacer(),
              if (languageProvider.currentLanguage == code)
                Icon(Icons.check_circle, color: color),
            ],
          ),
        ),
      ),
    );
  }

  void _showAccountBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          margin: EdgeInsets.all(20),
          child: Wrap(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 60,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      SizedBox(height: 20),

                      // User Info
                      Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: _getCardGradient(),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.account_circle,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _userData['nama'] ?? _getRoleTitle(),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  _userData['email'] ?? '',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  _userData['nama_sekolah'] ?? '',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 24),

                      if (_availableRoles.length > 1) ...[
                        SizedBox(height: 16),
                        Text(
                          AppLocalizations.switchRole.tr,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        SizedBox(height: 8),
                        ..._availableRoles.map((role) {
                          final isCurrent = role == widget.role;
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: isCurrent
                                  ? null
                                  : () {
                                      Navigator.pop(context);
                                      _switchRole(role);
                                    },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(12),
                                margin: EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: isCurrent
                                      ? _getPrimaryColor().withOpacity(0.1)
                                      : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isCurrent
                                        ? _getPrimaryColor().withOpacity(0.3)
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    _buildRoleIcon(role),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _getRoleDisplayName(role),
                                        style: TextStyle(
                                          fontWeight: isCurrent
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                    ),
                                    if (isCurrent)
                                      Icon(
                                        Icons.check_circle,
                                        color: _getPrimaryColor(),
                                        size: 20,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                        SizedBox(height: 16),
                        Divider(),
                        SizedBox(height: 16),
                      ],

                      // Switch Sekolah Button
                      if (_accessibleSchools.length > 1) ...[
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              _showSchoolSelectionDialog(context);
                            },
                            borderRadius: BorderRadius.circular(15),
                            child: Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _getPrimaryColor().withOpacity(0.1),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: _getPrimaryColor().withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.school_rounded,
                                    color: _getPrimaryColor(),
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    AppLocalizations.switchSchool.tr,
                                    style: TextStyle(
                                      color: _getPrimaryColor(),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        Divider(),
                        SizedBox(height: 16),
                      ],

                      // Settings Button
                      if (_effectiveRole == 'admin') ...[
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SettingsScreen(),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(15),
                            child: Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.settings,
                                    color: Colors.grey.shade800,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    AppLocalizations.settings.tr,
                                    style: TextStyle(
                                      color: Colors.grey.shade800,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                      ],

                      // Logout Button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.clear();
                            if (context.mounted) {
                              Navigator.pop(context);
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                '/login',
                                (route) => false,
                              );
                            }
                          },
                          borderRadius: BorderRadius.circular(15),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.red.shade100),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.logout_rounded,
                                  color: Colors.redAccent,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  AppLocalizations.logout.tr,
                                  style: TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRoleIcon(String role) {
    switch (role) {
      case 'admin':
        return Icon(
          Icons.admin_panel_settings,
          color: _getPrimaryColor(),
          size: 20,
        );
      case 'guru':
        return Icon(Icons.school, color: _getPrimaryColor(), size: 20);
      case 'wali':
        return Icon(Icons.family_restroom, color: _getPrimaryColor(), size: 20);
      case 'staff':
        return Icon(Icons.work, color: _getPrimaryColor(), size: 20);
      default:
        return Icon(Icons.person, color: _getPrimaryColor(), size: 20);
    }
  }

  String _getRoleDisplayName(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
      case 'administrator':
        return 'Administrator';
      case 'guru':
      case 'teacher':
        return 'Teacher';
      case 'wali':
      case 'parent':
      case 'walimurid':
      case 'wali murid':
        return 'Parent';
      case 'staff':
        return 'Staff';
      default:
        // Capitalize first letter if no match found
        if (role.isNotEmpty) {
          return role[0].toUpperCase() + role.substring(1);
        }
        return role;
    }
  }

  void _showSchoolSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.school_rounded, color: _getPrimaryColor()),
            SizedBox(width: 8),
            Text(
              'Pilih Sekolah',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isLoadingSchools)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                )
              else
                ..._accessibleSchools.map((school) {
                  final isCurrent =
                      school['school_id'] == _userData['school_id'];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: isCurrent
                          ? null
                          : () {
                              Navigator.pop(
                                dialogContext,
                              ); // Close dialog immediately
                              _switchSchool(school);
                            },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: EdgeInsets.all(12),
                        margin: EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? _getPrimaryColor().withOpacity(0.1)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCurrent
                                ? _getPrimaryColor().withOpacity(0.3)
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.school,
                              color: isCurrent
                                  ? _getPrimaryColor()
                                  : Colors.grey,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    school['school_name'],
                                    style: TextStyle(
                                      fontWeight: isCurrent
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    school['address'] ?? '',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (isCurrent)
                              Icon(
                                Icons.check_circle,
                                color: _getPrimaryColor(),
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Batal', style: TextStyle(color: Colors.grey.shade600)),
          ),
        ],
      ),
    );
  }

  // Helper methods untuk colors dan gradients
  Color _getPrimaryColor() {
    switch (_effectiveRole) {
      case 'admin':
        return Color(0xFF2563EB); // Blue
      case 'guru':
        return Color(0xFF16A34A); // Teal
      case 'staff':
        return Color(0xFFFF9F1C); // Orange
      case 'wali':
        return Color(0xFF9333EA); // Purple
      default:
        return Color.fromARGB(255, 17, 19, 29);
    }
  }

  Color _getBackgroundColor() {
    return Color(0xFFF8F9FA);
  }

  LinearGradient _getHeaderGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [_getPrimaryColor(), _getPrimaryColor().withOpacity(0.8)],
    );
  }

  LinearGradient _getCardGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [_getPrimaryColor(), _getPrimaryColor().withOpacity(0.7)],
    );
  }

  String _getRoleTitle() {
    switch (_effectiveRole) {
      case 'admin':
        return AppLocalizations.adminRole.tr;
      case 'guru':
        return AppLocalizations.teacherRole.tr;
      case 'staff':
        return AppLocalizations.staffRole.tr;
      case 'wali':
        return AppLocalizations.parentRole.tr;
      default:
        return 'User';
    }
  }

  // Keep existing methods for dashboard cards functionality
  List<Widget> _getDashboardCards(BuildContext context) {
    if (_effectiveRole == 'admin') {
      return [
        _buildDashboardCard(
          AppLocalizations.manageStudents.tr,
          Icons.people_alt_outlined,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => StudentManagementScreen()),
          ),
        ),
        _buildDashboardCard(
          AppLocalizations.manageTeachers.tr,
          Icons.person_outline,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => TeacherAdminScreen()),
          ),
        ),
        _buildDashboardCard(
          AppLocalizations.manageClasses.tr,
          Icons.class_outlined,
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AdminClassManagementScreen(),
            ),
          ),
        ),
        _buildDashboardCard(
          AppLocalizations.manageSubjects.tr,
          Icons.book_outlined,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SubjectManagementScreen()),
          ),
        ),
        _buildDashboardCard(
          AppLocalizations.manageTeachingSchedule.tr,
          Icons.schedule_outlined,
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TeachingScheduleManagementScreen(),
            ),
          ),
        ),
        _buildDashboardCard(
          AppLocalizations.inputGrades.tr,
          Icons.edit_note_outlined,
          () async {
            final prefs = await SharedPreferences.getInstance();
            final userData = json.decode(prefs.getString('user') ?? '{}');
            final adminData = {
              'id': userData['id'] ?? '',
              'nama': userData['nama'] ?? 'Admin',
              'email': userData['email'] ?? '',
              'role': _effectiveRole,
            };
            if (adminData['id']!.isEmpty) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: Admin ID not found')),
                );
              }
              return;
            }
            if (!context.mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GradePage(teacher: adminData),
              ),
            );
          },
        ),
        _buildDashboardCard(
          AppLocalizations.announcements.tr,
          Icons.announcement_outlined,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AdminAnnouncementScreen()),
          ),
        ),
        _buildDashboardCard(
          AppLocalizations.classActivities.tr,
          Icons.local_activity_outlined,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AdminClassActivityScreen()),
          ),
        ),
        _buildDashboardCard(
          AppLocalizations.presenceReport.tr,
          Icons.check_circle_outline,
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AdminPresenceReportScreen(),
            ),
          ),
        ),
        _buildDashboardCard(
          AppLocalizations.manageRpp.tr,
          Icons.description_outlined,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AdminRppScreen()),
          ),
        ),
        _buildDashboardCard(
          AppLocalizations.finance.tr,
          Icons.account_balance_wallet_outlined,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => FinanceScreen()),
          ),
        ),
        _buildDashboardCard(
          AppLocalizations.schoolSettings.tr,
          Icons.settings_applications,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SchoolSettingsScreen()),
          ),
        ),
      ];
    } else if (_effectiveRole == 'guru') {
      return [
        _buildDashboardCard(
          AppLocalizations.teachingSchedule.tr,
          Icons.schedule_outlined,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => TeachingScheduleScreen()),
          ),
        ),
        _buildDashboardCard(
          AppLocalizations.classActivities.tr,
          Icons.local_activity_outlined,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ClassActifityScreen()),
          ),
        ),
        _buildDashboardCard(
          AppLocalizations.studentAttendance.tr,
          Icons.check_circle_outline,
          () async {
            final prefs = await SharedPreferences.getInstance();
            final userData = json.decode(prefs.getString('user') ?? '{}');
            final guruData = {
              'id': userData['id'] ?? '',
              'nama': userData['nama'] ?? 'Teacher',
              'email': userData['email'] ?? '',
              'role': _effectiveRole,
            };
            if (guruData['id']!.isEmpty) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: Teacher ID not found')),
                );
              }
              return;
            }
            if (!context.mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PresencePage(teacher: guruData),
              ),
            );
          },
        ),
        _buildDashboardCard(
          AppLocalizations.inputGrades.tr,
          Icons.edit_note_outlined,
          () async {
            final prefs = await SharedPreferences.getInstance();
            final userData = json.decode(prefs.getString('user') ?? '{}');
            final teacherData = {
              'id': userData['id'] ?? '',
              'nama': userData['nama'] ?? 'Teacher',
              'email': userData['email'] ?? '',
              'role': _effectiveRole,
            };
            if (teacherData['id']!.isEmpty) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: Teacher ID not found')),
                );
              }
              return;
            }
            if (!context.mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GradePage(teacher: teacherData),
              ),
            );
          },
        ),
        _buildDashboardCard(
          AppLocalizations.learningMaterials.tr,
          Icons.book_outlined,
          () async {
            final prefs = await SharedPreferences.getInstance();
            final userData = json.decode(prefs.getString('user') ?? '{}');
            final teacherData = {
              'id': userData['id'] ?? '',
              'name': userData['name'] ?? 'Teacher',
              'role': _effectiveRole,
            };
            if (teacherData['id']!.isEmpty) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: Teacher ID not found')),
                );
              }
              return;
            }
            if (!context.mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MateriPage(teacher: teacherData),
              ),
            );
          },
        ),
        _buildDashboardCard(
          AppLocalizations.myRpp.tr,
          Icons.description_outlined,
          () async {
            final prefs = await SharedPreferences.getInstance();
            final userData = json.decode(prefs.getString('user') ?? '{}');
            final teacherData = {
              'id': userData['id'] ?? '',
              'nama': userData['nama'] ?? 'Teacher',
              'email': userData['email'] ?? '',
              'role': _effectiveRole,
            };
            if (teacherData['id']!.isEmpty) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: Teacher ID not found')),
                );
              }
              return;
            }
            if (!context.mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RppScreen(
                  teacherId: teacherData['id']!,
                  teacherName: teacherData['nama']!,
                ),
              ),
            );
          },
        ),
        _buildDashboardCard(
          AppLocalizations.announcements.tr,
          Icons.announcement_outlined,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AnnouncementScreen()),
          ),
        ),
      ];
    } else if (_effectiveRole == 'wali') {
      return [
        _buildDashboardCard(
          AppLocalizations.announcements.tr,
          Icons.announcement_outlined,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AnnouncementScreen()),
          ),
        ),
        _buildDashboardCard(
          AppLocalizations.classActivities.tr,
          Icons.local_activity_outlined,
          () {
            final academicYearId = Provider.of<AcademicYearProvider>(
              context,
              listen: false,
            ).selectedAcademicYear?['id']?.toString();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ParentClassActivityScreen(academicYearId: academicYearId),
              ),
            );
          },
        ),
        _buildDashboardCard(
          AppLocalizations.grades.tr,
          Icons.grade_outlined,
          () {
            final academicYearId = Provider.of<AcademicYearProvider>(
              context,
              listen: false,
            ).selectedAcademicYear?['id']?.toString();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ParentGradeScreen(academicYearId: academicYearId),
              ),
            );
          },
        ),
        _buildDashboardCard(
          AppLocalizations.presence.tr,
          Icons.check_circle_outline,
          () async {
            final academicYearId = Provider.of<AcademicYearProvider>(
              context,
              listen: false,
            ).selectedAcademicYear?['id']?.toString();

            final prefs = await SharedPreferences.getInstance();
            final userData = json.decode(prefs.getString('user') ?? '{}');
            // Load students
            final studentsData = await _getStudentDataForParent(
              userData['id'] ?? '',
            );

            if (studentsData.isEmpty) {
              if (context.mounted) {
                _showNoStudentsDialog(context);
              }
              return;
            }

            if (!context.mounted) return;

            if (studentsData.length == 1) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PresenceParentPage(
                    parent: userData,
                    studentId: studentsData[0]['id'],
                    academicYearId: academicYearId,
                  ),
                ),
              );
            } else {
              _showStudentSelectionDialog(
                context,
                userData,
                studentsData,
                academicYearId: academicYearId,
              );
            }
          },
        ),
        _buildDashboardCard(
          AppLocalizations.billing.tr,
          Icons.account_balance_wallet_outlined,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ParentBillingScreen()),
          ),
        ),
      ];
    }
    return [];
  }
}

void _showStudentSelectionDialog(
  BuildContext context,
  Map<String, dynamic> parent,
  List<dynamic> studentData, {
  String? academicYearId,
}) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Pilih Anak', style: TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: studentData.length,
          itemBuilder: (context, index) {
            final student = studentData[index];
            return Material(
              color: Colors.transparent,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade50,
                  child: Text(
                    student['name'][0].toUpperCase(),
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  student['name'],
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(student['kelas_nama'] ?? 'Kelas tidak tersedia'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PresenceParentPage(
                        parent: parent,
                        studentId: student['id'],
                        academicYearId: academicYearId,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    ),
  );
}

void _showNoStudentsDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Informasi'),
      content: Text(
        'Tidak ada data siswa yang terhubung dengan akun wali murid ini. Silakan hubungi administrator.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('OK')),
      ],
    ),
  );
}
