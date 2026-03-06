import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider with ChangeNotifier {
  static const String ENGLISH = 'en';
  static const String INDONESIAN = 'id';

  String _currentLanguage = INDONESIAN;

  String get currentLanguage => _currentLanguage;

  Future<void> setLanguage(String language) async {
    _currentLanguage = language;

    // Save to shared preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', language);

    notifyListeners(); // Notify all listeners about the change
  }

  // Load saved language
  Future<void> loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLanguage = prefs.getString('language') ?? INDONESIAN;
    _currentLanguage = savedLanguage;
    notifyListeners();
  }

  String getTranslatedText(Map<String, String> translations) {
    return translations[_currentLanguage] ?? translations[INDONESIAN] ?? '';
  }
}

// Singleton instance
LanguageProvider languageProvider = LanguageProvider();

// Extension untuk memudahkan penggunaan
extension LocalizedString on Map<String, String> {
  String get tr {
    return languageProvider.getTranslatedText(this);
  }
}

class AppLocalizations {
  // Dashboard
  static Map<String, String> get appTitle => {
    'en': 'School Management',
    'id': 'Manajemen Sekolah',
  };

  // Tambahkan di class AppLocalizations

  // Class Management
  static Map<String, String> get editClass => {
    'en': 'Edit Class',
    'id': 'Edit Kelas',
  };

  static Map<String, String> get addClass => {
    'en': 'Add Class',
    'id': 'Tambah Kelas',
  };

  static Map<String, String> get className => {
    'en': 'Class Name',
    'id': 'Nama Kelas',
  };

  static Map<String, String> get classNameRequired => {
    'en': 'Class name is required',
    'id': 'Nama kelas harus diisi',
  };

  static Map<String, String> get gradeLevel => {
    'en': 'Grade Level',
    'id': 'Tingkat Kelas',
  };

  static Map<String, String> get retry => {'en': 'Retry', 'id': 'Ulang'};

  static Map<String, String> get gradeLevelRequired => {
    'en': 'Grade level is required',
    'id': 'Tingkat kelas harus dipilih',
  };

  static Map<String, String> get selectGradeLevel => {
    'en': 'Select Grade Level',
    'id': 'Pilih Tingkat Kelas',
  };

  static Map<String, String> get homeroomTeacher => {
    'en': 'Homeroom Teacher',
    'id': 'Wali Kelas',
  };

  static Map<String, String> get noTeacher => {
    'en': 'No Teacher',
    'id': 'Tidak Ada Guru',
  };

  static Map<String, String> get update => {'en': 'Update', 'id': 'Perbarui'};

  static Map<String, String> get classDetails => {
    'en': 'Class Details',
    'id': 'Detail Kelas',
  };

  static Map<String, String> get numberOfStudents => {
    'en': 'Number of Students',
    'id': 'Jumlah Siswa',
  };

  static Map<String, String> get notAssigned => {
    'en': 'Not assigned',
    'id': 'Tidak ada',
  };

  static Map<String, String> get classesFound => {
    'en': 'classes found',
    'id': 'kelas ditemukan',
  };

  static Map<String, String> get noClasses => {
    'en': 'No classes',
    'id': 'Tidak ada kelas',
  };

  static Map<String, String> get tapToAddClass => {
    'en': 'Tap + to add a class',
    'id': 'Tap + untuk menambah kelas',
  };

  static Map<String, String> get searchClasses => {
    'en': 'Search classes...',
    'id': 'Cari kelas...',
  };

  static Map<String, String> get loadingClassData => {
    'en': 'Loading class data...',
    'id': 'Memuat data kelas...',
  };

  static Map<String, String> get classSuccessfullyUpdated => {
    'en': 'Class successfully updated',
    'id': 'Kelas berhasil diperbarui',
  };

  static Map<String, String> get classSuccessfullyAdded => {
    'en': 'Class successfully added',
    'id': 'Kelas berhasil ditambahkan',
  };

  static Map<String, String> get classSuccessfullyDeleted => {
    'en': 'Class successfully deleted',
    'id': 'Kelas berhasil dihapus',
  };

  static Map<String, String> get failedToSaveClass => {
    'en': 'Failed to save class',
    'id': 'Gagal menyimpan kelas',
  };

  static Map<String, String> get failedToDeleteClass => {
    'en': 'Failed to delete class',
    'id': 'Gagal menghapus kelas',
  };

  static Map<String, String> get areYouSureDeleteClass => {
    'en': 'Are you sure you want to delete this class?',
    'id': 'Apakah Anda yakin ingin menghapus kelas ini?',
  };

  // Filter Options
  static Map<String, String> get all => {'en': 'All', 'id': 'Semua'};

  static Map<String, String> get withHomeroomTeacher => {
    'en': 'With Homeroom Teacher',
    'id': 'Dengan Wali Kelas',
  };

