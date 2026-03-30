/// language_utils.dart - Internationalization (i18n) provider, translation maps, and helpers.
/// Like a combination of Laravel's `lang/` localization files + a Vuex store module for
/// the current locale. Provides a reactive language state, translation dictionaries,
/// and a convenient `.tr` extension for inline translation lookups.
///
/// Architecture:
/// - [LanguageProvider]: Reactive state holder (like a Vuex store module) that tracks
///   the current language and persists it to SharedPreferences (like Laravel's session).
/// - [AppLocalizations]: Static translation dictionary (like Laravel's `lang/en/messages.php`
///   and `lang/id/messages.php` merged into one class with `Map<String, String>` per key).
/// - [LocalizedString] extension: Adds a `.tr` getter to any `Map<String, String>` for
///   quick translation (like Laravel's `__('key')` or Vue-i18n's `$t('key')`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart' as riverpod_legacy;
import 'package:manajemensekolah/core/services/preferences_service.dart';

part 'language_utils_lesson_plans.dart';
part 'language_utils_parent_dashboard.dart';
part 'language_utils_settings_auth.dart';

/// Manages the app's current language and notifies listeners on change.
/// Like a Vuex store module - holds reactive global state that widgets can listen to.
///
/// Persists the selected language to SharedPreferences (like Laravel storing locale
/// in the session). Supports English ('en') and Indonesian ('id').
///
/// Usage: Wrap the app with `ChangeNotifierProvider<LanguageProvider>`, then use
/// `ref.watch(languageRiverpod)` to rebuild widgets when language changes.
class LanguageProvider with ChangeNotifier {
  static const String english = 'en';
  static const String indonesian = 'id';

  String _currentLanguage = indonesian;

  /// The currently active language code ('en' or 'id').
  String get currentLanguage => _currentLanguage;

  /// Changes the app language and persists the choice to SharedPreferences.
  /// Like setting `App::setLocale()` in Laravel's middleware.
  ///
  /// [language] - The language code to switch to ('en' or 'id').
  /// Side effects: Saves to SharedPreferences, calls [notifyListeners] to
  /// trigger UI rebuilds across the app.
  Future<void> setLanguage(String language) async {
    _currentLanguage = language;

    // Save to shared preferences
    final prefs = PreferencesService();
    await prefs.setString('language', language);

    notifyListeners(); // Notify all listeners about the change
  }

  /// Loads the previously saved language preference from SharedPreferences.
  /// Called once at app startup. Defaults to Indonesian if no preference is saved.
  /// Like reading `session('locale')` in Laravel.
  Future<void> loadSavedLanguage() async {
    final prefs = PreferencesService();
    final savedLanguage = prefs.getString('language') ?? indonesian;
    _currentLanguage = savedLanguage;
    notifyListeners();
  }

  /// Resolves a translation from a map of `{languageCode: text}`.
  /// Like Laravel's `__('messages.welcome')` but using a map instead of file-based keys.
  ///
  /// [translations] - A map like `{'en': 'Hello', 'id': 'Halo'}`.
  /// Returns the string for the current language, falling back to Indonesian.
  String getTranslatedText(Map<String, String> translations) {
    return translations[_currentLanguage] ?? translations[indonesian] ?? '';
  }
}

/// Global singleton instance of [LanguageProvider].
/// Used by the `.tr` extension and injected into the Provider tree in `main.dart`.
LanguageProvider languageProvider = LanguageProvider();

/// Convenience extension on `Map<String, String>` for inline translations.
/// Like Laravel's `__()` helper or Vue-i18n's `$t()`.
///
/// Usage: `AppLocalizations.welcome.tr` returns "Selamat datang," or "Welcome,"
/// depending on the current language.
extension LocalizedString on Map<String, String> {
  /// Returns the translated string for the current language.
  String get tr {
    return languageProvider.getTranslatedText(this);
  }
}

/// Riverpod provider for [LanguageProvider].
/// Uses the existing global singleton instance to stay in sync with
/// the `.tr` extension and old Provider-based widgets.
///
/// Usage: `ref.watch(languageRiverpod)` for reactive language changes
final languageRiverpod = riverpod_legacy.ChangeNotifierProvider<LanguageProvider>((
  ref,
) {
  return languageProvider; // Global singleton from language_utils.dart
});

/// Static translation dictionary containing all app strings in English and Indonesian.
/// Like Laravel's `resources/lang/en/messages.php` and `resources/lang/id/messages.php`
/// combined into a single class. Each getter returns a `Map<String, String>` of
/// `{languageCode: translatedText}`.
///
/// Organized by feature/screen: Dashboard, Class Management, Login, RPP (Lesson Plans),
/// Finance, Settings, Parent screens, etc.
///
/// Usage: `AppLocalizations.welcome.tr` (via the [LocalizedString] extension).

