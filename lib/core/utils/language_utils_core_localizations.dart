// Part of the AppLocalizations API — core translations for common UI
// elements. Strings for dashboard, class management, common actions, menu
// items, role titles, login, confirmations, and form fields.
part of 'language_utils.dart';

// ── Core string constants ────────────────────────────────────────────────
const _kAppTitle = {'en': 'School Management', 'id': 'Manajemen Sekolah'};
const _kEditClass = {'en': 'Edit Class', 'id': 'Edit Kelas'};
const _kAddClass = {'en': 'Add Class', 'id': 'Tambah Kelas'};
const _kClassName = {'en': 'Class Name', 'id': 'Nama Kelas'};
const _kClassNameRequired = {
  'en': 'Class name is required',
  'id': 'Nama kelas harus diisi',
};
const _kGradeLevel = {'en': 'Grade Level', 'id': 'Tingkat Kelas'};
const _kRetry = {'en': 'Retry', 'id': 'Ulang'};
const _kGradeLevelRequired = {
  'en': 'Grade level is required',
  'id': 'Tingkat kelas harus dipilih',
};
const _kSelectGradeLevel = {
  'en': 'Select Grade Level',
  'id': 'Pilih Tingkat Kelas',
};
const _kHomeroomTeacher = {'en': 'Homeroom Teacher', 'id': 'Wali Kelas'};
const _kNoTeacher = {'en': 'No Teacher', 'id': 'Tidak Ada Guru'};
const _kUpdate = {'en': 'Update', 'id': 'Perbarui'};
const _kClassDetails = {'en': 'Class Details', 'id': 'Detail Kelas'};
const _kNumberOfStudents = {'en': 'Number of Students', 'id': 'Jumlah Siswa'};
const _kNotAssigned = {'en': 'Not assigned', 'id': 'Tidak ada'};
const _kClassesFound = {'en': 'classes found', 'id': 'kelas ditemukan'};
const _kNoClasses = {'en': 'No classes', 'id': 'Tidak ada kelas'};
const _kTapToAddClass = {
  'en': 'Tap + to add a class',
  'id': 'Tap + untuk menambah kelas',
};
const _kSearchClasses = {'en': 'Search classes...', 'id': 'Cari kelas...'};
const _kLoadingClassData = {
  'en': 'Loading class data...',
  'id': 'Memuat data kelas...',
};
const _kClassSuccessfullyUpdated = {
  'en': 'Class successfully updated',
  'id': 'Kelas berhasil diperbarui',
};
const _kClassSuccessfullyAdded = {
  'en': 'Class successfully added',
  'id': 'Kelas berhasil ditambahkan',
};
const _kClassSuccessfullyDeleted = {
  'en': 'Class successfully deleted',
  'id': 'Kelas berhasil dihapus',
};
const _kFailedToSaveClass = {
  'en': 'Failed to save class',
  'id': 'Gagal menyimpan kelas',
};
const _kFailedToDeleteClass = {
  'en': 'Failed to delete class',
  'id': 'Gagal menghapus kelas',
};
const _kAreYouSureDeleteClass = {
  'en': 'Are you sure you want to delete this class?',
  'id': 'Apakah Anda yakin ingin menghapus kelas ini?',
};
const _kAll = {'en': 'All', 'id': 'Semua'};
const _kWithHomeroomTeacher = {
  'en': 'With Homeroom Teacher',
  'id': 'Dengan Wali Kelas',
};
const _kWithoutHomeroomTeacher = {
  'en': 'Without Homeroom Teacher',
  'id': 'Tanpa Wali Kelas',
};
const _kWelcome = {'en': 'Welcome,', 'id': 'Selamat datang,'};
const _kEmailPasswordNotEmpty = {
  'en': 'Email and password cannot be empty',
  'id': 'Email dan kata sandi tidak boleh kosong',
};
const _kAuthAccountNotRegisteredInAnySchool = {
  'en': 'Account not registered in any school',
  'id': 'Akun tidak terdaftar di sekolah manapun',
};
const _kAuthRolesNotAvailable = {
  'en': 'Roles not available',
  'id': 'Peran tidak tersedia',
};
const _kAuthIncompleteLoginData = {
  'en': 'Incomplete login data',
  'id': 'Data login tidak lengkap',
};
const _kAuthUserRoleNotFound = {
  'en': 'User role not found',
  'id': 'Peran pengguna tidak ditemukan',
};
const _kAuthInvalidCredentials = {
  'en': 'Invalid email or password',
  'id': 'Email atau kata sandi tidak valid',
};
const _kServerNotConnected = {
  'en': 'Cannot connect to server',
  'id': 'Tidak dapat terhubung ke server',
};
const _kLoginFailed = {'en': 'Login failed', 'id': 'Login gagal'};
const _kEnterOtp = {'en': 'Enter OTP', 'id': 'Masukkan OTP'};
const _kAccountNotRegistered = {
  'en': 'Account not registered',
  'id': 'Akun tidak terdaftar',
};
const _kAccountNotRegisteredMsg = {
  'en': 'This email is not registered in any school',
  'id': 'Email ini tidak terdaftar di sekolah manapun',
};
const _kUnderstand = {'en': 'I understand', 'id': 'Saya mengerti'};
const _kOtpVerification = {'en': 'OTP Verification', 'id': 'Verifikasi OTP'};
const _kOtpSentToEmail = {
  'en': 'OTP has been sent to your email',
  'id': 'OTP telah dikirim ke email Anda',
};
const _kEnterOtpDigits = {
  'en': 'Enter the OTP digits sent to your email',
  'id': 'Masukkan digit OTP yang dikirim ke email Anda',
};
const _kBackToLogin = {'en': 'Back to Login', 'id': 'Kembali ke Login'};
const _kOtpCode = {'en': 'OTP Code', 'id': 'Kode OTP'};
const _kVerify = {'en': 'Verify', 'id': 'Verifikasi'};
const _kSelectSchool = {'en': 'Select School', 'id': 'Pilih Sekolah'};
const _kHello = {'en': 'Hello', 'id': 'Halo'};
const _kSelectSchoolMsg = {
  'en': 'Please select a school to continue',
  'id': 'Silakan pilih sekolah untuk melanjutkan',
};
const _kSchoolNoName = {'en': 'School (No Name)', 'id': 'Sekolah (Tanpa Nama)'};
const _kSelectRole = {'en': 'Select Role', 'id': 'Pilih Peran'};
const _kSchoolLabel = {'en': 'School', 'id': 'Sekolah'};
const _kAccessAs = {'en': 'Access as', 'id': 'Akses sebagai'};
const _kPleaseWait = {'en': 'Please wait...', 'id': 'Harap tunggu...'};
const _kSignInWithGoogle = {
  'en': 'Sign in with Google',
  'id': 'Masuk dengan Google',
};
const _kRoleDescAdmin = {'en': 'Administrator', 'id': 'Administrator'};
const _kRoleDescTeacher = {'en': 'Teacher', 'id': 'Guru'};
const _kRoleDescParent = {'en': 'Parent', 'id': 'Wali Murid'};
const _kRoleDescStaff = {'en': 'Staff', 'id': 'Staf'};
const _kRoleDescDefault = {'en': 'User', 'id': 'Pengguna'};
const _kActiveAccount = {'en': 'Active account', 'id': 'Akun aktif'};
const _kSearchHint = {
  'en': 'Search features, data, or menus...',
  'id': 'Cari fitur, data, atau menu...',
};
const _kLogout = {'en': 'Logout', 'id': 'Keluar'};
const _kSettings = {'en': 'Settings', 'id': 'Pengaturan'};
const _kSave = {'en': 'Save', 'id': 'Simpan'};
const _kCancel = {'en': 'Cancel', 'id': 'Batal'};
const _kEdit = {'en': 'Edit', 'id': 'Edit'};
const _kDelete = {'en': 'Delete', 'id': 'Hapus'};
const _kAdd = {'en': 'Add', 'id': 'Tambah'};
const _kRefresh = {'en': 'Refresh', 'id': 'Muat Ulang'};
const _kSearch = {'en': 'Search', 'id': 'Cari'};
const _kLoading = {'en': 'Loading...', 'id': 'Memuat...'};
const _kNoData = {'en': 'No data', 'id': 'Tidak ada data'};
const _kNoSearchResults = {
  'en': 'No search results found',
  'id': 'Tidak ditemukan hasil pencarian',
};
const _kManageStudents = {'en': 'Manage Students', 'id': 'Kelola Siswa'};
const _kManageTeachers = {'en': 'Manage Teachers', 'id': 'Kelola Guru'};
const _kManageClasses = {'en': 'Manage Classes', 'id': 'Kelola Kelas'};
const _kManageSubjects = {
  'en': 'Manage Subjects',
  'id': 'Kelola Mata Pelajaran',
};
const _kManageTeachingSchedule = {
  'en': 'Manage Schedule',
  'id': 'Kelola Jadwal',
};
const _kReports = {'en': 'Reports', 'id': 'Laporan'};
const _kFinance = {'en': 'Finance', 'id': 'Keuangan'};
const _kAnnouncements = {'en': 'Announcements', 'id': 'Pengumuman'};
const _kStudentAttendance = {'en': 'Student Attendance', 'id': 'Absensi Siswa'};
const _kInputGrades = {'en': 'Grades', 'id': 'Nilai'};
const _kTeachingSchedule = {'en': 'Teaching Schedule', 'id': 'Jadwal Mengajar'};
const _kClassActivities = {'en': 'Class Activities', 'id': 'Kegiatan Kelas'};
const _kLessonPlanLearningMaterials = {
  'en': 'Learning Materials',
  'id': 'Materi Pembelajaran',
};
const _kMyLessonPlans = {'en': 'My Lesson Plans', 'id': 'RPP Saya'};
const _kManageLessonPlans = {'en': 'Manage Lesson Plans', 'id': 'Kelola RPP'};
const _kTryAgain = {'en': 'Try Again', 'id': 'Coba Lagi'};
const _kUpdateData = {'en': 'Update Data', 'id': 'Perbarui Data'};
const _kSelectClassMap = {'en': 'Select Class', 'id': 'Pilih Kelas'};
const _kNoAttendanceData = {
  'en': 'No attendance data for this period',
  'id': 'Tidak ada data absensi untuk periode ini',
};
const _kAllMonths = {'en': 'All Months', 'id': 'Semua Bulan'};
const _kAllTypes = {'en': 'All Types', 'id': 'Semua Jenis'};
const _kBankTransfer = {'en': 'Bank Transfer', 'id': 'Transfer Bank'};
const _kCreditCard = {'en': 'Credit/Debit Card', 'id': 'Kartu Kredit/Debit'};
const _kDateFormatHint = {
  'en': 'Format date: YYYY-MM-DD',
  'id': 'Format tanggal: YYYY-MM-DD',
};
const _kClose = {'en': 'Close', 'id': 'Tutup'};
const _kAdminRole = {'en': 'Admin', 'id': 'Admin'};
const _kTeacherRole = {'en': 'Teacher', 'id': 'Guru'};
const _kStaffRole = {'en': 'Staff', 'id': 'Staff'};
const _kParentRole = {'en': 'Parent', 'id': 'Wali Murid'};
const _kLogin = {'en': 'Login', 'id': 'Masuk'};
const _kEmail = {'en': 'Email', 'id': 'Email'};
const _kPassword = {'en': 'Password', 'id': 'Kata Sandi'};
const _kForgotPassword = {'en': 'Forgot Password?', 'id': 'Lupa Kata Sandi?'};
const _kLoginSuccess = {'en': 'Login Successful', 'id': 'Login Berhasil'};
const _kLoginError = {'en': 'Login Failed', 'id': 'Login Gagal'};
const _kConfirmDelete = {'en': 'Confirm Delete', 'id': 'Konfirmasi Hapus'};
const _kAreYouSureMap = {'en': 'Are you sure?', 'id': 'Apakah Anda yakin?'};
const _kName = {'en': 'Name', 'id': 'Nama'};
const _kClass = {'en': 'Class', 'id': 'Kelas'};
const _kSubject = {'en': 'Subject', 'id': 'Mata Pelajaran'};
const _kTeacher = {'en': 'Teacher', 'id': 'Guru'};
const _kScheduleMap = {'en': 'Schedule', 'id': 'Jadwal'};
const _kSuccess = {'en': 'Success', 'id': 'Berhasil'};
const _kError = {'en': 'Error', 'id': 'Error'};
const _kStartTime = {'en': 'Start Time', 'id': 'Jam Mulai'};
const _kEndTime = {'en': 'End Time', 'id': 'Jam Selesai'};
const _kDay = {'en': 'Day', 'id': 'Hari'};
const _kPresent = {'en': 'Present', 'id': 'Hadir'};
const _kLate = {'en': 'Late', 'id': 'Telat'};
const _kPermission = {'en': 'Permission', 'id': 'Izin'};
const _kSick = {'en': 'Sick', 'id': 'Sakit'};
const _kAlpha = {'en': 'Absent', 'id': 'Alpha'};
const _kFailedToLoadReportCard = {
  'en': 'Failed to load report card',
  'id': 'Gagal memuat rapor',
};
const _kGeneralSettings = {'en': 'General Settings', 'id': 'Pengaturan Umum'};
const _kTimeSettings = {'en': 'Time Settings', 'id': 'Pengaturan Waktu'};
const _kSchoolSettings = {'en': 'School Settings', 'id': 'Pengaturan Sekolah'};
const _kSettingsMenu = {'en': 'Settings Menu', 'id': 'Menu Pengaturan'};
const _kChooseSource = {'en': 'Choose Source', 'id': 'Pilih Sumber'};
const _kChooseImageSource = {
  'en': 'Choose Image Source',
  'id': 'Pilih Sumber Gambar',
};
const _kGallery = {'en': 'Gallery', 'id': 'Galeri'};
const _kCamera = {'en': 'Camera', 'id': 'Kamera'};
const _kChooseFileType = {'en': 'Choose File Type', 'id': 'Pilih Jenis File'};
const _kUploadPaymentProof = {
  'en': 'Upload Payment Proof',
  'id': 'Unggah Bukti Pembayaran',
};
const _kImageCameraGallery = {
  'en': 'Image (Camera/Gallery)',
  'id': 'Gambar (Kamera/Galeri)',
};
const _kPdfDocument = {'en': 'PDF Document', 'id': 'Dokumen PDF'};
const _kVerified = {'en': 'Verified', 'id': 'Terverifikasi'};
const _kPaymentVerifiedSuccessfully = {
  'en': 'Payment Verified Successfully',
  'id': 'Pembayaran Berhasil Diverifikasi',
};
const _kPaymentRejectedSuccessfully = {
  'en': 'Payment Rejected Successfully',
  'id': 'Pembayaran Berhasil Ditolak',
};
const _kFailedToVerify = {'en': 'Failed to Verify', 'id': 'Gagal Verifikasi'};
const _kPaymentTypes = {'en': 'Payment Types', 'id': 'Jenis Pembayaran'};
const _kNoPaymentProof = {
  'en': 'No Payment Proof',
  'id': 'Tidak Ada Bukti Pembayaran',
};
const _kFailedToLoadImage = {
  'en': 'Failed to Load Image',
  'id': 'Gagal Memuat Gambar',
};
const _kEditPaymentType = {
  'en': 'Edit Payment Type',
  'id': 'Edit Jenis Pembayaran',
};
const _kAddPaymentType = {
  'en': 'Add Payment Type',
  'id': 'Tambah Jenis Pembayaran',
};
const _kFailedToLoadTeacherSubjects = {
  'en': 'Failed to Load Teacher Subjects',
  'id': 'Gagal Memuat Mata Pelajaran Guru',
};
const _kPaymentRecordedSuccessfully = {
  'en': 'Payment Recorded Successfully',
  'id': 'Pembayaran Berhasil Dicatat',
};
const _kPaymentCancelled = {
  'en': 'Payment Cancelled',
  'id': 'Pembayaran Dibatalkan',
};
const _kNoChildrenLinked = {
  'en': 'No Children Linked',
  'id': 'Tidak Ada Anak yang Terhubung',
};
const _kSelectChild = {'en': 'Select Child', 'id': 'Pilih Anak'};
const _kNameNotAvailable = {
  'en': 'Name Not Available',
  'id': 'Nama Tidak Tersedia',
};
const _kClassString = {'en': 'Class', 'id': 'Kelas'};
const _kSelectChildToViewGrades = {
  'en': 'Select Child to View Grades',
  'id': 'Pilih Anak untuk Melihat Nilai',
};
const _kChildAcademicGrades = {
  'en': 'Child Academic Grades',
  'id': 'Nilai Akademik Anak',
};
const _kMonitorChildGrades = {
  'en': 'Monitor Child Grades',
  'id': 'Pantau Nilai Anak',
};
const _kNoGradeDataFound = {
  'en': 'No Grade Data Found',
  'id': 'Tidak Ada Data Nilai',
};
const _kStudentsMap = {'en': 'Students', 'id': 'Siswa'};
const _kNoStudentsMatchSearch = {
  'en': 'No Students Match Search',
  'id': 'Tidak Ada Siswa yang Cocok',
};
const _kBillAmount = {'en': 'Bill Amount', 'id': 'Jumlah Tagihan'};
const _kPaymentsPendingVerification = {
  'en': 'Payments Pending Verification',
  'id': 'Pembayaran Menunggu Verifikasi',
};
const _kUnpaid = {'en': 'Unpaid', 'id': 'Belum Dibayar'};
const _kDashboard = {'en': 'Dashboard', 'id': 'Dasbor'};
const _kVerification = {'en': 'Verification', 'id': 'Verifikasi'};
const _kClassReport = {'en': 'Class Report', 'id': 'Laporan Kelas'};
const _kDeleteMaterial = {'en': 'Delete Material', 'id': 'Hapus Materi'};
const _kDeleteColumnConfirm = {
  'en': 'Are you sure you want to delete this column?',
  'id': 'Apakah Anda yakin ingin menghapus kolom ini?',
};
const _kGradeRecapSaved = {
  'en': 'Grade Recap Saved',
  'id': 'Rekapitulasi Nilai Disimpan',
};
const _kFailedToImport = {'en': 'Failed to import', 'id': 'Gagal mengimpor'};
const _kFailedToLoadInitialData = {
  'en': 'Failed to load initial data',
  'id': 'Gagal memuat data awal',
};
const _kFailedToProcess = {'en': 'Failed to process', 'id': 'Gagal memproses'};
const _kFailedToSaveMap = {'en': 'Failed to save', 'id': 'Gagal menyimpan'};
const _kNoStudentsInClass = {
  'en': 'No students in this class',
  'id': 'Tidak ada siswa di kelas ini',
};