  static Map<String, String> get withoutHomeroomTeacher => {
    'en': 'Without Homeroom Teacher',
    'id': 'Tanpa Wali Kelas',
  };

  static Map<String, String> get welcome => {
    'en': 'Welcome,',
    'id': 'Selamat datang,',
  };

  static Map<String, String> get activeAccount => {
    'en': 'Active account',
    'id': 'Akun aktif',
  };

  static Map<String, String> get searchHint => {
    'en': 'Search features, data, or menus...',
    'id': 'Cari fitur, data, atau menu...',
  };

  static Map<String, String> get logout => {'en': 'Logout', 'id': 'Keluar'};

  static Map<String, String> get settings => {
    'en': 'Settings',
    'id': 'Pengaturan',
  };

  // Common
  static Map<String, String> get save => {'en': 'Save', 'id': 'Simpan'};

  static Map<String, String> get cancel => {'en': 'Cancel', 'id': 'Batal'};

  static Map<String, String> get edit => {'en': 'Edit', 'id': 'Edit'};

  static Map<String, String> get delete => {'en': 'Delete', 'id': 'Hapus'};

  static Map<String, String> get add => {'en': 'Add', 'id': 'Tambah'};

  static Map<String, String> get refresh => {
    'en': 'Refresh',
    'id': 'Muat Ulang',
  };

  static Map<String, String> get search => {'en': 'Search', 'id': 'Cari'};

  static Map<String, String> get loading => {
    'en': 'Loading...',
    'id': 'Memuat...',
  };

  static Map<String, String> get noData => {
    'en': 'No data',
    'id': 'Tidak ada data',
  };

  static Map<String, String> get noSearchResults => {
    'en': 'No search results found',
    'id': 'Tidak ditemukan hasil pencarian',
  };

  // Menu Items
  static Map<String, String> get manageStudents => {
    'en': 'Manage Students',
    'id': 'Kelola Siswa',
  };

  static Map<String, String> get manageTeachers => {
    'en': 'Manage Teachers',
    'id': 'Kelola Guru',
  };

  static Map<String, String> get manageClasses => {
    'en': 'Manage Classes',
    'id': 'Kelola Kelas',
  };

  static Map<String, String> get manageSubjects => {
    'en': 'Manage Subjects',
    'id': 'Kelola Mata Pelajaran',
  };

  static Map<String, String> get manageTeachingSchedule => {
    'en': 'Manage Schedule',
    'id': 'Kelola Jadwal',
  };

  static Map<String, String> get reports => {'en': 'Reports', 'id': 'Laporan'};

  static Map<String, String> get finance => {'en': 'Finance', 'id': 'Keuangan'};

  static Map<String, String> get announcements => {
    'en': 'Announcements',
    'id': 'Pengumuman',
  };

  static Map<String, String> get studentAttendance => {
    'en': 'Student Attendance',
    'id': 'Absensi Siswa',
  };

  static Map<String, String> get inputGrades => {'en': 'Grades', 'id': 'Nilai'};

  static Map<String, String> get teachingSchedule => {
    'en': 'Teaching Schedule',
    'id': 'Jadwal Mengajar',
  };

  static Map<String, String> get classActivities => {
    'en': 'Class Activities',
    'id': 'Kegiatan Kelas',
  };

  static Map<String, String> get rppLearningMaterials => {
    'en': 'Learning Materials',
    'id': 'Materi Pembelajaran',
  };

  // TAMBAHKAN MENU RPP
  static Map<String, String> get myRpp => {
    'en': 'My Lesson Plans',
    'id': 'RPP Saya',
  };

  static Map<String, String> get manageRpp => {
    'en': 'Manage Lesson Plans',
    'id': 'Kelola RPP',
  };

  // Tambahkan di class AppLocalizations
  static Map<String, String> get tryAgain => {
    'en': 'Try Again',
    'id': 'Coba Lagi',
  };

  static Map<String, String> get close => {'en': 'Close', 'id': 'Tutup'};

  // Role Titles
  static Map<String, String> get adminRole => {'en': 'Admin', 'id': 'Admin'};

  static Map<String, String> get teacherRole => {'en': 'Teacher', 'id': 'Guru'};

  static Map<String, String> get staffRole => {'en': 'Staff', 'id': 'Staff'};

  static Map<String, String> get parentRole => {
    'en': 'Parent',
    'id': 'Wali Murid',
  };

  // Login Screen
  static Map<String, String> get login => {'en': 'Login', 'id': 'Masuk'};

  static Map<String, String> get email => {'en': 'Email', 'id': 'Email'};

  static Map<String, String> get password => {
    'en': 'Password',
    'id': 'Kata Sandi',
  };

  static Map<String, String> get forgotPassword => {
    'en': 'Forgot Password?',
    'id': 'Lupa Kata Sandi?',
  };