class AppLocalizations {
  // ── Core strings ─────────────────────────────────────────────────────────────
  // Dashboard, Class Management, Filter Options, Common actions, Menu Items,
  // Role Titles, Login Screen, Confirmation dialogs, Form fields, Time-related.
  static Map<String, String> get appTitle => {'en': 'School Management', 'id': 'Manajemen Sekolah'};
  static Map<String, String> get editClass => {'en': 'Edit Class', 'id': 'Edit Kelas'};
  static Map<String, String> get addClass => {'en': 'Add Class', 'id': 'Tambah Kelas'};
  static Map<String, String> get className => {'en': 'Class Name', 'id': 'Nama Kelas'};
  static Map<String, String> get classNameRequired => {'en': 'Class name is required', 'id': 'Nama kelas harus diisi'};
  static Map<String, String> get gradeLevel => {'en': 'Grade Level', 'id': 'Tingkat Kelas'};
  static Map<String, String> get retry => {'en': 'Retry', 'id': 'Ulang'};
  static Map<String, String> get gradeLevelRequired => {'en': 'Grade level is required', 'id': 'Tingkat kelas harus dipilih'};
  static Map<String, String> get selectGradeLevel => {'en': 'Select Grade Level', 'id': 'Pilih Tingkat Kelas'};
  static Map<String, String> get homeroomTeacher => {'en': 'Homeroom Teacher', 'id': 'Wali Kelas'};
  static Map<String, String> get noTeacher => {'en': 'No Teacher', 'id': 'Tidak Ada Guru'};
  static Map<String, String> get update => {'en': 'Update', 'id': 'Perbarui'};
  static Map<String, String> get classDetails => {'en': 'Class Details', 'id': 'Detail Kelas'};
  static Map<String, String> get numberOfStudents => {'en': 'Number of Students', 'id': 'Jumlah Siswa'};
  static Map<String, String> get notAssigned => {'en': 'Not assigned', 'id': 'Tidak ada'};
  static Map<String, String> get classesFound => {'en': 'classes found', 'id': 'kelas ditemukan'};
  static Map<String, String> get noClasses => {'en': 'No classes', 'id': 'Tidak ada kelas'};
  static Map<String, String> get tapToAddClass => {'en': 'Tap + to add a class', 'id': 'Tap + untuk menambah kelas'};
  static Map<String, String> get searchClasses => {'en': 'Search classes...', 'id': 'Cari kelas...'};
  static Map<String, String> get loadingClassData => {'en': 'Loading class data...', 'id': 'Memuat data kelas...'};
  static Map<String, String> get classSuccessfullyUpdated => {'en': 'Class successfully updated', 'id': 'Kelas berhasil diperbarui'};
  static Map<String, String> get classSuccessfullyAdded => {'en': 'Class successfully added', 'id': 'Kelas berhasil ditambahkan'};
  static Map<String, String> get classSuccessfullyDeleted => {'en': 'Class successfully deleted', 'id': 'Kelas berhasil dihapus'};
  static Map<String, String> get failedToSaveClass => {'en': 'Failed to save class', 'id': 'Gagal menyimpan kelas'};
  static Map<String, String> get failedToDeleteClass => {'en': 'Failed to delete class', 'id': 'Gagal menghapus kelas'};
  static Map<String, String> get areYouSureDeleteClass => {'en': 'Are you sure you want to delete this class?', 'id': 'Apakah Anda yakin ingin menghapus kelas ini?'};
  static Map<String, String> get all => {'en': 'All', 'id': 'Semua'};
  static Map<String, String> get withHomeroomTeacher => {'en': 'With Homeroom Teacher', 'id': 'Dengan Wali Kelas'};
  static Map<String, String> get withoutHomeroomTeacher => {'en': 'Without Homeroom Teacher', 'id': 'Tanpa Wali Kelas'};
  static Map<String, String> get welcome => {'en': 'Welcome,', 'id': 'Selamat datang,'};
  static Map<String, String> get activeAccount => {'en': 'Active account', 'id': 'Akun aktif'};
  static Map<String, String> get searchHint => {'en': 'Search features, data, or menus...', 'id': 'Cari fitur, data, atau menu...'};
  static Map<String, String> get logout => {'en': 'Logout', 'id': 'Keluar'};
  static Map<String, String> get settings => {'en': 'Settings', 'id': 'Pengaturan'};
  static Map<String, String> get save => {'en': 'Save', 'id': 'Simpan'};
  static Map<String, String> get cancel => {'en': 'Cancel', 'id': 'Batal'};
  static Map<String, String> get edit => {'en': 'Edit', 'id': 'Edit'};
  static Map<String, String> get delete => {'en': 'Delete', 'id': 'Hapus'};
  static Map<String, String> get add => {'en': 'Add', 'id': 'Tambah'};
  static Map<String, String> get refresh => {'en': 'Refresh', 'id': 'Muat Ulang'};
  static Map<String, String> get search => {'en': 'Search', 'id': 'Cari'};
  static Map<String, String> get loading => {'en': 'Loading...', 'id': 'Memuat...'};
  static Map<String, String> get noData => {'en': 'No data', 'id': 'Tidak ada data'};
  static Map<String, String> get noSearchResults => {'en': 'No search results found', 'id': 'Tidak ditemukan hasil pencarian'};
  static Map<String, String> get manageStudents => {'en': 'Manage Students', 'id': 'Kelola Siswa'};
  static Map<String, String> get manageTeachers => {'en': 'Manage Teachers', 'id': 'Kelola Guru'};
  static Map<String, String> get manageClasses => {'en': 'Manage Classes', 'id': 'Kelola Kelas'};
  static Map<String, String> get manageSubjects => {'en': 'Manage Subjects', 'id': 'Kelola Mata Pelajaran'};
  static Map<String, String> get manageTeachingSchedule => {'en': 'Manage Schedule', 'id': 'Kelola Jadwal'};
  static Map<String, String> get reports => {'en': 'Reports', 'id': 'Laporan'};
  static Map<String, String> get finance => {'en': 'Finance', 'id': 'Keuangan'};
  static Map<String, String> get announcements => {'en': 'Announcements', 'id': 'Pengumuman'};
  static Map<String, String> get studentAttendance => {'en': 'Student Attendance', 'id': 'Absensi Siswa'};
  static Map<String, String> get inputGrades => {'en': 'Grades', 'id': 'Nilai'};
  static Map<String, String> get teachingSchedule => {'en': 'Teaching Schedule', 'id': 'Jadwal Mengajar'};
  static Map<String, String> get classActivities => {'en': 'Class Activities', 'id': 'Kegiatan Kelas'};
  static Map<String, String> get lessonPlanLearningMaterials => {'en': 'Learning Materials', 'id': 'Materi Pembelajaran'};
  static Map<String, String> get myLessonPlans => {'en': 'My Lesson Plans', 'id': 'RPP Saya'};
  static Map<String, String> get manageLessonPlans => {'en': 'Manage Lesson Plans', 'id': 'Kelola RPP'};
  static Map<String, String> get tryAgain => {'en': 'Try Again', 'id': 'Coba Lagi'};
  static Map<String, String> get updateData => {'en': 'Update Data', 'id': 'Perbarui Data'};
  static Map<String, String> get selectClass => {'en': 'Select Class', 'id': 'Pilih Kelas'};
  static Map<String, String> get noAttendanceData => {'en': 'No attendance data for this period', 'id': 'Tidak ada data absensi untuk periode ini'};
  static Map<String, String> get allMonths => {'en': 'All Months', 'id': 'Semua Bulan'};
  static Map<String, String> get allTypes => {'en': 'All Types', 'id': 'Semua Jenis'};
  static Map<String, String> get bankTransfer => {'en': 'Bank Transfer', 'id': 'Transfer Bank'};
  static Map<String, String> get creditCard => {'en': 'Credit/Debit Card', 'id': 'Kartu Kredit/Debit'};
  static Map<String, String> get dateFormatHint => {'en': 'Format date: YYYY-MM-DD', 'id': 'Format tanggal: YYYY-MM-DD'};
  static Map<String, String> get close => {'en': 'Close', 'id': 'Tutup'};
  static Map<String, String> get adminRole => {'en': 'Admin', 'id': 'Admin'};
  static Map<String, String> get teacherRole => {'en': 'Teacher', 'id': 'Guru'};
  static Map<String, String> get staffRole => {'en': 'Staff', 'id': 'Staff'};
  static Map<String, String> get parentRole => {'en': 'Parent', 'id': 'Wali Murid'};
  static Map<String, String> get login => {'en': 'Login', 'id': 'Masuk'};
  static Map<String, String> get email => {'en': 'Email', 'id': 'Email'};
  static Map<String, String> get password => {'en': 'Password', 'id': 'Kata Sandi'};
  static Map<String, String> get forgotPassword => {'en': 'Forgot Password?', 'id': 'Lupa Kata Sandi?'};
  static Map<String, String> get loginSuccess => {'en': 'Login Successful', 'id': 'Login Berhasil'};
  static Map<String, String> get loginError => {'en': 'Login Failed', 'id': 'Login Gagal'};
  static Map<String, String> get confirmDelete => {'en': 'Confirm Delete', 'id': 'Konfirmasi Hapus'};
  static Map<String, String> get areYouSure => {'en': 'Are you sure?', 'id': 'Apakah Anda yakin?'};
  static Map<String, String> get name => {'en': 'Name', 'id': 'Nama'};
  static Map<String, String> get class_ => {'en': 'Class', 'id': 'Kelas'};
  static Map<String, String> get subject => {'en': 'Subject', 'id': 'Mata Pelajaran'};
  static Map<String, String> get teacher => {'en': 'Teacher', 'id': 'Guru'};
  static Map<String, String> get schedule => {'en': 'Schedule', 'id': 'Jadwal'};
  static Map<String, String> get success => {'en': 'Success', 'id': 'Berhasil'};
  static Map<String, String> get error => {'en': 'Error', 'id': 'Error'};
  static Map<String, String> get startTime => {'en': 'Start Time', 'id': 'Jam Mulai'};
  static Map<String, String> get endTime => {'en': 'End Time', 'id': 'Jam Selesai'};
  static Map<String, String> get day => {'en': 'Day', 'id': 'Hari'};