/// Static translation dictionary containing core app strings in English and
/// Indonesian.
/// Like Laravel's `resources/lang/en/messages.php` combined with
/// `resources/lang/id/messages.php`. Each getter returns a
/// `Map<String, String>` of `{languageCode: translatedText}`.
///
/// Usage: `AppLocalizations.welcome.tr` (via the [LocalizedString]
/// extension).
class AppLocalizations {
  static Map<String, String> get appTitle => _kAppTitle;
  static Map<String, String> get editClass => _kEditClass;
  static Map<String, String> get addClass => _kAddClass;
  static Map<String, String> get className => _kClassName;
  static Map<String, String> get classNameRequired => _kClassNameRequired;
  static Map<String, String> get gradeLevel => _kGradeLevel;
  static Map<String, String> get retry => _kRetry;
  static Map<String, String> get gradeLevelRequired => _kGradeLevelRequired;
  static Map<String, String> get selectGradeLevel => _kSelectGradeLevel;
  static Map<String, String> get homeroomTeacher => _kHomeroomTeacher;
  static Map<String, String> get noTeacher => _kNoTeacher;
  static Map<String, String> get update => _kUpdate;
  static Map<String, String> get classDetails => _kClassDetails;
  static Map<String, String> get numberOfStudents => _kNumberOfStudents;
  static Map<String, String> get notAssigned => _kNotAssigned;
  static Map<String, String> get classesFound => _kClassesFound;
  static Map<String, String> get noClasses => _kNoClasses;
  static Map<String, String> get tapToAddClass => _kTapToAddClass;
  static Map<String, String> get searchClasses => _kSearchClasses;
  static Map<String, String> get loadingClassData => _kLoadingClassData;
  static Map<String, String> get classSuccessfullyUpdated =>
      _kClassSuccessfullyUpdated;
  static Map<String, String> get classSuccessfullyAdded =>
      _kClassSuccessfullyAdded;
  static Map<String, String> get classSuccessfullyDeleted =>
      _kClassSuccessfullyDeleted;
  static Map<String, String> get failedToSaveClass => _kFailedToSaveClass;
  static Map<String, String> get failedToDeleteClass => _kFailedToDeleteClass;
  static Map<String, String> get areYouSureDeleteClass =>
      _kAreYouSureDeleteClass;
  static Map<String, String> get all => _kAll;
  static Map<String, String> get withHomeroomTeacher => _kWithHomeroomTeacher;
  static Map<String, String> get withoutHomeroomTeacher =>
      _kWithoutHomeroomTeacher;
  static Map<String, String> get welcome => _kWelcome;
  static Map<String, String> get emailPasswordNotEmpty =>
      _kEmailPasswordNotEmpty;
  static Map<String, String> get authAccountNotRegisteredInAnySchool =>
      _kAuthAccountNotRegisteredInAnySchool;
  static Map<String, String> get authRolesNotAvailable =>
      _kAuthRolesNotAvailable;
  static Map<String, String> get authIncompleteLoginData =>
      _kAuthIncompleteLoginData;
  static Map<String, String> get authUserRoleNotFound => _kAuthUserRoleNotFound;
  static Map<String, String> get authInvalidCredentials =>
      _kAuthInvalidCredentials;
  static Map<String, String> get serverNotConnected => _kServerNotConnected;
  static Map<String, String> get loginFailed => _kLoginFailed;
  static Map<String, String> get enterOtp => _kEnterOtp;
  static Map<String, String> get accountNotRegistered => _kAccountNotRegistered;
  static Map<String, String> get accountNotRegisteredMsg =>
      _kAccountNotRegisteredMsg;
  static Map<String, String> get understand => _kUnderstand;
  static Map<String, String> get otpVerification => _kOtpVerification;
  static Map<String, String> get otpSentToEmail => _kOtpSentToEmail;
  static Map<String, String> get enterOtpDigits => _kEnterOtpDigits;
  static Map<String, String> get backToLogin => _kBackToLogin;
  static Map<String, String> get otpCode => _kOtpCode;
  static Map<String, String> get verify => _kVerify;
  static Map<String, String> get selectSchool => _kSelectSchool;
  static Map<String, String> get hello => _kHello;
  static Map<String, String> get selectSchoolMsg => _kSelectSchoolMsg;
  static Map<String, String> get schoolNoName => _kSchoolNoName;
  static Map<String, String> get selectRole => _kSelectRole;
  static Map<String, String> get schoolLabel => _kSchoolLabel;
  static Map<String, String> get accessAs => _kAccessAs;
  static Map<String, String> get pleaseWait => _kPleaseWait;
  static Map<String, String> get signInWithGoogle => _kSignInWithGoogle;
  static Map<String, String> get roleDescAdmin => _kRoleDescAdmin;
  static Map<String, String> get roleDescTeacher => _kRoleDescTeacher;
  static Map<String, String> get roleDescParent => _kRoleDescParent;
  static Map<String, String> get roleDescStaff => _kRoleDescStaff;
  static Map<String, String> get roleDescDefault => _kRoleDescDefault;
  static Map<String, String> get activeAccount => _kActiveAccount;
  static Map<String, String> get searchHint => _kSearchHint;
  static Map<String, String> get logout => _kLogout;
  static Map<String, String> get settings => _kSettings;
  static Map<String, String> get save => _kSave;
  static Map<String, String> get cancel => _kCancel;
  static Map<String, String> get edit => _kEdit;
  static Map<String, String> get delete => _kDelete;
  static Map<String, String> get add => _kAdd;
  static Map<String, String> get refresh => _kRefresh;
  static Map<String, String> get search => _kSearch;
  static Map<String, String> get loading => _kLoading;
  static Map<String, String> get noData => _kNoData;
  static Map<String, String> get noSearchResults => _kNoSearchResults;
  static Map<String, String> get manageStudents => _kManageStudents;
  static Map<String, String> get manageTeachers => _kManageTeachers;
  static Map<String, String> get manageClasses => _kManageClasses;
  static Map<String, String> get manageSubjects => _kManageSubjects;
  static Map<String, String> get manageTeachingSchedule =>
      _kManageTeachingSchedule;
  static Map<String, String> get reports => _kReports;
  static Map<String, String> get finance => _kFinance;
  static Map<String, String> get announcements => _kAnnouncements;
  static Map<String, String> get studentAttendance => _kStudentAttendance;
  static Map<String, String> get inputGrades => _kInputGrades;
  static Map<String, String> get teachingSchedule => _kTeachingSchedule;
  static Map<String, String> get classActivities => _kClassActivities;
  static Map<String, String> get lessonPlanLearningMaterials =>
      _kLessonPlanLearningMaterials;
  static Map<String, String> get myLessonPlans => _kMyLessonPlans;
  static Map<String, String> get manageLessonPlans => _kManageLessonPlans;
  static Map<String, String> get tryAgain => _kTryAgain;
  static Map<String, String> get updateData => _kUpdateData;
  static Map<String, String> get selectClass => _kSelectClassMap;
  static Map<String, String> get noAttendanceData => _kNoAttendanceData;
  static Map<String, String> get allMonths => _kAllMonths;
  static Map<String, String> get allTypes => _kAllTypes;
  static Map<String, String> get bankTransfer => _kBankTransfer;
  static Map<String, String> get creditCard => _kCreditCard;
  static Map<String, String> get dateFormatHint => _kDateFormatHint;
  static Map<String, String> get close => _kClose;
  static Map<String, String> get adminRole => _kAdminRole;
  static Map<String, String> get teacherRole => _kTeacherRole;
  static Map<String, String> get staffRole => _kStaffRole;
  static Map<String, String> get parentRole => _kParentRole;
  static Map<String, String> get login => _kLogin;
  static Map<String, String> get email => _kEmail;
  static Map<String, String> get password => _kPassword;
  static Map<String, String> get forgotPassword => _kForgotPassword;
  static Map<String, String> get loginSuccess => _kLoginSuccess;
  static Map<String, String> get loginError => _kLoginError;
  static Map<String, String> get confirmDelete => _kConfirmDelete;
  static Map<String, String> get areYouSure => _kAreYouSureMap;
  static Map<String, String> get name => _kName;
  static Map<String, String> get class_ => _kClass;
  static Map<String, String> get subject => _kSubject;
  static Map<String, String> get teacher => _kTeacher;
  static Map<String, String> get schedule => _kScheduleMap;
  static Map<String, String> get success => _kSuccess;
  static Map<String, String> get error => _kError;
  static Map<String, String> get startTime => _kStartTime;
  static Map<String, String> get endTime => _kEndTime;
  static Map<String, String> get day => _kDay;
  static Map<String, String> get present => _kPresent;
  static Map<String, String> get late => _kLate;
  static Map<String, String> get permission => _kPermission;
  static Map<String, String> get sick => _kSick;
  static Map<String, String> get alpha => _kAlpha;
  static Map<String, String> get failedToLoadReportCard =>
      _kFailedToLoadReportCard;
  static Map<String, String> get generalSettings => _kGeneralSettings;
  static Map<String, String> get timeSettings => _kTimeSettings;
  static Map<String, String> get schoolSettings => _kSchoolSettings;
  static Map<String, String> get settingsMenu => _kSettingsMenu;
  static Map<String, String> get chooseSource => _kChooseSource;
  static Map<String, String> get chooseImageSource => _kChooseImageSource;
  static Map<String, String> get gallery => _kGallery;
  static Map<String, String> get camera => _kCamera;
  static Map<String, String> get chooseFileType => _kChooseFileType;
  static Map<String, String> get uploadPaymentProof => _kUploadPaymentProof;
  static Map<String, String> get imageCameraGallery => _kImageCameraGallery;
  static Map<String, String> get pdfDocument => _kPdfDocument;
  static Map<String, String> get verified => _kVerified;
  static Map<String, String> get paymentVerifiedSuccessfully =>
      _kPaymentVerifiedSuccessfully;
  static Map<String, String> get paymentRejectedSuccessfully =>
      _kPaymentRejectedSuccessfully;
  static Map<String, String> get failedToVerify => _kFailedToVerify;
  static Map<String, String> get paymentTypes => _kPaymentTypes;
  static Map<String, String> get noPaymentProof => _kNoPaymentProof;
  static Map<String, String> get failedToLoadImage => _kFailedToLoadImage;
  static Map<String, String> get editPaymentType => _kEditPaymentType;
  static Map<String, String> get addPaymentType => _kAddPaymentType;
  static Map<String, String> get failedToLoadTeacherSubjects =>
      _kFailedToLoadTeacherSubjects;
  static Map<String, String> get paymentRecordedSuccessfully =>
      _kPaymentRecordedSuccessfully;
  static Map<String, String> get paymentCancelled => _kPaymentCancelled;
  static Map<String, String> get noChildrenLinked => _kNoChildrenLinked;
  static Map<String, String> get selectChild => _kSelectChild;
  static Map<String, String> get nameNotAvailable => _kNameNotAvailable;
  static Map<String, String> get classString => _kClassString;
  static Map<String, String> get selectChildToViewGrades =>
      _kSelectChildToViewGrades;
  static Map<String, String> get childAcademicGrades => _kChildAcademicGrades;
  static Map<String, String> get monitorChildGrades => _kMonitorChildGrades;
  static Map<String, String> get noGradeDataFound => _kNoGradeDataFound;
  static Map<String, String> get students => _kStudentsMap;
  static Map<String, String> get noStudentsMatchSearch =>
      _kNoStudentsMatchSearch;
  static Map<String, String> get billAmount => _kBillAmount;
  static Map<String, String> get paymentsPendingVerification =>
      _kPaymentsPendingVerification;
  static Map<String, String> get unpaid => _kUnpaid;
  static Map<String, String> get dashboard => _kDashboard;
  static Map<String, String> get verification => _kVerification;
  static Map<String, String> get classReport => _kClassReport;
  static Map<String, String> get deleteMaterial => _kDeleteMaterial;
  static Map<String, String> get deleteColumnConfirm => _kDeleteColumnConfirm;
  static Map<String, String> get gradeRecapSaved => _kGradeRecapSaved;
  static Map<String, String> get failedToImport => _kFailedToImport;
  static Map<String, String> get failedToLoadInitialData =>
      _kFailedToLoadInitialData;
  static Map<String, String> get failedToProcess => _kFailedToProcess;
  static Map<String, String> get failedToSave => _kFailedToSaveMap;
  static Map<String, String> get noStudentsInClass => _kNoStudentsInClass;

