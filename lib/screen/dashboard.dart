import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/providers/academic_year_provider.dart';
import 'package:manajemensekolah/screen/admin/admin_announcement.dart';
import 'package:manajemensekolah/screen/admin/admin_class_activity.dart';
import 'package:manajemensekolah/screen/admin/admin_data_management.dart';
import 'package:manajemensekolah/screen/admin/admin_presence_report.dart';
import 'package:manajemensekolah/screen/admin/admin_rpp_screen.dart';
import 'package:manajemensekolah/screen/admin/finance.dart';
import 'package:manajemensekolah/screen/admin/school_settings_screen.dart';
import 'package:manajemensekolah/screen/admin/settings_screen.dart';
import 'package:manajemensekolah/screen/admin/teaching_schedule_management.dart';
import 'package:manajemensekolah/screen/common/notification_list.dart';
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
import 'package:manajemensekolah/services/api_class_activity_services.dart';
import 'package:manajemensekolah/services/api_class_services.dart';
import 'package:manajemensekolah/services/api_schedule_services.dart';
import 'package:manajemensekolah/services/api_services.dart';
import 'package:manajemensekolah/services/api_student_services.dart';
import 'package:manajemensekolah/services/api_subject_services.dart';
import 'package:manajemensekolah/services/api_teacher_services.dart';
import 'package:manajemensekolah/services/fcm_service.dart';
import 'package:manajemensekolah/services/local_cache_service.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/utils/error_utils.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:manajemensekolah/widgets/dashboard/attendance_bar_chart_card.dart';
import 'package:manajemensekolah/widgets/dashboard/category_section.dart';
import 'package:manajemensekolah/widgets/dashboard/finance_bar_chart_card.dart';
import 'package:manajemensekolah/widgets/dashboard/menu_item_card.dart';
import 'package:manajemensekolah/widgets/dashboard/mini_bar_chart.dart';
import 'package:manajemensekolah/widgets/dashboard/overview_card.dart';
import 'package:manajemensekolah/widgets/dashboard/quick_action_button.dart';
import 'package:manajemensekolah/widgets/dashboard/schedule_slider_card.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

class Dashboard extends StatefulWidget {
  final String role;

  const Dashboard({super.key, required this.role});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with TickerProviderStateMixin {
  String get _effectiveRole {
    if (widget.role == 'teacher') return 'guru';
    if (widget.role == 'parent') return 'wali';
    return widget.role;
  }

  late AnimationController _animationController;
  Map<String, dynamic> _userData = {};
  List<dynamic> _accessibleSchools = [];
  bool _isLoadingSchools = false;
  List<dynamic> _availableRoles = [];
  bool _isLoadingRoles = false;
  List<Map<String, dynamic>> _attendanceChartData = [];
  List<Map<String, dynamic>> _financeChartData = [];

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
    'unread_billing': 0,
  };

  // State for Schedule Slider
  List<dynamic> _todaysScheduleList = [];

  // Finance Badge State
  int _unverifiedPaymentCount = 0;

  // Skeleton loading state
  bool _isStatsLoaded = false;