  // ── Lesson Plans (RPP) ──────────────────────────────────────────────────────
  // Data lives in language_utils_lesson_plans.dart (part of this library).
  static Map<String, String> get lessonPlan => _kLessonPlan;
  static Map<String, String> get lessonPlanList => _kLessonPlanList;
  static Map<String, String> get createLessonPlan => _kCreateLessonPlan;
  static Map<String, String> get editLessonPlan => _kEditLessonPlan;
  static Map<String, String> get status => _kStatus;
  static Map<String, String> get pending => _kPending;
  static Map<String, String> get approved => _kApproved;
  static Map<String, String> get rejected => _kRejected;
  static Map<String, String> get title => _kTitle;
  static Map<String, String> get academicTerm => _kAcademicTerm;
  static Map<String, String> get academicYear => _kAcademicYear;
  static Map<String, String> get coreCompetence => _kCoreCompetence;
  static Map<String, String> get basicCompetence => _kBasicCompetence;
  static Map<String, String> get indicators => _kIndicators;
  static Map<String, String> get learningObjectives => _kLearningObjectives;
  static Map<String, String> get learningMaterials => _kLearningMaterials;
  static Map<String, String> get learningMethods => _kLearningMethods;
  static Map<String, String> get mediaTools => _kMediaTools;
  static Map<String, String> get learningResources => _kLearningResources;
  static Map<String, String> get learningActivities => _kLearningActivities;
  static Map<String, String> get assessment => _kAssessment;
  static Map<String, String> get attachment => _kAttachment;
  static Map<String, String> get createNewLessonPlan => _kCreateNewLessonPlan;
  static Map<String, String> get viewLessonPlan => _kViewLessonPlan;
  static Map<String, String> get downloadLessonPlan => _kDownloadLessonPlan;
  static Map<String, String> get uploadFile => _kUploadFile;
  static Map<String, String> get chooseFile => _kChooseFile;
  static Map<String, String> get fileSelected => _kFileSelected;
  static Map<String, String> get noLessonPlanAvailable => _kNoLessonPlanAvailable;
  static Map<String, String> get lessonPlanCreatedSuccess => _kLessonPlanCreatedSuccess;
  static Map<String, String> get lessonPlanUpdatedSuccess => _kLessonPlanUpdatedSuccess;
  static Map<String, String> get lessonPlanDeletedSuccess => _kLessonPlanDeletedSuccess;
  static Map<String, String> get lessonPlanStatusUpdated => _kLessonPlanStatusUpdated;
  static Map<String, String> get fileUploadSuccess => _kFileUploadSuccess;
  static Map<String, String> get fileUploadError => _kFileUploadError;
  static Map<String, String> get invalidFileType => _kInvalidFileType;
  static Map<String, String> get fileTooLarge => _kFileTooLarge;
  static Map<String, String> get allLessonPlans => _kAllLessonPlans;
  static Map<String, String> get filterByStatus => _kFilterByStatus;
  static Map<String, String> get teacherName => _kTeacherName;
  static Map<String, String> get subjectName => _kSubjectName;
  static Map<String, String> get creationDate => _kCreationDate;
  static Map<String, String> get updateStatus => _kUpdateStatus;
  static Map<String, String> get adminNotes => _kAdminNotes;
  static Map<String, String> get notesOptional => _kNotesOptional;
  static Map<String, String> get approveLessonPlan => _kApproveLessonPlan;
  static Map<String, String> get rejectLessonPlan => _kRejectLessonPlan;
  static Map<String, String> get lessonPlanDetails => _kLessonPlanDetails;
  static Map<String, String> get basicInfo => _kBasicInfo;
  static Map<String, String> get learningComponents => _kLearningComponents;
  static Map<String, String> get assessmentMethods => _kAssessmentMethods;
  static Map<String, String> get noLessonPlanCreated => _kNoLessonPlanCreated;
  static Map<String, String> get clickPlusToCreate => _kClickPlusToCreate;
  static Map<String, String> get viewAndManageLessonPlans => _kViewAndManageLessonPlans;
  static Map<String, String> get noLessonPlanForFilter => _kNoLessonPlanForFilter;
  static Map<String, String> get titleRequired => _kTitleRequired;
  static Map<String, String> get subjectRequired => _kSubjectRequired;
  static Map<String, String> get academicTermRequired => _kAcademicTermRequired;
  static Map<String, String> get academicYearRequired => _kAcademicYearRequired;
  static Map<String, String> get wordDocument => _kWordDocument;
  static Map<String, String> get pdfDocument => _kPdfDocument;
  static Map<String, String> get supportedFormats => _kSupportedFormats;
  static Map<String, String> get selectAndOrganizeMaterials => _kSelectAndOrganizeMaterials;
  static Map<String, String> get presence => _kPresence;
  static Map<String, String> get billing => _kBilling;
  static Map<String, String> get materialsLabel => _kMaterialsLabel;