  // ── Lesson Plan AI strings ──────────────────────────────────────────────
  static Map<String, String> get lessonPlanSavedSuccessfully =>
      _kLessonPlanSavedSuccessfully;
  static Map<String, String> get lessonPlanStatusUpdated =>
      _kLessonPlanStatusUpdated;
  static Map<String, String> get failedToUpdate => _kFailedToUpdate;
  static Map<String, String> get downloadSuccessful => _kDownloadSuccessful;
  static Map<String, String> get failedToOpenFile => _kFailedToOpenFile;
  static Map<String, String> get failedToDownload => _kFailedToDownload;
  static Map<String, String> get fieldRegeneratedSuccessfully =>
      _kFieldRegeneratedSuccessfully;
  static Map<String, String> get failedToGetJobId => _kFailedToGetJobId;
  static Map<String, String> get failedToGenerate => _kFailedToGenerate;
  static Map<String, String> get failedExceededLimit => _kFailedExceededLimit;
  static Map<String, String> get lessonPlanExportedToText =>
      _kLessonPlanExportedToText;
  static Map<String, String> get fileSavedSuccessfully =>
      _kFileSavedSuccessfully;
  static Map<String, String> get lessonPlanCopiedToClipboard =>
      _kLessonPlanCopiedToClipboard;
  static Map<String, String> get failedToGenerateLessonPlan =>
      _kFailedToGenerateLessonPlan;
  static Map<String, String> get regenerate => _kRegenerate;
  static Map<String, String> get regenerateAll => _kRegenerateAll;
  static Map<String, String> get lessonPlanRegeneratedSuccessfully =>
      _kLessonPlanRegeneratedSuccessfully;
  static Map<String, String> get failedToRegenerateLessonPlan =>
      _kFailedToRegenerateLessonPlan;
  static Map<String, String> get failedToCreatePdfPreview =>
      _kFailedToCreatePdfPreview;
  static Map<String, String> get lessonPlanAiGeneratedDescription =>
      _kLessonPlanAiGeneratedDescription;