  // Stats Pagination state

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );

    _animationController.forward();

    // Listen to background sync triggers (e.g. from FCM)
    FCMService().syncTrigger.addListener(_handleSyncTrigger);

    _initializeData();
  }

  Future<void> _initializeData() async {
    // Load cached data first (fast, synchronous-like)
    await _loadCachedUserData();

    setState(() {});

    try {
      // Fetch fresh data in background
      _loadFreshTeacherData();
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
      await _loadSemesterLabel();
    } catch (e) {
      if (kDebugMode) print('❌ Error during initialization: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal memuat data dashboard: ${ErrorUtils.getFriendlyMessage(e)}',
            ),
            backgroundColor: Colors.orange.shade800,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {});
      }
    }
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
    if (!mounted) return;
    setState(() => _isStatsLoaded = false);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal pindah role: ${ErrorUtils.getFriendlyMessage(e)}',
            ),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _loadCachedUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString('user');
    if (userString != null) {
      if (!mounted) return;
      final localUserData = json.decode(userString);
      setState(() {
        _userData = localUserData;
      });
    }
  }

  Future<void> _loadFreshTeacherData() async {
    if (_effectiveRole != 'guru') return;

    try {
      String? academicYearId;
      if (mounted) {
        final academicYearProvider = Provider.of<AcademicYearProvider>(
          context,
          listen: false,
        );
        academicYearId = academicYearProvider.selectedAcademicYear?['id']
            ?.toString();
      }

      if (academicYearId != null && _userData['id'] != null) {
        final teacherData = await ApiTeacherService.getGuruByUserId(
          _userData['id'].toString(),
          academicYearId: academicYearId,
        );

        if (teacherData != null && mounted) {
          setState(() {
            _userData = {..._userData, ...teacherData};
          });
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error loading fresh teacher data: $e');
    }
  }

  // Obsolete - removed in favor of split loading
  Future<void> _loadUserData() async {
    await _loadCachedUserData();
    await _loadFreshTeacherData();
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
        final todaysClassesList = _getTodaysClassesList(schedule);
        final todaysClasses = todaysClassesList.length;

        if (kDebugMode) {
          print(
            '📊 Stats Guru - Siswa: $totalStudentsTaught, Kelas: $totalClassesTaught, Hari Ini: $todaysClasses',
          );
        }

        final unreadCount = await ApiService.getUnreadAnnouncementCount();
        final unreadActivityCount =
            await ApiClassActivityService.getUnreadCount();

        if (!mounted) return;

        setState(() {
          _isStatsLoaded = true;
          _todaysScheduleList = todaysClassesList;
          _stats = {
            'total_siswa': totalStudentsTaught,
            'total_kelas': totalClassesTaught,
            'kelas_hari_ini': todaysClasses,
            'total_materi': subjects.length,
            'total_rpp': rpp.length,
            'unread_announcements': unreadCount,
            'unread_class_activities': unreadActivityCount,
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

        final studentStats = await ApiStudentService.getStudentStats(
          academicYearId: selectedYearId,
          status: 'active',
        );

        final teacherStats = await ApiTeacherService.getTeacherStats(
          academicYearId: selectedYearId,
        );

        // Filter classes by active year
        final classes = await ApiClassService.getClassPaginated(
          limit: 1, // We only need the total_items from pagination
          academicYearId: selectedYearId,
        );
        final totalClasses = classes['pagination']?['total_items'] ?? 0;

        final subjects = await ApiSubjectService().getSubject();
        final unreadCount = await ApiService.getUnreadAnnouncementCount();
        final unreadActivityCount =
            await ApiClassActivityService.getUnreadCount();

        final now = DateTime.now();
        final currentMonthNames = [
          'Januari',
          'Februari',
          'Maret',
          'April',
          'Mei',
          'Juni',
          'Juli',
          'Agustus',
          'September',
          'Oktober',
          'November',
          'Desember',
        ];
        final currentMonthStr = currentMonthNames[now.month - 1];
        int weekNum = (now.day / 7).ceil();
        if (weekNum > 5) weekNum = 5; // Cap at 5 weeks
        final currentWeekStr = 'Pekan $weekNum';

        // Fetch Attendance Chart Data
        final attendanceDataList = await ApiService.getAttendanceDashboardChart(
          academicYearId: selectedYearId,
          month: currentMonthStr,
          week: currentWeekStr,
        );

        final financeDataList = await ApiService.getFinanceDashboardChart(
          academicYearId: selectedYearId,
        );

        if (!mounted) return;
        setState(() {
          _isStatsLoaded = true;
          _attendanceChartData = List<Map<String, dynamic>>.from(
            attendanceDataList,
          );
          _financeChartData = List<Map<String, dynamic>>.from(financeDataList);
          _stats = {
            'total_siswa': studentStats['total'] ?? 0,
            'total_guru': teacherStats['total'] ?? 0,
            'total_kelas': totalClasses,
            'total_mapel': subjects.length,
            'unread_announcements': unreadCount,
            'unread_class_activities': unreadActivityCount,
          };
        });

        // Load Finance Stats for Admin
        await _loadFinanceStats();
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

        // Fetch Attendance Chart Data for Parent
        final now = DateTime.now();
        final currentMonthNames = [
          'Januari',
          'Februari',
          'Maret',
          'April',
          'Mei',
          'Juni',
          'Juli',
          'Agustus',
          'September',
          'Oktober',
          'November',
          'Desember',
        ];
        final currentMonthStr = currentMonthNames[now.month - 1];
        int weekNum = (now.day / 7).ceil();
        if (weekNum > 5) weekNum = 5;
        final currentWeekStr = 'Pekan $weekNum';

        final academicYearProvider = Provider.of<AcademicYearProvider>(
          context,
          listen: false,
        );
        final selectedYearId = academicYearProvider.selectedAcademicYear?['id']
            ?.toString();

        final attendanceDataList = await ApiService.getAttendanceDashboardChart(
          academicYearId: selectedYearId,
          month: currentMonthStr,
          week: currentWeekStr,
          role: _effectiveRole,
        );

        // Untuk pengumuman, kita gunakan fallback dulu
        final announcements = await _getAnnouncements();
        final unreadCount = await ApiService.getUnreadAnnouncementCount();
        final unreadActivityCount =
            await ApiClassActivityService.getUnreadCount();
        final unreadGradeCount = await ApiService.getUnreadGradeCount();
        final unreadPresenceCount = await ApiService.getUnreadPresenceCount();
        final unreadBillingCount = await ApiService.getUnreadBillingCount();

        if (!mounted) return;
        setState(() {
          _isStatsLoaded = true;
          _attendanceChartData = List<Map<String, dynamic>>.from(
            attendanceDataList,
          );
          _stats = {
            'anak_terdaftar': studentsData.length,
            'pengumuman_terbaru': announcements.length,
            'unread_announcements': unreadCount,
            'unread_class_activities': unreadActivityCount,
            'unread_grades': unreadGradeCount,
            'unread_presence': unreadPresenceCount,
            'unread_billing': unreadBillingCount,
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
        _isStatsLoaded = true;
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
          _stats = {
            'anak_terdaftar': 2,
            'pengumuman_terbaru': 3,
            'unread_grades': 0,
            'unread_presence': 0,
          };
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
          final students = await ApiClassService.getStudentsByClassId(
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
          final classData = await ApiClassService.getClassById(classId!);
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

  List<dynamic> _getTodaysClassesList(List<dynamic> schedule) {
    try {
      if (schedule.isEmpty) return [];

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

      // Sort by time
      todayClasses.sort((a, b) {
        String timeA =
            a['lesson_hour']?['start_time'] ?? a['start_time'] ?? '00:00';
        String timeB =
            b['lesson_hour']?['start_time'] ?? b['start_time'] ?? '00:00';
        return timeA.compareTo(timeB);
      });

      if (kDebugMode) {
        print('🎯 Kelas hari ini: ${todayClasses.length}');
      }
      return todayClasses;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error in _getTodaysClassesList: $e');
      }
      return [];
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

  // Load Finance Stats (Admin Only)
  Future<void> _loadFinanceStats() async {
    try {
      final financeStats = await ApiService.getFinanceDashboardStats();
      if (mounted && financeStats.containsKey('pembayaran_pending')) {
        setState(() {
          _unverifiedPaymentCount =
              int.tryParse(financeStats['pembayaran_pending'].toString()) ?? 0;
        });
        if (kDebugMode) {
          print('💰 Unverified Payments: $_unverifiedPaymentCount');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading finance stats: $e');
      }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal pindah sekolah: ${ErrorUtils.getFriendlyMessage(e)}',
            ),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _processSchoolSwitch(
    Map<String, dynamic> response,
    Map<String, dynamic> schoolInfo,
    String? selectedRole,
  ) async {
    // Clear all cache to prevent stale data from previous school
    await LocalCacheService.clearAll();

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
    FCMService().syncTrigger.removeListener(_handleSyncTrigger);
    _animationController.dispose();
    try {
      Provider.of<AcademicYearProvider>(
        context,
        listen: false,
      ).removeListener(_onYearChanged);
    } catch (e) {
      if (kDebugMode) print('Error removing AcademicYearProvider listener: $e');
    }
    super.dispose();
  }

  void _handleSyncTrigger() {
    final trigger = FCMService().syncTrigger.value;
    if (trigger != null) {
      if (trigger['type'] == 'refresh_announcements') {
        if (kDebugMode) {
          print(
            '🔄 Dashboard flushing announcement cache due to background/foreground sync',
          );
        }
        // Reload announcements count
        if (_effectiveRole == 'wali' ||
            _effectiveRole == 'admin' ||
            _effectiveRole == 'guru') {
          ApiService.getUnreadAnnouncementCount().then((count) {
            if (mounted) {
              setState(() {
                _stats['unread_announcements'] = count;
              });
            }
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Scaffold(
          backgroundColor: ColorUtils.slate50,
          body: CustomScrollView(
            physics: BouncingScrollPhysics(),
            slivers: [
              // Modern App Bar
              _buildModernAppBar(context, languageProvider),

              // Hero Section with Stats Overlay
              SliverToBoxAdapter(child: _buildHeroSection()),

              // Quick Actions
              SliverToBoxAdapter(child: _buildQuickActions()),

              // Today's Overview
              SliverToBoxAdapter(child: _buildTodaysOverview()),

              // Section Divider
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(12, 12, 12, 10),
                  child: Text(
                    'Menu',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: ColorUtils.slate900,
                    ),
                  ),
                ),
              ),

              // Navigation Menu
              _buildSliverGridMenu(context),

              // Bottom Padding
              SliverPadding(padding: EdgeInsets.only(bottom: 24)),
            ],
          ),
        );
      },
    );
  }

  // ==================== SKELETON SHIMMER HELPERS ====================

  Widget _buildShimmerBox({
    double width = double.infinity,
    double height = 16,
    double borderRadius = 8,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }

  Widget _buildHeroStatSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.white.withOpacity(0.15),
      highlightColor: Colors.white.withOpacity(0.35),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          SizedBox(height: 6),
          Container(
            width: 28,
            height: 17,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          SizedBox(height: 4),
          Container(
            width: 36,
            height: 9,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCardSkeleton() {
    return Shimmer.fromColors(
      baseColor: ColorUtils.shimmerBaseColor,
      highlightColor: ColorUtils.shimmerHighlightColor,
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ColorUtils.slate200, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildShimmerBox(width: 36, height: 36, borderRadius: 10),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildShimmerBox(width: 40, height: 20, borderRadius: 4),
                      SizedBox(height: 4),
                      _buildShimmerBox(width: 70, height: 11, borderRadius: 4),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            _buildShimmerBox(width: 100, height: 10, borderRadius: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionSkeleton() {
    return Shimmer.fromColors(
      baseColor: ColorUtils.shimmerBaseColor,
      highlightColor: ColorUtils.shimmerHighlightColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 65,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          SizedBox(height: 6),
          Container(
            width: 50,
            height: 11,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== NEW MODERN UI COMPONENTS ====================

  Widget _buildModernAppBar(
    BuildContext context,
    LanguageProvider languageProvider,
  ) {
    return SliverAppBar(
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white,
      toolbarHeight: 50,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: ColorUtils.slate200, width: 1),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Logo - simpler design
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _getPrimaryColor(),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.school, color: Colors.white, size: 18),
                ),
                SizedBox(width: 12),

                // Title - single line
                Expanded(
                  child: Text(
                    _userData['nama_sekolah'] ?? AppLocalizations.appTitle.tr,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: ColorUtils.slate900,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Actions - more compact
                IconButton(
                  icon: Icon(
                    Icons.language,
                    size: 20,
                    color: ColorUtils.slate600,
                  ),
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  splashRadius: 18,
                  onPressed: () =>
                      _showLanguageDialog(context, languageProvider),
                ),
                Stack(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.notifications_outlined,
                        size: 20,
                        color: ColorUtils.slate600,
                      ),
                      iconSize: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      splashRadius: 18,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                NotificationListScreen(role: widget.role),
                          ),
                        );
                      },
                    ),
                    if (_stats['unread_announcements'] != null &&
                        _stats['unread_announcements'] > 0)
                      Positioned(
                        right: 4,
                        top: 2,
                        child: Container(
                          padding: EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: ColorUtils.error600,
                            shape: BoxShape.circle,
                          ),
                          constraints: BoxConstraints(
                            minWidth: 14,
                            minHeight: 14,
                          ),
                          child: Text(
                            _stats['unread_announcements'] > 9
                                ? '9+'
                                : _stats['unread_announcements'].toString(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 7,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    Icons.account_circle,
                    size: 20,
                    color: ColorUtils.slate600,
                  ),
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  splashRadius: 18,
                  onPressed: () => _showAccountBottomSheet(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    final primaryColor = _getPrimaryColor();

    return Container(
      margin: EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(
        gradient: ColorUtils.heroGradient(primaryColor: primaryColor),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Decorative circle - top right
            Positioned(
              top: -40,
              right: -30,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
            ),
            // Decorative circle - bottom left
            Positioned(
              bottom: -25,
              left: 15,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
            ),
            // Small accent dot
            Positioned(
              top: 20,
              right: 70,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.3),
                ),
              ),
            ),

            // Academic Year & Semester - Top Right
            Positioned(
              top: 10,
              right: 12,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showAcademicYearDialog(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.calendar_today_outlined,
                            size: 12,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        SizedBox(width: 8),
                        Consumer<AcademicYearProvider>(
                          builder: (context, provider, _) {
                            final academicYear =
                                provider.selectedAcademicYear?['year'] ?? '-';
                            final semester = _currentSemesterLabel ?? '-';
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  academicYear,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    height: 1.1,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  semester,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white.withOpacity(0.8),
                                    fontWeight: FontWeight.w500,
                                    height: 1.1,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Main content
            Padding(
              padding: EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Greeting
                  Row(
                    children: [
                      Text(
                        _getGreeting(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.85),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                      SizedBox(width: 4),
                      Text(_getGreetingEmoji(), style: TextStyle(fontSize: 14)),
                    ],
                  ),
                  SizedBox(height: 3),
                  Text(
                    _userData['nama'] ?? 'User',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 14),

                  // 4-Column Stats Grid
                  Row(
                    children: _isStatsLoaded
                        ? _buildFourColumnStats()
                              .map((stat) => Expanded(child: stat))
                              .toList()
                        : List.generate(
                            4,
                            (_) => Expanded(child: _buildHeroStatSkeleton()),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAcademicYearDialog(BuildContext context) {
    final provider = Provider.of<AcademicYearProvider>(context, listen: false);
    final years = provider.academicYears;

    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Pilih Tahun Ajaran'),
        children: years.map((year) {
          final isSelected = provider.selectedAcademicYear?['id'] == year['id'];
          return SimpleDialogOption(
            onPressed: () {
              provider.setSelectedYear(year['id'].toString());
              Navigator.pop(context);
            },
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  year['year'] ?? '-',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isSelected
                        ? ColorUtils.corporateBlue600
                        : ColorUtils.slate900,
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check,
                    color: ColorUtils.corporateBlue600,
                    size: 20,
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getGreetingEmoji() {
    final hour = DateTime.now().hour;
    if (hour < 12) return '🌅';
    if (hour < 17) return '☀️';
    return '🌙';
  }

  List<Widget> _buildFourColumnStats() {
    if (_effectiveRole == 'admin') {
      return [
        _buildHeroStat(
          Icons.people_outline,
          _stats['total_siswa']?.toString() ?? '0',
          'Siswa',
        ),
        _buildHeroStat(
          Icons.school_outlined,
          _stats['total_guru']?.toString() ?? '0',
          'Guru',
        ),
        _buildHeroStat(
          Icons.class_outlined,
          _stats['total_kelas']?.toString() ?? '0',
          'Kelas',
        ),
        _buildHeroStat(
          Icons.book_outlined,
          _stats['total_mapel']?.toString() ?? '0',
          'Mapel',
        ),
      ];
    } else if (_effectiveRole == 'guru') {
      return [
        _buildHeroStat(
          Icons.people_outline,
          _stats['total_siswa']?.toString() ?? '0',
          'Siswa',
        ),
        _buildHeroStat(
          Icons.class_outlined,
          _stats['total_kelas']?.toString() ?? '0',
          'Kelas',
        ),
        _buildHeroStat(
          Icons.schedule_outlined,
          _stats['kelas_hari_ini']?.toString() ?? '0',
          'Hari Ini',
        ),
        _buildHeroStat(
          Icons.assignment_outlined,
          _stats['total_rpp']?.toString() ?? '0',
          'RPP',
        ),
      ];
    } else {
      return [
        _buildHeroStat(
          Icons.child_care_outlined,
          _stats['anak_terdaftar']?.toString() ?? '0',
          'Anak',
        ),
        _buildHeroStat(
          Icons.announcement_outlined,
          _stats['pengumuman_terbaru']?.toString() ?? '0',
          'Info',
        ),
        _buildHeroStat(
          Icons.grade_outlined,
          _stats['unread_grades']?.toString() ?? '0',
          'Nilai',
        ),
        _buildHeroStat(
          Icons.calendar_today_outlined,
          _stats['unread_presence']?.toString() ?? '0',
          'Absen',
        ),
      ];
    }
  }

  Widget _buildHeroStat(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icon with glass morphism effect
        Container(
          padding: EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
          ),
          child: Icon(icon, color: Colors.white, size: 17),
        ),
        SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),
        SizedBox(height: 1),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: Colors.white.withOpacity(0.85),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    List<Widget> actions = _getQuickActions();

    if (actions.isEmpty && _isStatsLoaded) {
      return SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Section header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Quick Access',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: ColorUtils.slate900,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          // Action buttons or skeleton
          SizedBox(
            height: 85,
            child: _isStatsLoaded
                ? ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: BouncingScrollPhysics(),
                    itemCount: actions.length,
                    separatorBuilder: (context, index) => SizedBox(width: 10),
                    itemBuilder: (context, index) => actions[index],
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: 4,
                    separatorBuilder: (context, index) => SizedBox(width: 10),
                    itemBuilder: (context, index) =>
                        _buildQuickActionSkeleton(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodaysOverview() {
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Today's Overview",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: ColorUtils.slate900,
            ),
          ),
          GridView.count(
            padding: EdgeInsets.only(top: 12),
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.4,
            children: _isStatsLoaded
                ? _getTodaysOverviewCards()
                : List.generate(4, (_) => _buildOverviewCardSkeleton()),
          ),
        ],
      ),
    );
  }

  List<Widget> _getTodaysOverviewCards() {
    if (_effectiveRole == 'admin') {
      return [
        if (_financeChartData.isNotEmpty)
          FinanceBarChartCard(
            title: 'Keuangan',
            icon: Icons.account_balance_wallet_outlined,
            accentColor: ColorUtils.success600,
            semestersData: _financeChartData,
            onTap: () {
              showDialog(
                context: context,
                builder: (context) =>
                    _FinancePopupDialog(semestersData: _financeChartData),
              );
            },
          ),
        if (_attendanceChartData.isNotEmpty)
          AttendanceBarChartCard(
            title: 'Absensi',
            icon: Icons.ssid_chart_outlined,
            accentColor: ColorUtils.warning600,
            classesData: _attendanceChartData,
            onTap: () {
              // Extract the selected academic year right before showing dialog
              final selectedYearId = Provider.of<AcademicYearProvider>(
                context,
                listen: false,
              ).selectedAcademicYear?['id']?.toString();

              showDialog(
                context: context,
                builder: (context) => _AttendancePopupDialog(
                  semesterLabel: _currentSemesterLabel,
                  initialData: _attendanceChartData,
                  academicYearId: selectedYearId,
                ),
              );
            },
          ),
        OverviewCard(
          title: 'Active Teachers',
          value: _stats['total_guru']?.toString() ?? '0',
          subtitle: 'Currently teaching',
          icon: Icons.people_alt_outlined,
          accentColor: ColorUtils.success600,
          onTap: () {
            // Navigate to teachers
          },
        ),
        OverviewCard(
          title: 'Announcements',
          value: _stats['pengumuman_terbaru']?.toString() ?? '0',
          subtitle: 'Recent updates',
          icon: Icons.campaign_outlined,
          accentColor: ColorUtils.info600,
          onTap: () {
            // Navigate to announcements
          },
        ),
      ];
    } else if (_effectiveRole == 'guru') {
      return [
        ScheduleSliderCard(
          schedules: _todaysScheduleList,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => TeachingScheduleScreen()),
            );
          },
        ),
        OverviewCard(
          title: 'Attendance',
          value: _stats['total_siswa']?.toString() ?? '0',
          subtitle: 'Students today',
          icon: Icons.how_to_reg_outlined,
          accentColor: ColorUtils.success600,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PresencePage(teacher: _userData),
              ),
            );
          },
        ),
        OverviewCard(
          title: 'Materials',
          value: _stats['total_materi']?.toString() ?? '0',
          subtitle: 'Learning resources',
          icon: Icons.book_outlined,
          accentColor: ColorUtils.info600,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MateriPage(teacher: _userData),
              ),
            );
          },
        ),
        OverviewCard(
          title: 'Lesson Plans',
          value: _stats['total_rpp']?.toString() ?? '0',
          subtitle: 'Prepared documents',
          icon: Icons.description_outlined,
          accentColor: ColorUtils.corporateBlue600,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RppScreen(
                  teacherId: _userData['id'].toString(),
                  teacherName: _userData['name'] ?? 'Guru',
                ),
              ),
            );
          },
        ),
      ];
    } else {
      return [
        OverviewCard(
          title: 'My Children',
          value: _stats['anak_terdaftar']?.toString() ?? '0',
          subtitle: 'Registered students',
          icon: Icons.family_restroom_outlined,
          accentColor: ColorUtils.corporateBlue600,
          onTap: () {
            // Navigate to children
          },
        ),
        OverviewCard(
          title: 'New Grades',
          value: _stats['unread_grades']?.toString() ?? '0',
          subtitle: 'Recent updates',
          icon: Icons.grade_outlined,
          accentColor: ColorUtils.success600,
          onTap: () {
            // Navigate to grades
          },
        ),
        if (_attendanceChartData.isNotEmpty)
          AttendanceBarChartCard(
            title: 'Kehadiran Anak',
            icon: Icons.ssid_chart_outlined,
            accentColor: ColorUtils.warning600,
            classesData: _attendanceChartData,
            hideSubtitle:
                true, // Requested by user to hide the child's name on the card
            onTap: () {
              final selectedYearId = Provider.of<AcademicYearProvider>(
                context,
                listen: false,
              ).selectedAcademicYear?['id']?.toString();

              showDialog(
                context: context,
                builder: (context) => _AttendancePopupDialog(
                  semesterLabel: _currentSemesterLabel,
                  initialData: _attendanceChartData,
                  academicYearId: selectedYearId,
                ),
              );
            },
          )
        else
          OverviewCard(
            title: 'Attendance',
            value: _stats['unread_presence']?.toString() ?? '0',
            subtitle: 'New records',
            icon: Icons.calendar_month_outlined,
            accentColor: ColorUtils.warning600,
            onTap: () {
              // Navigate to attendance
            },
          ),
        OverviewCard(
          title: 'Announcements',
          value: _stats['pengumuman_terbaru']?.toString() ?? '0',
          subtitle: 'Latest info',
          icon: Icons.announcement_outlined,
          accentColor: ColorUtils.info600,
          onTap: () {
            // Navigate to announcements
          },
        ),
      ];
    }
  }

  List<Widget> _getQuickActions() {
    final primaryColor = _getPrimaryColor();

    if (_effectiveRole == 'admin') {
      return [
        QuickActionButton(
          label: 'Data',
          icon: Icons.folder_outlined,
          color: primaryColor,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AdminDataManagementScreen(),
            ),
          ),
        ),
        QuickActionButton(
          label: 'Jadwal',
          icon: Icons.schedule_outlined,
          color: ColorUtils.info600,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TeachingScheduleManagementScreen(),
            ),
          ),
        ),
        QuickActionButton(
          label: 'Keuangan',
          icon: Icons.account_balance_wallet_outlined,
          color: ColorUtils.success600,
          badgeCount: _unverifiedPaymentCount > 0
              ? _unverifiedPaymentCount
              : null,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => FinanceScreen()),
          ),
        ),
        QuickActionButton(
          label: 'Pengumuman',
          icon: Icons.announcement_outlined,
          color: ColorUtils.warning600,
          badgeCount: _stats['unread_announcements'],
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AdminAnnouncementScreen(),
              ),
            );
            _loadStats();
          },
        ),
      ];
    } else if (_effectiveRole == 'guru') {
      return [
        QuickActionButton(
          label: 'Jadwal',
          icon: Icons.schedule_outlined,
          color: primaryColor,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => TeachingScheduleScreen()),
          ),
        ),
        QuickActionButton(
          label: 'Aktivitas',
          icon: Icons.local_activity_outlined,
          color: ColorUtils.info600,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ClassActifityScreen()),
          ),
        ),
        QuickActionButton(
          label: 'Nilai',
          icon: Icons.edit_note_outlined,
          color: ColorUtils.success600,
          onTap: () async {
            final prefs = await SharedPreferences.getInstance();
            final userData = json.decode(prefs.getString('user') ?? '{}');
            final teacherData = {
              'id': userData['id'] ?? '',
              'nama': userData['nama'] ?? 'Teacher',
              'email': userData['email'] ?? '',
              'role': _effectiveRole,
            };
            if (teacherData['id']!.isEmpty) return;
            if (!context.mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GradePage(teacher: teacherData),
              ),
            );
          },
        ),
      ];
    } else {
      return [
        QuickActionButton(
          label: 'Pengumuman',
          icon: Icons.announcement_outlined,
          color: primaryColor,
          badgeCount: _stats['unread_announcements'],
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AnnouncementScreen()),
            );
            _loadStats();
          },
        ),
        QuickActionButton(
          label: 'Tagihan',
          icon: Icons.account_balance_wallet_outlined,
          color: ColorUtils.error600,
          badgeCount: _stats['unread_billing'],
          onTap: () async {
            final academicYearId = Provider.of<AcademicYearProvider>(
              context,
              listen: false,
            ).selectedAcademicYear?['id']?.toString();

            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ParentBillingScreen()),
            );
            _loadStats();
          },
        ),
      ];
    }
  }

  // ==================== END NEW UI COMPONENTS ====================

  Widget _buildSliverGridMenu(BuildContext context) {
    // All roles now use professional MenuItemCard design
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildListDelegate(_buildCategorizedMenu(context)),
      ),
    );
  }

  List<Widget> _buildCategorizedMenu(BuildContext context) {
    final primaryColor = _getPrimaryColor();

    if (_effectiveRole == 'admin') {
      return [
        CategorySection(
          title: '📊 MANAJEMEN DATA',
          icon: Icons.folder_shared,
          accentColor: ColorUtils.slate700,
          primaryColor: primaryColor,
          items: _getAdminDataManagementItems(context),
        ),
        CategorySection(
          title: '📢 AKADEMIK & KOMUNIKASI',
          icon: Icons.school,
          accentColor: ColorUtils.slate700,
          primaryColor: primaryColor,
          items: _getAdminAcademicItems(context),
        ),
        CategorySection(
          title: '💰 KEUANGAN & PENGATURAN',
          icon: Icons.settings,
          accentColor: ColorUtils.slate700,
          primaryColor: primaryColor,
          items: _getAdminFinanceItems(context),
        ),
      ];
    } else if (_effectiveRole == 'guru') {
      return [
        CategorySection(
          title: '📚 MENGAJAR',
          icon: Icons.school,
          accentColor: ColorUtils.slate700,
          primaryColor: primaryColor,
          items: _getTeacherTeachingItems(context),
        ),
        CategorySection(
          title: '✏️ PENILAIAN & PERENCANAAN',
          icon: Icons.edit_note,
          accentColor: ColorUtils.slate700,
          primaryColor: primaryColor,
          items: _getTeacherAssessmentItems(context),
        ),
      ];
    } else if (_effectiveRole == 'wali') {
      // Parent role: Simple list without categories (only 5 items)
      final items = _getParentMenuItems(context);
      return items
          .map(
            (item) => Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: MenuItemCard(
                title: item.title,
                icon: item.icon,
                onTap: item.onTap,
                badgeCount: item.badgeCount,
                primaryColor: primaryColor,
              ),
            ),
          )
          .toList();
    }

    return [];
  }

  // Admin - Data Management Category
  List<MenuItem> _getAdminDataManagementItems(BuildContext context) {
    return [
      MenuItem(
        title: 'Kelola Data',
        icon: Icons.folder_shared_outlined,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AdminDataManagementScreen()),
        ),
      ),
      MenuItem(
        title: AppLocalizations.manageTeachingSchedule.tr,
        icon: Icons.schedule_outlined,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TeachingScheduleManagementScreen(),
          ),
        ),
      ),
      MenuItem(
        title: AppLocalizations.inputGrades.tr,
        icon: Icons.edit_note_outlined,
        onTap: () async {
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
    ];
  }

  // Admin - Academic & Communication Category
  List<MenuItem> _getAdminAcademicItems(BuildContext context) {
    return [
      MenuItem(
        title: AppLocalizations.announcements.tr,
        icon: Icons.announcement_outlined,
        badgeCount: _stats['unread_announcements'],
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AdminAnnouncementScreen()),
          );
          _loadStats();
        },
      ),
      MenuItem(
        title: AppLocalizations.classActivities.tr,
        icon: Icons.local_activity_outlined,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AdminClassActivityScreen()),
        ),
      ),
      MenuItem(
        title: AppLocalizations.presenceReport.tr,
        icon: Icons.check_circle_outline,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AdminPresenceReportScreen()),
        ),
      ),
      MenuItem(
        title: AppLocalizations.manageRpp.tr,
        icon: Icons.description_outlined,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AdminRppScreen()),
        ),
      ),
    ];
  }

  // Admin - Finance & Settings Category
  List<MenuItem> _getAdminFinanceItems(BuildContext context) {
    return [
      MenuItem(
        title: AppLocalizations.finance.tr,
        icon: Icons.account_balance_wallet_outlined,
        badgeCount: _unverifiedPaymentCount > 0
            ? _unverifiedPaymentCount
            : null,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => FinanceScreen()),
        ),
      ),
      MenuItem(
        title: AppLocalizations.schoolSettings.tr,
        icon: Icons.settings_applications,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => SchoolSettingsScreen()),
        ),
      ),
    ];
  }

  // Teacher - Teaching Category
  List<MenuItem> _getTeacherTeachingItems(BuildContext context) {
    return [
      MenuItem(
        title: AppLocalizations.teachingSchedule.tr,
        icon: Icons.schedule_outlined,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => TeachingScheduleScreen()),
        ),
      ),
      MenuItem(
        title: AppLocalizations.classActivities.tr,
        icon: Icons.local_activity_outlined,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ClassActifityScreen()),
        ),
      ),
      MenuItem(
        title: AppLocalizations.studentAttendance.tr,
        icon: Icons.check_circle_outline,
        onTap: () async {
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
      MenuItem(
        title: AppLocalizations.learningMaterials.tr,
        icon: Icons.book_outlined,
        onTap: () async {
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
    ];
  }

  // Teacher - Assessment & Planning Category
  List<MenuItem> _getTeacherAssessmentItems(BuildContext context) {
    return [
      MenuItem(
        title: AppLocalizations.inputGrades.tr,
        icon: Icons.edit_note_outlined,
        onTap: () async {
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
      MenuItem(
        title: AppLocalizations.myRpp.tr,
        icon: Icons.description_outlined,
        onTap: () async {
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
      MenuItem(
        title: AppLocalizations.announcements.tr,
        icon: Icons.announcement_outlined,
        badgeCount: _stats['unread_announcements'],
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AnnouncementScreen()),
          );
          _loadStats();
        },
      ),
    ];
  }

  // Parent - Menu Items (Simple list, no categories)
  List<MenuItem> _getParentMenuItems(BuildContext context) {
    return [
      MenuItem(
        title: AppLocalizations.announcements.tr,
        icon: Icons.announcement_outlined,
        badgeCount: _stats['unread_announcements'],
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AnnouncementScreen()),
          );
          _loadStats();
        },
      ),
      MenuItem(
        title: AppLocalizations.classActivities.tr,
        icon: Icons.local_activity_outlined,
        badgeCount: _stats['unread_class_activities'],
        onTap: () async {
          final academicYearId = Provider.of<AcademicYearProvider>(
            context,
            listen: false,
          ).selectedAcademicYear?['id']?.toString();
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ParentClassActivityScreen(academicYearId: academicYearId),
            ),
          );
          _loadStats();
        },
      ),
      MenuItem(
        title: AppLocalizations.grades.tr,
        icon: Icons.grade_outlined,
        badgeCount: _stats['unread_grades'],
        onTap: () async {
          final academicYearId = Provider.of<AcademicYearProvider>(
            context,
            listen: false,
          ).selectedAcademicYear?['id']?.toString();
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ParentGradeScreen(academicYearId: academicYearId),
            ),
          );
          _loadStats();
        },
      ),
      MenuItem(
        title: AppLocalizations.presence.tr,
        icon: Icons.check_circle_outline,
        badgeCount: _stats['unread_presence'],
        onTap: () async {
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
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PresenceParentPage(
                  parent: userData,
                  studentId: studentsData[0]['id'],
                  academicYearId: academicYearId,
                ),
              ),
            );
            _loadStats();
          } else {
            await _showStudentSelectionDialog(
              context,
              userData,
              studentsData,
              academicYearId: academicYearId,
            );
            _loadStats();
          }
        },
      ),
      MenuItem(
        title: AppLocalizations.billing.tr,
        icon: Icons.account_balance_wallet_outlined,
        badgeCount: _stats['unread_billing'],
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ParentBillingScreen()),
          );
          _loadStats();
        },
      ),
    ];
  }

  Widget _buildDashboardCard(
    String title,
    dynamic icon,
    VoidCallback onTap, {
    int? badgeCount,
  }) {
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

              // Notification Badge
              if (badgeCount != null && badgeCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : badgeCount.toString(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
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

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  // Keep existing methods for dashboard cards functionality
  List<Widget> _getDashboardCards(BuildContext context) {
    if (_effectiveRole == 'admin') {
      return [
        _buildDashboardCard(
          'Kelola Data',
          Icons.folder_shared_outlined,
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AdminDataManagementScreen(),
            ),
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
          () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AdminAnnouncementScreen(),
              ),
            );
            _loadStats();
          },
          badgeCount: _stats['unread_announcements'],
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
          badgeCount: _unverifiedPaymentCount > 0
              ? _unverifiedPaymentCount
              : null,
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
          () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AnnouncementScreen()),
            );
            _loadStats();
          },
          badgeCount: _stats['unread_announcements'],
        ),
      ];
    } else if (_effectiveRole == 'wali') {
      return [
        _buildDashboardCard(
          AppLocalizations.announcements.tr,
          Icons.announcement_outlined,
          () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AnnouncementScreen()),
            );
            _loadStats();
          },
          badgeCount: _stats['unread_announcements'],
        ),
        _buildDashboardCard(
          AppLocalizations.classActivities.tr,
          Icons.local_activity_outlined,
          () async {
            final academicYearId = Provider.of<AcademicYearProvider>(
              context,
              listen: false,
            ).selectedAcademicYear?['id']?.toString();
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ParentClassActivityScreen(academicYearId: academicYearId),
              ),
            );
            _loadStats();
          },
          badgeCount: _stats['unread_class_activities'],
        ),
        _buildDashboardCard(
          AppLocalizations.grades.tr,
          Icons.grade_outlined,
          () async {
            final academicYearId = Provider.of<AcademicYearProvider>(
              context,
              listen: false,
            ).selectedAcademicYear?['id']?.toString();
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ParentGradeScreen(academicYearId: academicYearId),
              ),
            );
            _loadStats();
          },
          badgeCount: _stats['unread_grades'],
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
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PresenceParentPage(
                    parent: userData,
                    studentId: studentsData[0]['id'],
                    academicYearId: academicYearId,
                  ),
                ),
              );
              _loadStats();
            } else {
              await _showStudentSelectionDialog(
                context,
                userData,
                studentsData,
                academicYearId: academicYearId,
              );
              _loadStats();
            }
          },
          badgeCount: _stats['unread_presence'],
        ),
        _buildDashboardCard(
          AppLocalizations.billing.tr,
          Icons.account_balance_wallet_outlined,
          () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ParentBillingScreen()),
            );
            _loadStats();
          },
          badgeCount: _stats['unread_billing'],
        ),
      ];
    }
    return [];
  }

  Future<void> _showStudentSelectionDialog(
    BuildContext context,
    Map<String, dynamic> parent,
    List<dynamic> studentData, {
    String? academicYearId,
  }) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Pilih Anak',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
                  subtitle: Text(
                    student['kelas_nama'] ?? 'Kelas tidak tersedia',
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PresenceParentPage(
                          parent: parent,
                          studentId: student['id'],
                          academicYearId: academicYearId,
                        ),
                      ),
                    );
                    _loadStats();
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _FinancePopupDialog extends StatefulWidget {
  final List<Map<String, dynamic>> semestersData;

  const _FinancePopupDialog({required this.semestersData});

  @override
  State<_FinancePopupDialog> createState() => _FinancePopupDialogState();
}