  // ── Parent Screens & Dashboard Statistics ───────────────────────────────────
  // Data lives in language_utils_parent_dashboard.dart (part of this library).
  static Map<String, String> get chooseLanguage => _kChooseLanguage;
  static Map<String, String> get totalStudents => _kTotalStudents;
  static Map<String, String> get totalTeachers => _kTotalTeachers;
  static Map<String, String> get totalClasses => _kTotalClasses;
  static Map<String, String> get switchRole => _kSwitchRole;
  static Map<String, String> get switchSchool => _kSwitchSchool;
  static Map<String, String> get registered => _kRegistered;
  static Map<String, String> get active => _kActive;
  static Map<String, String> get available => _kAvailable;
  static Map<String, String> get supervised => _kSupervised;
  static Map<String, String> get todaysClasses => _kTodaysClasses;
  static Map<String, String> get subjects => _kSubjects;
  static Map<String, String> get ongoing => _kOngoing;
  static Map<String, String> get submitted => _kSubmitted;
  static Map<String, String> get presenceReport => _kPresenceReport;
  static Map<String, String> get schoolSettings => _kSchoolSettings;
  static Map<String, String> get latestInfo => _kLatestInfo;
  static Map<String, String> get childrenData => _kChildrenData;
  static Map<String, String> get registeredChildren => _kRegisteredChildren;
  static Map<String, String> get grades => _kGrades;
  static Map<String, String> get noChildrenLinked => _kNoChildrenLinked;
  static Map<String, String> get selectChild => _kSelectChild;
  static Map<String, String> get nameNotAvailable => _kNameNotAvailable;
  static Map<String, String> get classString => _kClassString;
  static Map<String, String> get assessmentDate => _kAssessmentDate;
  static Map<String, String> get teacherNotes => _kTeacherNotes;
  static Map<String, String> get selectChildToViewGrades => _kSelectChildToViewGrades;
  static Map<String, String> get noGradesData => _kNoGradesData;
  static Map<String, String> get childAcademicGrades => _kChildAcademicGrades;
  static Map<String, String> get monitorChildGrades => _kMonitorChildGrades;
  static Map<String, String> get unknown => _kUnknown;
  static Map<String, String> get activityTitle => _kActivityTitle;
  static Map<String, String> get date => _kDate;
  static Map<String, String> get deadline => _kDeadline;
  static Map<String, String> get description => _kDescription;
  static Map<String, String> get chapterInfo => _kChapterInfo;
  static Map<String, String> get chapter => _kChapter;
  static Map<String, String> get mainSubChapter => _kMainSubChapter;
  static Map<String, String> get additionalSubChapter => _kAdditionalSubChapter;
  static Map<String, String> get selectChildToViewActivity => _kSelectChildToViewActivity;
  static Map<String, String> get noActivityForChild => _kNoActivityForChild;
  static Map<String, String> get childClassActivity => _kChildClassActivity;
  static Map<String, String> get monitorChildActivity => _kMonitorChildActivity;
  static Map<String, String> get assignment => _kAssignment;
  static Map<String, String> get material => _kMaterial;
  static Map<String, String> get myBills => _kMyBills;
  static Map<String, String> get manageBillPayments => _kManageBillPayments;
  static Map<String, String> get searchBills => _kSearchBills;
  static Map<String, String> get paymentStatus => _kPaymentStatus;
  static Map<String, String> get paid => _kPaid;
  static Map<String, String> get waitingForVerification => _kWaitingForVerification;
  static Map<String, String> get paymentPeriod => _kPaymentPeriod;
  static Map<String, String> get monthly => _kMonthly;
  static Map<String, String> get yearly => _kYearly;
  static Map<String, String> get filter => _kFilter;
  static Map<String, String> get apply => _kApply;
  static Map<String, String> get reset => _kReset;
  static Map<String, String> get chooseSource => _kChooseSource;
  static Map<String, String> get chooseImageSource => _kChooseImageSource;
  static Map<String, String> get gallery => _kGallery;
  static Map<String, String> get camera => _kCamera;
  static Map<String, String> get unsupportedFileFormat => _kUnsupportedFileFormat;
  static Map<String, String> get chooseFileType => _kChooseFileType;
  static Map<String, String> get imageCameraGallery => _kImageCameraGallery;
  static Map<String, String> get uploadPaymentProof => _kUploadPaymentProof;
  static Map<String, String> get billAmount => _kBillAmount;
  static Map<String, String> get student => _kStudent;
  static Map<String, String> get payNow => _kPayNow;
  static Map<String, String> get childPresence => _kChildPresence;
  static Map<String, String> get studentName => _kStudentName;
  static Map<String, String> get monthlyRecap => _kMonthlyRecap;
  static Map<String, String> get attendanceRate => _kAttendanceRate;
  static Map<String, String> get present => _kPresent;
  static Map<String, String> get late => _kLate;
  static Map<String, String> get permission => _kPermission;
  static Map<String, String> get sick => _kSick;
  static Map<String, String> get alpha => _kAlpha;
  static Map<String, String> get presenceHistory => _kPresenceHistory;
  static Map<String, String> get noPresenceData => _kNoPresenceData;
  static Map<String, String> get forMonth => _kForMonth;
  static Map<String, String> get loadingPresenceData => _kLoadingPresenceData;
  static Map<String, String> get financialManagement => _kFinancialManagement;
  static Map<String, String> get dashboard => _kDashboard;
  static Map<String, String> get paymentTypes => _kPaymentTypes;
  static Map<String, String> get verification => _kVerification;
  static Map<String, String> get monthlyIncome => _kMonthlyIncome;
  static Map<String, String> get pendingVerification => _kPendingVerification;
  static Map<String, String> get unpaid => _kUnpaid;
  static Map<String, String> get verified => _kVerified;
  static Map<String, String> get addPaymentType => _kAddPaymentType;
  static Map<String, String> get editPaymentType => _kEditPaymentType;
  static Map<String, String> get deletePaymentType => _kDeletePaymentType;
  static Map<String, String> get paymentsPendingVerification => _kPaymentsPendingVerification;
  static Map<String, String> get classReport => _kClassReport;
  static Map<String, String> get students => _kStudents;