  // ── Extended getters from other modules ──────────────────────────────────
  static Map<String, String> get menu => _kMenu;
  static Map<String, String> get attendance => _kAttendance;
  static Map<String, String> get activeTeachers => _kActiveTeachers;
  static Map<String, String> get currentlyTeaching => _kCurrentlyTeaching;
  static Map<String, String> get recentUpdates => _kRecentUpdates;
  static Map<String, String> get myChildren => _kMyChildren;
  static Map<String, String> get registeredStudents => _kRegisteredStudents;
  static Map<String, String> get newGrades => _kNewGrades;
  static Map<String, String> get childAttendance => _kChildAttendance;
  static Map<String, String> get newRecords => _kNewRecords;
  static Map<String, String> get latestInformation => _kLatestInformation;
  static Map<String, String> get data => _kData;
  static Map<String, String> get activity => _kActivity;
  static Map<String, String> get selectAcademicYear => _kSelectAcademicYear;
  static Map<String, String> get classNotAvailable => _kClassNotAvailable;
  static Map<String, String> get information => _kInformation;
  static Map<String, String> get noStudentLinked => _kNoStudentLinked;
  static Map<String, String> get goodMorning => _kGoodMorning;
  static Map<String, String> get goodAfternoon => _kGoodAfternoon;
  static Map<String, String> get goodEvening => _kGoodEvening;
  static Map<String, String> get categoryDataManagement =>
      _kCategoryDataManagement;
  static Map<String, String> get categoryAcademicCommunication =>
      _kCategoryAcademicCommunication;
  static Map<String, String> get categoryFinanceSettings =>
      _kCategoryFinanceSettings;
  static Map<String, String> get categoryTeaching => _kCategoryTeaching;
  static Map<String, String> get categoryAssessmentPlanning =>
      _kCategoryAssessmentPlanning;
  static Map<String, String> get manageData => _kManageData;
  static Map<String, String> get errorAdminIdNotFound => _kErrorAdminIdNotFound;
  static Map<String, String> get errorTeacherIdNotFound =>
      _kErrorTeacherIdNotFound;
  static Map<String, String> get learningMaterials => _kLearningMaterials;
  static Map<String, String> get gradeRecap => _kGradeRecap;
  static Map<String, String> get todaysOverview => _kTodaysOverview;
  static Map<String, String> get quickAccess => _kQuickAccess;
  static Map<String, String> get reportCard => _kReportCard;
  static Map<String, String> get eReportCard => _kEReportCard;
  static Map<String, String> get learningRecommendation =>
      _kLearningRecommendation;
  static Map<String, String> get chooseLanguage => _kChooseLanguage;
  static Map<String, String> get selectAcademicYearTitle =>
      _kSelectAcademicYear;
  static Map<String, String> get failedToLoad => _kFailedToLoad;
  static Map<String, String> get noDataToExport => _kNoDataToExport;
  static Map<String, String> get unknown => _kUnknown;
  static Map<String, String> get activityTitle => _kActivityTitle;
  static Map<String, String> get deadline => _kDeadline;
  static Map<String, String> get description => _kDescription;
  static Map<String, String> get additionalSubChapter => _kAdditionalSubChapter;
  static Map<String, String> get selectChildToViewActivity =>
      _kSelectChildToViewActivity;
  static Map<String, String> get noActivityForChild => _kNoActivityForChild;
  static Map<String, String> get childClassActivity => _kChildClassActivity;
  static Map<String, String> get monitorChildActivity => _kMonitorChildActivity;
  static Map<String, String> get assignment => _kAssignment;
  static Map<String, String> get material => _kMaterial;
  static Map<String, String> get presence => _kPresence;
  static Map<String, String> get billing => _kBilling;
  static Map<String, String> get switchRole => _kSwitchRole;
  static Map<String, String> get switchSchool => _kSwitchSchool;
  static Map<String, String> get ok => _kOk;
  static Map<String, String> get studentReport => _kStudentReport;
  static Map<String, String> get presenceReport => _kPresenceReport;
}