  static Map<String, String> get loginSuccess => {
    'en': 'Login Successful',
    'id': 'Login Berhasil',
  };

  static Map<String, String> get loginError => {
    'en': 'Login Failed',
    'id': 'Login Gagal',
  };

  // Confirmation dialogs
  static Map<String, String> get confirmDelete => {
    'en': 'Confirm Delete',
    'id': 'Konfirmasi Hapus',
  };

  static Map<String, String> get areYouSure => {
    'en': 'Are you sure?',
    'id': 'Apakah Anda yakin?',
  };

  // Form fields
  static Map<String, String> get name => {'en': 'Name', 'id': 'Nama'};

  static Map<String, String> get class_ => {'en': 'Class', 'id': 'Kelas'};

  static Map<String, String> get subject => {
    'en': 'Subject',
    'id': 'Mata Pelajaran',
  };

  static Map<String, String> get teacher => {'en': 'Teacher', 'id': 'Guru'};

  static Map<String, String> get schedule => {'en': 'Schedule', 'id': 'Jadwal'};

  // Success messages
  static Map<String, String> get success => {'en': 'Success', 'id': 'Berhasil'};

  static Map<String, String> get error => {'en': 'Error', 'id': 'Error'};

  // Time related
  static Map<String, String> get startTime => {
    'en': 'Start Time',
    'id': 'Jam Mulai',
  };

  static Map<String, String> get endTime => {
    'en': 'End Time',
    'id': 'Jam Selesai',
  };

  static Map<String, String> get day => {'en': 'Day', 'id': 'Hari'};

  // ========== TAMBAHAN UNTUK FITUR RPP ==========

  // RPP Screen Titles
  static Map<String, String> get rpp => {
    'en': 'Lesson Plan',
    'id': 'Rencana Pelaksanaan Pembelajaran',
  };

  static Map<String, String> get rppList => {
    'en': 'Lesson Plan List',
    'id': 'Daftar RPP',
  };

  static Map<String, String> get createRpp => {
    'en': 'Create Lesson Plan',
    'id': 'Buat RPP',
  };

  static Map<String, String> get editRpp => {
    'en': 'Edit Lesson Plan',
    'id': 'Edit RPP',
  };

  // RPP Status
  static Map<String, String> get status => {'en': 'Status', 'id': 'Status'};

  static Map<String, String> get pending => {'en': 'Pending', 'id': 'Menunggu'};

  static Map<String, String> get approved => {
    'en': 'Approved',
    'id': 'Disetujui',
  };

  static Map<String, String> get rejected => {
    'en': 'Rejected',
    'id': 'Ditolak',
  };

  // RPP Form Fields
  static Map<String, String> get title => {'en': 'Title', 'id': 'Judul'};

  static Map<String, String> get semester => {
    'en': 'Semester',
    'id': 'Semester',
  };

  static Map<String, String> get academicYear => {
    'en': 'Academic Year',
    'id': 'Tahun Ajaran',
  };

  static Map<String, String> get coreCompetence => {
    'en': 'Core Competence',
    'id': 'Kompetensi Inti',
  };

  static Map<String, String> get basicCompetence => {
    'en': 'Basic Competence',
    'id': 'Kompetensi Dasar',
  };

  static Map<String, String> get indicators => {
    'en': 'Indicators',
    'id': 'Indikator',
  };

  static Map<String, String> get learningObjectives => {
    'en': 'Learning Objectives',
    'id': 'Tujuan Pembelajaran',
  };

  static Map<String, String> get learningMaterials => {
    'en': 'Learning Materials',
    'id': 'Materi Pembelajaran',
  };

  static Map<String, String> get learningMethods => {
    'en': 'Learning Methods',
    'id': 'Metode Pembelajaran',
  };

  static Map<String, String> get mediaTools => {
    'en': 'Media & Tools',
    'id': 'Media dan Alat',
  };

  static Map<String, String> get learningResources => {
    'en': 'Learning Resources',
    'id': 'Sumber Belajar',
  };

  static Map<String, String> get learningActivities => {
    'en': 'Learning Activities',
    'id': 'Kegiatan Pembelajaran',
  };

  static Map<String, String> get assessment => {
    'en': 'Assessment',
    'id': 'Penilaian',
  };

  static Map<String, String> get attachment => {
    'en': 'Attachment',
    'id': 'Lampiran',
  };

  // RPP Actions
  static Map<String, String> get createNewRpp => {
    'en': 'Create New Lesson Plan',
    'id': 'Buat RPP Baru',
  };

  static Map<String, String> get viewRpp => {
    'en': 'View Lesson Plan',
    'id': 'Lihat RPP',
  };

  static Map<String, String> get downloadRpp => {
    'en': 'Download Lesson Plan',
    'id': 'Unduh RPP',
  };