  // ── Settings, Auth/Login, Navigation, Notifications, Generic Patterns ────────
  // Data lives in language_utils_settings_auth.dart (part of this library).
  static Map<String, String> get settingsMenu => _kSettingsMenu;
  static Map<String, String> get generalSettings => _kGeneralSettings;
  static Map<String, String> get timeSettings => _kTimeSettings;
  static Map<String, String> get userProfile => _kUserProfile;
  static Map<String, String> get personalInformation => _kPersonalInformation;
  static Map<String, String> get accountInformation => _kAccountInformation;
  static Map<String, String> get fullName => _kFullName;
  static Map<String, String> get phoneNumber => _kPhoneNumber;
  static Map<String, String> get address => _kAddress;
  static Map<String, String> get role => _kRole;
  static Map<String, String> get school => _kSchool;
  static Map<String, String> get editProfile => _kEditProfile;
  static Map<String, String> get changePassword => _kChangePassword;
  static Map<String, String> get oldPassword => _kOldPassword;
  static Map<String, String> get newPassword => _kNewPassword;
  static Map<String, String> get confirmPassword => _kConfirmPassword;
  static Map<String, String> get passwordMismatch => _kPasswordMismatch;
  static Map<String, String> get passwordMinLength => _kPasswordMinLength;
  static Map<String, String> get passwordLetters => _kPasswordLetters;
  static Map<String, String> get passwordNumbers => _kPasswordNumbers;
  static Map<String, String> get passwordSymbols => _kPasswordSymbols;
  static Map<String, String> get required => _kRequired;
  static Map<String, String> get profileUpdatedSuccess => _kProfileUpdatedSuccess;
  static Map<String, String> get passwordChangedSuccess => _kPasswordChangedSuccess;
  static Map<String, String> get failedToLoadProfile => _kFailedToLoadProfile;
  static Map<String, String> get failedToUpdateProfile => _kFailedToUpdateProfile;
  static Map<String, String> get failedToChangePassword => _kFailedToChangePassword;
  static Map<String, String> get quickAccess => _kQuickAccess;
  static Map<String, String> get todaysOverview => _kTodaysOverview;
  static Map<String, String> get menu => _kMenu;
  static Map<String, String> get goodMorning => _kGoodMorning;
  static Map<String, String> get goodAfternoon => _kGoodAfternoon;
  static Map<String, String> get goodEvening => _kGoodEvening;
  static Map<String, String> get data => _kData;
  static Map<String, String> get attendance => _kAttendance;
  static Map<String, String> get activity => _kActivity;
  static Map<String, String> get activeTeachers => _kActiveTeachers;
  static Map<String, String> get currentlyTeaching => _kCurrentlyTeaching;
  static Map<String, String> get recentUpdates => _kRecentUpdates;
  static Map<String, String> get myChildren => _kMyChildren;
  static Map<String, String> get registeredStudents => _kRegisteredStudents;
  static Map<String, String> get newGrades => _kNewGrades;
  static Map<String, String> get newRecords => _kNewRecords;
  static Map<String, String> get latestInformation => _kLatestInformation;
  static Map<String, String> get childAttendance => _kChildAttendance;
  static Map<String, String> get categoryDataManagement => _kCategoryDataManagement;
  static Map<String, String> get categoryAcademicCommunication => _kCategoryAcademicCommunication;
  static Map<String, String> get categoryFinanceSettings => _kCategoryFinanceSettings;
  static Map<String, String> get categoryTeaching => _kCategoryTeaching;
  static Map<String, String> get categoryAssessmentPlanning => _kCategoryAssessmentPlanning;
  static Map<String, String> get manageData => _kManageData;
  static Map<String, String> get studentReport => _kStudentReport;
  static Map<String, String> get gradeRecap => _kGradeRecap;
  static Map<String, String> get reportCard => _kReportCard;
  static Map<String, String> get learningRecommendation => _kLearningRecommendation;
  static Map<String, String> get eReportCard => _kEReportCard;
  static Map<String, String> get selectSchool => _kSelectSchool;
  static Map<String, String> get verify => _kVerify;
  static Map<String, String> get regenerate => _kRegenerate;
  static Map<String, String> get regenerateAll => _kRegenerateAll;
  static Map<String, String> get unsavedChanges => _kUnsavedChanges;
  static Map<String, String> get unsavedChangesConfirm => _kUnsavedChangesConfirm;
  static Map<String, String> get leave => _kLeave;
  static Map<String, String> get deleteMaterial => _kDeleteMaterial;
  static Map<String, String> get deleteColumnConfirm => _kDeleteColumnConfirm;
  static Map<String, String> get removeClass => _kRemoveClass;
  static Map<String, String> get sendReportCard => _kSendReportCard;
  static Map<String, String> get sendReportCardConfirm => _kSendReportCardConfirm;
  static Map<String, String> get yesSend => _kYesSend;
  static Map<String, String> get finalizeReportCard => _kFinalizeReportCard;
  static Map<String, String> get finalizeReportCardConfirm => _kFinalizeReportCardConfirm;
  static Map<String, String> get yesFinalize => _kYesFinalize;
  static Map<String, String> get achievements => _kAchievements;
  static Map<String, String> get failedToSave => _kFailedToSave;
  static Map<String, String> get settingsSavedSuccess => _kSettingsSavedSuccess;
  static Map<String, String> get schoolNameMinChars => _kSchoolNameMinChars;
  static Map<String, String> get enterOtp => _kEnterOtp;
  static Map<String, String> get serverNotConnected => _kServerNotConnected;
  static Map<String, String> get emailPasswordNotEmpty => _kEmailPasswordNotEmpty;
  static Map<String, String> get emailInvalid => _kEmailInvalid;
  static Map<String, String> get accountNotRegistered => _kAccountNotRegistered;
  static Map<String, String> get accountNotRegisteredMsg => _kAccountNotRegisteredMsg;
  static Map<String, String> get selectRole => _kSelectRole;
  static Map<String, String> get selectRoleMsg => _kSelectRoleMsg;
  static Map<String, String> get selectSchoolMsg => _kSelectSchoolMsg;
  static Map<String, String> get understand => _kUnderstand;
  static Map<String, String> get loginFailed => _kLoginFailed;
  static Map<String, String> get backToLogin => _kBackToLogin;
  static Map<String, String> get continueText => _kContinueText;
  static Map<String, String> get verifyFailed => _kVerifyFailed;
  static Map<String, String> get otpVerification => _kOtpVerification;
  static Map<String, String> get otpSentToEmail => _kOtpSentToEmail;
  static Map<String, String> get enterOtpDigits => _kEnterOtpDigits;
  static Map<String, String> get otpCode => _kOtpCode;
  static Map<String, String> get pleaseWait => _kPleaseWait;
  static Map<String, String> get signInWithGoogle => _kSignInWithGoogle;
  static Map<String, String> get schoolNoName => _kSchoolNoName;
  static Map<String, String> get accessAs => _kAccessAs;
  static Map<String, String> get roleDescAdmin => _kRoleDescAdmin;
  static Map<String, String> get roleDescTeacher => _kRoleDescTeacher;
  static Map<String, String> get roleDescParent => _kRoleDescParent;
  static Map<String, String> get roleDescStaff => _kRoleDescStaff;
  static Map<String, String> get roleDescDefault => _kRoleDescDefault;
  static Map<String, String> get hello => _kHello;
  static Map<String, String> get schoolLabel => _kSchoolLabel;
  static Map<String, String> get authAccountNotRegisteredInAnySchool => _kAuthAccountNotRegisteredInAnySchool;
  static Map<String, String> get authRolesNotAvailable => _kAuthRolesNotAvailable;
  static Map<String, String> get authIncompleteLoginData => _kAuthIncompleteLoginData;
  static Map<String, String> get authUserRoleNotFound => _kAuthUserRoleNotFound;
  static Map<String, String> get authInvalidCredentials => _kAuthInvalidCredentials;
  static Map<String, String> get googleSignInError => _kGoogleSignInError;
  static Map<String, String> get information => _kInformation;
  static Map<String, String> get ok => _kOk;
  static Map<String, String> get selectAcademicYear => _kSelectAcademicYear;
  static Map<String, String> get schoolSwitched => _kSchoolSwitched;
  static Map<String, String> get classNotAvailable => _kClassNotAvailable;
  static Map<String, String> get noStudentLinked => _kNoStudentLinked;
  static Map<String, String> get errorAdminIdNotFound => _kErrorAdminIdNotFound;
  static Map<String, String> get errorTeacherIdNotFound => _kErrorTeacherIdNotFound;
  static Map<String, String> get noNotifications => _kNoNotifications;
  static Map<String, String> get allNotificationsWillAppear => _kAllNotificationsWillAppear;
  static Map<String, String> get justNow => _kJustNow;
  static Map<String, String> get minutesAgo => _kMinutesAgo;
  static Map<String, String> get hoursAgo => _kHoursAgo;
  static Map<String, String> get daysAgo => _kDaysAgo;
  static Map<String, String> get failedToLoad => _kFailedToLoad;
  static Map<String, String> get failedToDelete => _kFailedToDelete;
  static Map<String, String> get failedToExport => _kFailedToExport;
  static Map<String, String> get failedToImport => _kFailedToImport;
  static Map<String, String> get failedToGenerate => _kFailedToGenerate;
  static Map<String, String> get failedToUpdate => _kFailedToUpdate;
  static Map<String, String> get failedToVerify => _kFailedToVerify;
  static Map<String, String> get failedToDownload => _kFailedToDownload;
  static Map<String, String> get failedToOpenFile => _kFailedToOpenFile;
  static Map<String, String> get failedToProcess => _kFailedToProcess;
  static Map<String, String> get failedToLoadInitialData => _kFailedToLoadInitialData;
  static Map<String, String> get failedToLoadDetail => _kFailedToLoadDetail;
  static Map<String, String> get failedToLoadImage => _kFailedToLoadImage;
  static Map<String, String> get failedToLoadSchedule => _kFailedToLoadSchedule;
  static Map<String, String> get failedToLoadTeacherSubjects => _kFailedToLoadTeacherSubjects;
  static Map<String, String> get failedToCreatePdfPreview => _kFailedToCreatePdfPreview;
  static Map<String, String> get failedToGetJobId => _kFailedToGetJobId;
  static Map<String, String> get dataSavedSuccessfully => _kDataSavedSuccessfully;
  static Map<String, String> get downloadSuccessful => _kDownloadSuccessful;
  static Map<String, String> get fileSavedSuccessfully => _kFileSavedSuccessfully;
  static Map<String, String> get noDataToExport => _kNoDataToExport;
  static Map<String, String> get noStudentsFoundForCriteria => _kNoStudentsFoundForCriteria;
  static Map<String, String> get noStudentsMatchSearch => _kNoStudentsMatchSearch;
  static Map<String, String> get noPaymentProof => _kNoPaymentProof;
  static Map<String, String> get noTeachingSubjects => _kNoTeachingSubjects;
  static Map<String, String> get noClassesForSubject => _kNoClassesForSubject;
  static Map<String, String> get noActiveClasses => _kNoActiveClasses;
  static Map<String, String> get noChapters => _kNoChapters;
  static Map<String, String> get noStudentsInClass => _kNoStudentsInClass;
  static Map<String, String> get noAnnouncementsMatchSearch => _kNoAnnouncementsMatchSearch;
  static Map<String, String> get noAnnouncementsAvailable => _kNoAnnouncementsAvailable;
  static Map<String, String> get failedToLoadReportCard => _kFailedToLoadReportCard;
  static Map<String, String> get failedToSaveReportCard => _kFailedToSaveReportCard;
  static Map<String, String> get failedToLoadMaterial => _kFailedToLoadMaterial;
  static Map<String, String> get paymentRecordedSuccessfully => _kPaymentRecordedSuccessfully;
  static Map<String, String> get paymentCancelled => _kPaymentCancelled;
  static Map<String, String> get paymentVerifiedSuccessfully => _kPaymentVerifiedSuccessfully;
  static Map<String, String> get paymentRejectedSuccessfully => _kPaymentRejectedSuccessfully;
  static Map<String, String> get gradeRecapSaved => _kGradeRecapSaved;
  static Map<String, String> get lessonPlanRegeneratedSuccessfully => _kLessonPlanRegeneratedSuccessfully;
  static Map<String, String> get lessonPlanSavedSuccessfully => _kLessonPlanSavedSuccessfully;
  static Map<String, String> get lessonPlanExportedToText => _kLessonPlanExportedToText;
  static Map<String, String> get lessonPlanCopiedToClipboard => _kLessonPlanCopiedToClipboard;
  static Map<String, String> get fieldRegeneratedSuccessfully => _kFieldRegeneratedSuccessfully;
  static Map<String, String> get failedExceededLimit => _kFailedExceededLimit;
  static Map<String, String> get lessonPlanAiGeneratedDescription => _kLessonPlanAiGeneratedDescription;
  static Map<String, String> get failedToGenerateLessonPlan => _kFailedToGenerateLessonPlan;
  static Map<String, String> get failedToGenerateMaterial => _kFailedToGenerateMaterial;
  static Map<String, String> get noGradeDataFound => _kNoGradeDataFound;
  static Map<String, String> get failedToRegenerateLessonPlan => _kFailedToRegenerateLessonPlan;
}

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