class _FinancePopupDialogState extends State<_FinancePopupDialog> {
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 380, // Fixed height for page view
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.semestersData.length,
                itemBuilder: (context, index) {
                  final item = widget.semestersData[index];
                  final subtitle = item['subtitle'] as String;
                  final title = 'Detail $subtitle';
                  final chartData = List<double>.from(
                    (item['data'] as List).map((e) => (e as num).toDouble()),
                  );
                  final isGenap = subtitle.toLowerCase().contains('genap');

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: ColorUtils.slate800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Geser ke kiri/kanan untuk melihat riwayat',
                        style: TextStyle(
                          fontSize: 12,
                          color: ColorUtils.slate500,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Use an explicit container without ScrollView so PageView catches horizontal swipe gestures
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            alignment: Alignment.center,
                            height: 200,
                            child: MiniBarChart(
                              data: chartData,
                              color: ColorUtils.success600,
                              height: 200,
                              width:
                                  chartData.length *
                                  44.0, // Reduced from 50 to 44 to better fit small screens without scrolling
                              barWidth: 28.0,
                              barSpacing: 16.0,
                              cornerRadius: 4.0,
                              showLabels: true,
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: ColorUtils.slate700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              chartData.length,
                              (idx) => Container(
                                width:
                                    44.0, // Matching the new total width unit
                                alignment: Alignment.center,
                                child: Text(
                                  [
                                    'Jan',
                                    'Feb',
                                    'Mar',
                                    'Apr',
                                    'Mei',
                                    'Jun',
                                    'Jul',
                                    'Ags',
                                    'Sep',
                                    'Okt',
                                    'Nov',
                                    'Des',
                                  ][isGenap ? idx : (idx + 6)],
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: ColorUtils.slate600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SmoothPageIndicator(
              controller: _pageController,
              count: widget.semestersData.length,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorUtils.success600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text('Tutup'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendancePopupDialog extends StatefulWidget {
  final String? semesterLabel;
  final List<Map<String, dynamic>>? initialData;
  final String? academicYearId;

  const _AttendancePopupDialog({
    this.semesterLabel,
    this.initialData,
    this.academicYearId,
  });

  @override
  State<_AttendancePopupDialog> createState() => _AttendancePopupDialogState();
}

class _AttendancePopupDialogState extends State<_AttendancePopupDialog> {
  final PageController _pageController = PageController();

  bool _isWeekly = true;
  late String _selectedMonth;
  String _selectedWeek = 'Pekan 1';

  late List<String> _months;
  final List<String> _weeks = [
    'Pekan 1',
    'Pekan 2',
    'Pekan 3',
    'Pekan 4',
    'Pekan 5',
  ];

  bool _isLoading = false;
  List<Map<String, dynamic>> _classesData = [];

  @override
  void initState() {
    super.initState();
    // Default to Ganjil (Juli-Desember) if semester isn't identified
    final isGenap =
        widget.semesterLabel?.toLowerCase().contains('genap') ?? false;

    if (isGenap) {
      _months = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni'];
    } else {
      _months = [
        'Juli',
        'Agustus',
        'September',
        'Oktober',
        'November',
        'Desember',
      ];
    }

    final now = DateTime.now();
    final allMonths = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    final currentMonthName = allMonths[now.month - 1];

    // Check if the current month is applicable for the chosen semester
    if (_months.contains(currentMonthName)) {
      _selectedMonth = currentMonthName;
    } else {
      _selectedMonth = _months.first;
    }

    int currentWeek = (now.day / 7).ceil();
    if (currentWeek > 5) currentWeek = 5;
    _selectedWeek = 'Pekan $currentWeek';

    // Load initial data if available, or fetch fresh
    if (widget.initialData != null && widget.initialData!.isNotEmpty) {
      _classesData = List.from(widget.initialData!);
    } else {
      _fetchData();
    }
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final fetchedData = await ApiService.getAttendanceDashboardChart(
        academicYearId: widget.academicYearId,
        month: _selectedMonth,
        week: _selectedWeek,
      );

      if (mounted) {
        setState(() {
          _classesData = List<Map<String, dynamic>>.from(fetchedData);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // You could show a snackbar here
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _isLoading
                ? SizedBox(
                    height: 380,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: ColorUtils.warning600,
                      ),
                    ),
                  )
                : _classesData.isEmpty
                ? const SizedBox(
                    height: 380,
                    child: Center(
                      child: Text('Tidak ada data absensi untuk periode ini'),
                    ),
                  )
                : SizedBox(
                    height: 380, // Fixed height for page view
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _classesData.length,
                      itemBuilder: (context, index) {
                        final item = _classesData[index];
                        final title = item['title'] as String;
                        final List<double> chartData = _isWeekly
                            ? List<double>.from(
                                (item['weekly_data'] as List).map(
                                  (e) => (e as num).toDouble(),
                                ),
                              )
                            : List<double>.from(
                                (item['daily_data'] as List).map(
                                  (e) => (e as num).toDouble(),
                                ),
                              );

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: ColorUtils.slate800,
                                    ),
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    _buildTypeDropdown(),
                                    const SizedBox(height: 8),
                                    _isWeekly
                                        ? _buildMonthDropdown()
                                        : _buildWeekDropdown(),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Geser ke kiri/kanan untuk berpindah kelas',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: ColorUtils.slate500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            if (title == 'Absensi Belum Ada Data' ||
                                chartData.every((val) => val == 0.0))
                              SizedBox(
                                height:
                                    212, // match the height of 200 MiniBarChart + 12 spaces
                                child: Center(
                                  child: Text(
                                    'Belum ada data kehadiran siswa pada periode ini',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: ColorUtils.slate400,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              )
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    alignment: Alignment.center,
                                    height: 200,
                                    child: MiniBarChart(
                                      data: chartData,
                                      color: ColorUtils.warning600,
                                      height: 200,
                                      width: chartData.length * 44.0,
                                      barWidth: 22.0,
                                      barSpacing: 22.0,
                                      cornerRadius: 4.0,
                                      showLabels: true,
                                      labelStyle: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: ColorUtils.slate700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(
                                      chartData.length,
                                      (idx) => Container(
                                        width:
                                            44.0, // Matching the new total width unit
                                        alignment: Alignment.center,
                                        child: Text(
                                          _isWeekly
                                              ? 'Pekan ${idx + 1}'
                                              : [
                                                  'Sen',
                                                  'Sel',
                                                  'Rab',
                                                  'Kam',
                                                  'Jum',
                                                  'Sab',
                                                ][idx],
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: ColorUtils.slate600,
                                          ),
                                          maxLines: 1, // Prevent wrapping
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        );
                      },
                    ),
                  ),
            const SizedBox(height: 16),
            SmoothPageIndicator(
              controller: _pageController,
              count: _classesData.length,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorUtils.warning600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text('Tutup'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeDropdown() {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: ColorUtils.slate200),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _isWeekly ? 'Pekanan' : 'Harian',
          icon: Icon(
            Icons.keyboard_arrow_down,
            size: 16,
            color: ColorUtils.slate500,
          ),
          isDense: true,
          style: TextStyle(
            fontSize: 12,
            color: ColorUtils.slate700,
            fontWeight: FontWeight.w500,
          ),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _isWeekly = newValue == 'Pekanan';
              });
            }
          },
          items: ['Harian', 'Pekanan'].map<DropdownMenuItem<String>>((
            String value,
          ) {
            return DropdownMenuItem<String>(value: value, child: Text(value));
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMonthDropdown() {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: ColorUtils.slate200),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedMonth,
          icon: Icon(
            Icons.keyboard_arrow_down,
            size: 14,
            color: ColorUtils.slate500,
          ),
          isDense: true,
          style: TextStyle(
            fontSize: 10,
            color: ColorUtils.slate700,
            fontWeight: FontWeight.w500,
          ),
          onChanged: (String? newValue) {
            if (newValue != null && newValue != _selectedMonth) {
              setState(() {
                _selectedMonth = newValue;
              });
              _fetchData();
            }
          },
          items: _months.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(value: value, child: Text(value));
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildWeekDropdown() {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: ColorUtils.slate200),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedWeek,
          icon: Icon(
            Icons.keyboard_arrow_down,
            size: 14,
            color: ColorUtils.slate500,
          ),
          isDense: true,
          style: TextStyle(
            fontSize: 10,
            color: ColorUtils.slate700,
            fontWeight: FontWeight.w500,
          ),
          onChanged: (String? newValue) {
            if (newValue != null && newValue != _selectedWeek) {
              setState(() {
                _selectedWeek = newValue;
              });
              _fetchData();
            }
          },
          items: _weeks.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(value: value, child: Text(value));
          }).toList(),
        ),
      ),
    );
  }
}