  static Map<String, String> get uploadFile => {
    'en': 'Upload File',
    'id': 'Unggah File',
  };

  static Map<String, String> get chooseFile => {
    'en': 'Choose File',
    'id': 'Pilih File',
  };

  static Map<String, String> get fileSelected => {
    'en': 'File Selected',
    'id': 'File Terpilih',
  };

  // RPP Messages
  static Map<String, String> get noRppAvailable => {
    'en': 'No lesson plans available',
    'id': 'Belum ada RPP',
  };

  static Map<String, String> get rppCreatedSuccess => {
    'en': 'Lesson plan created successfully',
    'id': 'RPP berhasil dibuat',
  };

  static Map<String, String> get rppUpdatedSuccess => {
    'en': 'Lesson plan updated successfully',
    'id': 'RPP berhasil diperbarui',
  };

  static Map<String, String> get rppDeletedSuccess => {
    'en': 'Lesson plan deleted successfully',
    'id': 'RPP berhasil dihapus',
  };

  static Map<String, String> get rppStatusUpdated => {
    'en': 'Lesson plan status updated',
    'id': 'Status RPP berhasil diupdate',
  };

  // File Upload
  static Map<String, String> get fileUploadSuccess => {
    'en': 'File uploaded successfully',
    'id': 'File berhasil diunggah',
  };

  static Map<String, String> get fileUploadError => {
    'en': 'File upload failed',
    'id': 'Gagal mengunggah file',
  };

  static Map<String, String> get invalidFileType => {
    'en': 'Invalid file type. Please upload Word or PDF files only.',
    'id': 'Tipe file tidak valid. Harap unggah file Word atau PDF saja.',
  };

  static Map<String, String> get fileTooLarge => {
    'en': 'File too large. Maximum size is 10MB.',
    'id': 'File terlalu besar. Ukuran maksimal 10MB.',
  };

  // Admin RPP Management
  static Map<String, String> get allRpp => {
    'en': 'All Lesson Plans',
    'id': 'Semua RPP',
  };

  static Map<String, String> get filterByStatus => {
    'en': 'Filter by Status',
    'id': 'Filter Berdasarkan Status',
  };

  static Map<String, String> get teacherName => {
    'en': 'Teacher Name',
    'id': 'Nama Guru',
  };

  static Map<String, String> get subjectName => {
    'en': 'Subject Name',
    'id': 'Nama Mata Pelajaran',
  };

  // static Map<String, String> get className => {
  //   'en': 'Class Name',
  //   'id': 'Nama Kelas',
  // };

  static Map<String, String> get creationDate => {
    'en': 'Creation Date',
    'id': 'Tanggal Dibuat',
  };

  static Map<String, String> get updateStatus => {
    'en': 'Update Status',
    'id': 'Update Status',
  };

  static Map<String, String> get adminNotes => {
    'en': 'Admin Notes',
    'id': 'Catatan Admin',
  };

  static Map<String, String> get notesOptional => {
    'en': 'Notes (Optional)',
    'id': 'Catatan (Opsional)',
  };

  static Map<String, String> get approveRpp => {
    'en': 'Approve Lesson Plan',
    'id': 'Setujui RPP',
  };

  static Map<String, String> get rejectRpp => {
    'en': 'Reject Lesson Plan',
    'id': 'Tolak RPP',
  };

  // RPP Details
  static Map<String, String> get rppDetails => {
    'en': 'Lesson Plan Details',
    'id': 'Detail RPP',
  };

  static Map<String, String> get basicInfo => {
    'en': 'Basic Information',
    'id': 'Informasi Dasar',
  };

  static Map<String, String> get learningComponents => {
    'en': 'Learning Components',
    'id': 'Komponen Pembelajaran',
  };

  static Map<String, String> get assessmentMethods => {
    'en': 'Assessment Methods',
    'id': 'Metode Penilaian',
  };

  // Empty States
  static Map<String, String> get noRppCreated => {
    'en': 'No lesson plans created yet',
    'id': 'Belum ada RPP yang dibuat',
  };

  static Map<String, String> get clickPlusToCreate => {
    'en': 'Press the + button to create a lesson plan',
    'id': 'Tekan tombol + untuk membuat RPP',
  };

  static Map<String, String> get viewAndManageRpp => {
    'en': 'View and manage your lesson plans',
    'id': 'Lihat dan kelola RPP Anda',
  };

  static Map<String, String> get noRppForFilter => {
    'en': 'No lesson plans found for the selected filter',
    'id': 'Tidak ada RPP untuk filter yang dipilih',
  };

  // Validation Messages
  static Map<String, String> get titleRequired => {
    'en': 'Title is required',
    'id': 'Judul harus diisi',
  };

  static Map<String, String> get subjectRequired => {
    'en': 'Subject is required',
    'id': 'Mata pelajaran harus dipilih',
  };

  static Map<String, String> get semesterRequired => {
    'en': 'Semester is required',
    'id': 'Semester harus dipilih',
  };

  static Map<String, String> get academicYearRequired => {
    'en': 'Academic year is required',
    'id': 'Tahun ajaran harus diisi',
  };

  // File Types
  static Map<String, String> get wordDocument => {
    'en': 'Word Document',
    'id': 'Dokumen Word',
  };

  static Map<String, String> get pdfDocument => {
    'en': 'PDF Document',
    'id': 'Dokumen PDF',
  };

  static Map<String, String> get supportedFormats => {
    'en': 'Supported formats: .doc, .docx, .pdf',
    'id': 'Format yang didukung: .doc, .docx, .pdf',
  };

  static Map<String, String> get selectAndOrganizeMaterials => {
    'en': 'Select and organize your teaching materials',
    'id': 'Pilih dan kelola materi pembelajaran Anda',
  };

  // Missing Keys
  static Map<String, String> get presence => {
    'en': 'Presence',
    'id': 'Kehadiran',
  };

  static Map<String, String> get billing => {'en': 'Billing', 'id': 'Tagihan'};

  static Map<String, String> get materi => {'en': 'Materials', 'id': 'Materi'};

  // Dashboard Statistics
  static Map<String, String> get chooseLanguage => {
    'en': 'Choose Language',
    'id': 'Pilih Bahasa',
  };

  static Map<String, String> get totalStudents => {
    'en': 'Total Students',
    'id': 'Total Siswa',
  };

  static Map<String, String> get totalTeachers => {
    'en': 'Total Teachers',
    'id': 'Total Guru',
  };

  static Map<String, String> get totalClasses => {
    'en': 'Total Classes',
    'id': 'Total Kelas',
  };

  static Map<String, String> get switchRole => {
    'en': 'Switch Role',
    'id': 'Ganti Role',
  };

  static Map<String, String> get switchSchool => {
    'en': 'Switch School',
    'id': 'Ganti Sekolah',
  };

  static Map<String, String> get registered => {
    'en': 'Registered',
    'id': 'Terdaftar',
  };

  static Map<String, String> get active => {'en': 'Active', 'id': 'Aktif'};

  static Map<String, String> get available => {
    'en': 'Available',
    'id': 'Tersedia',
  };

  static Map<String, String> get supervised => {
    'en': 'Supervised',
    'id': 'Diampu',
  };

  static Map<String, String> get todaysClasses => {
    'en': "Today's Classes",
    'id': 'Kelas Hari Ini',
  };

  static Map<String, String> get subjects => {
    'en': 'Subjects',
    'id': 'Mata Pelajaran',
  };

  static Map<String, String> get ongoing => {
    'en': 'Ongoing',
    'id': 'Sedang berlangsung',
  };

  static Map<String, String> get submitted => {
    'en': 'Submitted',
    'id': 'Terkirim',
  };

  static Map<String, String> get presenceReport => {
    'en': 'Presence Report',
    'id': 'Laporan Presensi',
  };

  static Map<String, String> get schoolSettings => {
    'en': 'School Settings',
    'id': 'Pengaturan Sekolah',
  };

  // Parent Dashboard
  static Map<String, String> get latestInfo => {
    'en': 'Latest Info',
    'id': 'Info terbaru',
  };

  static Map<String, String> get childrenData => {
    'en': 'Children Data',
    'id': 'Data Anak',
  };

  static Map<String, String> get registeredChildren => {
    'en': 'Registered Children',
    'id': 'Anak terdaftar',
  };

  static Map<String, String> get grades => {'en': 'Grades', 'id': 'Nilai'};

  // Parent Grade Screen
  static Map<String, String> get noChildrenLinked => {
    'en': 'No student/child linked to this account',
    'id': 'Tidak ada data siswa/anak yang terhubung dengan akun ini',
  };
  static Map<String, String> get selectChild => {
    'en': 'Select Child:',
    'id': 'Pilih Anak:',
  };
  static Map<String, String> get nameNotAvailable => {
    'en': 'Name not available',
    'id': 'Nama tidak tersedia',
  };
  static Map<String, String> get classString => {'en': 'Class', 'id': 'Kelas'};

  static Map<String, String> get assessmentDate => {
    'en': 'Assessment Date',
    'id': 'Tanggal Penilaian',
  };
  static Map<String, String> get teacherNotes => {
    'en': 'Teacher Notes',
    'id': 'Catatan Guru',
  };
  static Map<String, String> get selectChildToViewGrades => {
    'en': 'Select child first to view grades',
    'id': 'Pilih anak terlebih dahulu untuk melihat nilai',
  };
  static Map<String, String> get noGradesData => {
    'en': 'No grades data for this child',
    'id': 'Belum ada data nilai untuk anak ini',
  };
  static Map<String, String> get childAcademicGrades => {
    'en': 'Child Academic Grades',
    'id': 'Nilai Akademik Anak',
  };
  static Map<String, String> get monitorChildGrades => {
    'en': 'Monitor your child\'s grade progress',
    'id': 'Pantau perkembangan nilai anak Anda',
  };

  static Map<String, String> get unknown => {
    'en': 'Unknown',
    'id': 'Tidak Diketahui',
  };

  // Parent Activity Screen
  static Map<String, String> get activityTitle => {
    'en': 'Activity Title',
    'id': 'Judul Kegiatan',
  };

  static Map<String, String> get date => {'en': 'Date', 'id': 'Tanggal'};
  static Map<String, String> get deadline => {
    'en': 'Deadline',
    'id': 'Batas Waktu',
  };
  static Map<String, String> get description => {
    'en': 'Description',
    'id': 'Deskripsi',
  };
  static Map<String, String> get chapterInfo => {
    'en': 'Chapter Info',
    'id': 'Informasi Bab',
  };
  static Map<String, String> get chapter => {'en': 'Chapter', 'id': 'Bab'};
  static Map<String, String> get mainSubChapter => {
    'en': 'Main Sub-chapter',
    'id': 'Sub Bab (Utama)',
  };
  static Map<String, String> get additionalSubChapter => {
    'en': 'Additional Sub-chapter',
    'id': 'Sub Bab (Tambahan)',
  };
  static Map<String, String> get selectChildToViewActivity => {
    'en': 'Select child first to view activities',
    'id': 'Pilih anak terlebih dahulu untuk melihat aktivitas',
  };
  static Map<String, String> get noActivityForChild => {
    'en': 'No activity for this child',
    'id': 'Belum ada aktivitas untuk anak ini',
  };
  static Map<String, String> get childClassActivity => {
    'en': 'Child Class Activity',
    'id': 'Aktivitas Kelas Anak',
  };
  static Map<String, String> get monitorChildActivity => {
    'en': 'Monitor your child\'s activity',
    'id': 'Pantau aktivitas anak Anda',
  };
  static Map<String, String> get assignment => {
    'en': 'ASSIGNMENT',
    'id': 'TUGAS',
  };
  static Map<String, String> get material => {'en': 'MATERIAL', 'id': 'MATERI'};

  // Parent Billing Screen
  static Map<String, String> get myBills => {
    'en': 'My Bills',
    'id': 'Tagihan Saya',
  };
  static Map<String, String> get manageBillPayments => {
    'en': 'Manage bill payments',
    'id': 'Kelola pembayaran tagihan',
  };
  static Map<String, String> get searchBills => {
    'en': 'Search bills...',
    'id': 'Cari tagihan...',
  };
  static Map<String, String> get paymentStatus => {
    'en': 'Payment Status',
    'id': 'Status Pembayaran',
  };
  static Map<String, String> get paid => {'en': 'Paid', 'id': 'Lunas'};

  static Map<String, String> get waitingForVerification => {
    'en': 'Waiting for Verification',
    'id': 'Menunggu Verifikasi',
  };
  static Map<String, String> get paymentPeriod => {
    'en': 'Payment Period',
    'id': 'Periode Pembayaran',
  };
  static Map<String, String> get monthly => {'en': 'Monthly', 'id': 'Bulanan'};
  static Map<String, String> get yearly => {'en': 'Yearly', 'id': 'Tahunan'};
  static Map<String, String> get filter => {'en': 'Filter', 'id': 'Filter'};
  static Map<String, String> get apply => {'en': 'Apply', 'id': 'Terapkan'};

  static Map<String, String> get reset => {'en': 'Reset', 'id': 'Reset'};
  static Map<String, String> get chooseSource => {
    'en': 'Choose Source',
    'id': 'Pilih Sumber',
  };
  static Map<String, String> get chooseImageSource => {
    'en': 'Choose image source',
    'id': 'Pilih sumber gambar',
  };
  static Map<String, String> get gallery => {'en': 'Gallery', 'id': 'Galeri'};
  static Map<String, String> get camera => {'en': 'Camera', 'id': 'Kamera'};
  static Map<String, String> get unsupportedFileFormat => {
    'en': 'Unsupported file format. Only JPG, JPEG, and PNG are allowed.',
    'id':
        'Format file tidak didukung. Hanya JPG, JPEG, dan PNG yang diizinkan.',
  };
  static Map<String, String> get chooseFileType => {
    'en': 'Choose File Type',
    'id': 'Pilih Jenis File',
  };
  static Map<String, String> get imageCameraGallery => {
    'en': 'Image (Camera/Gallery)',
    'id': 'Gambar (Kamera/Galeri)',
  };

  static Map<String, String> get uploadPaymentProof => {
    'en': 'Upload Payment Proof',
    'id': 'Upload Bukti Pembayaran',
  };
  static Map<String, String> get billAmount => {
    'en': 'Bill Amount',
    'id': 'Jumlah Tagihan',
  };
  static Map<String, String> get student => {'en': 'Student', 'id': 'Siswa'};
  static Map<String, String> get payNow => {
    'en': 'Pay Now',
    'id': 'Bayar Sekarang',
  };

  // Parent Presence Screen
  static Map<String, String> get childPresence => {
    'en': 'Child Presence',
    'id': 'Absensi Anak',
  };
  static Map<String, String> get studentName => {
    'en': 'Student Name',
    'id': 'Nama Siswa',
  };
  static Map<String, String> get monthlyRecap => {
    'en': 'Monthly Recap',
    'id': 'Rekap Bulanan',
  };
  static Map<String, String> get attendanceRate => {
    'en': 'Attendance Rate',
    'id': 'Tingkat Kehadiran',
  };
  static Map<String, String> get present => {'en': 'Present', 'id': 'Hadir'};
  static Map<String, String> get late => {
    'en': 'Late',
    'id': 'Terlambat',
  }; // late is reserved keyword in dart? No.
  static Map<String, String> get permission => {
    'en': 'Permission',
    'id': 'Izin',
  };
  static Map<String, String> get sick => {'en': 'Sick', 'id': 'Sakit'};
  static Map<String, String> get alpha => {'en': 'Alpha', 'id': 'Alpha'};
  static Map<String, String> get presenceHistory => {
    'en': 'Presence History',
    'id': 'Riwayat Absensi',
  };
  static Map<String, String> get noPresenceData => {
    'en': 'No presence data',
    'id': 'Tidak ada data absensi',
  };
  static Map<String, String> get forMonth => {
    'en': 'For month',
    'id': 'Untuk bulan',
  };
  static Map<String, String> get loadingPresenceData => {
    'en': 'Loading presence data...',
    'id': 'Memuat data absensi...',
  };

  // Finance
  static Map<String, String> get financialManagement => {
    'en': 'Financial Management',
    'id': 'Manajemen Keuangan',
  };

  static Map<String, String> get dashboard => {
    'en': 'Dashboard',
    'id': 'Dashboard',
  };

  static Map<String, String> get paymentTypes => {
    'en': 'Payment Types',
    'id': 'Jenis Pembayaran',
  };

  static Map<String, String> get verification => {
    'en': 'Verification',
    'id': 'Verifikasi',
  };

  static Map<String, String> get monthlyIncome => {
    'en': 'Monthly Income',
    'id': 'Pendapatan Bulan Ini',
  };

  static Map<String, String> get pendingVerification => {
    'en': 'Pending Verification',
    'id': 'Menunggu Verifikasi',
  };

  static Map<String, String> get unpaid => {
    'en': 'Unpaid',
    'id': 'Belum Bayar',
  };

  static Map<String, String> get verified => {
    'en': 'Verified',
    'id': 'Terverifikasi',
  };

  static Map<String, String> get addPaymentType => {
    'en': 'Add Payment Type',
    'id': 'Tambah Jenis Pembayaran',
  };

  static Map<String, String> get editPaymentType => {
    'en': 'Edit Payment Type',
    'id': 'Edit Jenis Pembayaran',
  };

  static Map<String, String> get deletePaymentType => {
    'en': 'Delete Payment Type',
    'id': 'Hapus Jenis Pembayaran',
  };

  static Map<String, String> get paymentsPendingVerification => {
    'en': 'Payments Pending Verification',
    'id': 'Pembayaran Menunggu Verifikasi',
  };

  static Map<String, String> get classReport => {
    'en': 'Class Report',
    'id': 'Laporan Kelas',
  };

  static Map<String, String> get students => {'en': 'students', 'id': 'siswa'};

  // Settings
  static Map<String, String> get settingsMenu => {
    'en': 'Settings Menu',
    'id': 'Menu Pengaturan',
  };

  static Map<String, String> get generalSettings => {
    'en': 'General Settings',
    'id': 'Pengaturan Umum',
  };

  static Map<String, String> get timeSettings => {
    'en': 'Time Settings',
    'id': 'Pengaturan Waktu',
  };

  static Map<String, String> get userProfile => {
    'en': 'User Profile',
    'id': 'Profil Pengguna',
  };

  static Map<String, String> get personalInformation => {
    'en': 'Personal Information',
    'id': 'Informasi Pribadi',
  };

  static Map<String, String> get accountInformation => {
    'en': 'Account Information',
    'id': 'Informasi Akun',
  };

  static Map<String, String> get fullName => {
    'en': 'Full Name',
    'id': 'Nama Lengkap',
  };

  static Map<String, String> get phoneNumber => {
    'en': 'Phone Number',
    'id': 'No. Telepon',
  };

  static Map<String, String> get address => {'en': 'Address', 'id': 'Alamat'};

  static Map<String, String> get role => {'en': 'Role', 'id': 'Role'};

  static Map<String, String> get school => {'en': 'School', 'id': 'Sekolah'};

  static Map<String, String> get editProfile => {
    'en': 'Edit Profile',
    'id': 'Edit Profil',
  };

  static Map<String, String> get changePassword => {
    'en': 'Change Password',
    'id': 'Ubah Kata Sandi',
  };

  static Map<String, String> get oldPassword => {
    'en': 'Old Password',
    'id': 'Kata Sandi Lama',
  };

  static Map<String, String> get newPassword => {
    'en': 'New Password',
    'id': 'Kata Sandi Baru',
  };

  static Map<String, String> get confirmPassword => {
    'en': 'Confirm Password',
    'id': 'Konfirmasi Kata Sandi',
  };

  static Map<String, String> get passwordMismatch => {
    'en': 'Passwords do not match',
    'id': 'Kata sandi tidak cocok',
  };

  static Map<String, String> get passwordMinLength => {
    'en': 'Password must be at least 8 characters',
    'id': 'Kata sandi minimal 8 karakter',
  };

  static Map<String, String> get passwordLetters => {
    'en': 'Password must contain uppercase and lowercase letters',
    'id': 'Kata sandi harus mengandung huruf besar dan kecil',
  };

  static Map<String, String> get passwordNumbers => {
    'en': 'Password must contain numbers',
    'id': 'Kata sandi harus mengandung angka',
  };

  static Map<String, String> get passwordSymbols => {
    'en': 'Password must contain symbols',
    'id': 'Kata sandi harus mengandung simbol',
  };

  static Map<String, String> get required => {
    'en': 'Required',
    'id': 'Wajib diisi',
  };

  static Map<String, String> get profileUpdatedSuccess => {
    'en': 'Profile updated successfully',
    'id': 'Profil berhasil diperbarui',
  };

  static Map<String, String> get passwordChangedSuccess => {
    'en': 'Password changed successfully',
    'id': 'Kata sandi berhasil diubah',
  };

  static Map<String, String> get failedToLoadProfile => {
    'en': 'Failed to load profile',
    'id': 'Gagal memuat profil',
  };

  static Map<String, String> get failedToUpdateProfile => {
    'en': 'Failed to update profile',
    'id': 'Gagal memperbarui profil',
  };

  static Map<String, String> get failedToChangePassword => {
    'en': 'Failed to change password',
    'id': 'Gagal mengubah kata sandi',
  };
}

// Extension untuk memudahkan penggunaan terjemahan
extension AppLocalizationsExtension on AppLocalizations {
  // Class Management
  static String get editClass => AppLocalizations.editClass.tr;
  static String get addClass => AppLocalizations.addClass.tr;
  static String get className => AppLocalizations.className.tr;
  static String get classNameRequired => AppLocalizations.classNameRequired.tr;
  static String get gradeLevel => AppLocalizations.gradeLevel.tr;
  static String get gradeLevelRequired =>
      AppLocalizations.gradeLevelRequired.tr;
  static String get selectGradeLevel => AppLocalizations.selectGradeLevel.tr;
  static String get homeroomTeacher => AppLocalizations.homeroomTeacher.tr;
  static String get noTeacher => AppLocalizations.noTeacher.tr;
  static String get update => AppLocalizations.update.tr;
  static String get classDetails => AppLocalizations.classDetails.tr;
  static String get numberOfStudents => AppLocalizations.numberOfStudents.tr;
  static String get notAssigned => AppLocalizations.notAssigned.tr;
  static String get classesFound => AppLocalizations.classesFound.tr;
  static String get noClasses => AppLocalizations.noClasses.tr;
  static String get tapToAddClass => AppLocalizations.tapToAddClass.tr;
  static String get searchClasses => AppLocalizations.searchClasses.tr;
  static String get loadingClassData => AppLocalizations.loadingClassData.tr;
  static String get classSuccessfullyUpdated =>
      AppLocalizations.classSuccessfullyUpdated.tr;
  static String get classSuccessfullyAdded =>
      AppLocalizations.classSuccessfullyAdded.tr;
  static String get classSuccessfullyDeleted =>
      AppLocalizations.classSuccessfullyDeleted.tr;
  static String get failedToSaveClass => AppLocalizations.failedToSaveClass.tr;
  static String get failedToDeleteClass =>
      AppLocalizations.failedToDeleteClass.tr;
  static String get areYouSureDeleteClass =>
      AppLocalizations.areYouSureDeleteClass.tr;
  static String get all => AppLocalizations.all.tr;
  static String get withHomeroomTeacher =>
      AppLocalizations.withHomeroomTeacher.tr;
  static String get withoutHomeroomTeacher =>
      AppLocalizations.withoutHomeroomTeacher.tr;
}
