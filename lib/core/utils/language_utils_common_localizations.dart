// Part of the AppLocalizations API — common strings that reference other part
// files and extension for applying translations.
part of 'language_utils.dart';

/// Extension of [AppLocalizations] with remaining translation categories.
/// Includes: Lesson Plans (RPP), Parent Screens & Dashboard Statistics,
/// Settings, Auth/Login, Navigation, Notifications, Generic Patterns.
extension AppLocalizationsCommonExtension on AppLocalizations {
  // ── Lesson Plans (RPP) ──────────────────────────────────────────────────
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
  static Map<String, String> get noLessonPlanAvailable =>
      _kNoLessonPlanAvailable;
  static Map<String, String> get lessonPlanCreatedSuccess =>
      _kLessonPlanCreatedSuccess;
  static Map<String, String> get lessonPlanUpdatedSuccess =>
      _kLessonPlanUpdatedSuccess;
  static Map<String, String> get lessonPlanDeletedSuccess =>
      _kLessonPlanDeletedSuccess;
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
  static Map<String, String> get viewAndManageLessonPlans =>
      _kViewAndManageLessonPlans;
  static Map<String, String> get noLessonPlanForFilter =>
      _kNoLessonPlanForFilter;
  static Map<String, String> get titleRequired => _kTitleRequired;
  static Map<String, String> get subjectRequired => _kSubjectRequired;
  static Map<String, String> get academicTermRequired => _kAcademicTermRequired;
  static Map<String, String> get academicYearRequired => _kAcademicYearRequired;
  static Map<String, String> get wordDocument => _kWordDocument;
  static Map<String, String> get supportedFormats => _kSupportedFormats;
  static Map<String, String> get selectAndOrganizeMaterials =>
      _kSelectAndOrganizeMaterials;
  static Map<String, String> get materialsLabel => _kMaterialsLabel;

  // ── Parent Screens & Dashboard Statistics ───────────────────────────────
  // Data lives in language_utils_parent_dashboard.dart (part of this
  // library).
  static Map<String, String> get totalStudents => _kTotalStudents;
  static Map<String, String> get totalTeachers => _kTotalTeachers;
  static Map<String, String> get totalClasses => _kTotalClasses;
  static Map<String, String> get registered => _kRegistered;
  static Map<String, String> get active => _kActive;
  static Map<String, String> get available => _kAvailable;
  static Map<String, String> get supervised => _kSupervised;
  static Map<String, String> get todaysClasses => _kTodaysClasses;
  static Map<String, String> get subjects => _kSubjects;
  static Map<String, String> get ongoing => _kOngoing;
  static Map<String, String> get submitted => _kSubmitted;
  static Map<String, String> get latestInfo => _kLatestInfo;
  static Map<String, String> get childrenData => _kChildrenData;
  static Map<String, String> get registeredChildren => _kRegisteredChildren;
  static Map<String, String> get grades => _kGrades;
  static Map<String, String> get assessmentDate => _kAssessmentDate;
  static Map<String, String> get teacherNotes => _kTeacherNotes;
  static Map<String, String> get noGradesData => _kNoGradesData;
  static Map<String, String> get date => _kDate;
  static Map<String, String> get chapterInfo => _kChapterInfo;
  static Map<String, String> get chapter => _kChapter;
  static Map<String, String> get mainSubChapter => _kMainSubChapter;
  static Map<String, String> get myBills => _kMyBills;
  static Map<String, String> get manageBillPayments => _kManageBillPayments;
  static Map<String, String> get searchBills => _kSearchBills;
  static Map<String, String> get paymentStatus => _kPaymentStatus;
  static Map<String, String> get paid => _kPaid;
  static Map<String, String> get waitingForVerification =>
      _kWaitingForVerification;
  static Map<String, String> get paymentPeriod => _kPaymentPeriod;
  static Map<String, String> get monthly => _kMonthly;
  static Map<String, String> get yearly => _kYearly;
  static Map<String, String> get filter => _kFilter;
  static Map<String, String> get apply => _kApply;
  static Map<String, String> get reset => _kReset;
  static Map<String, String> get unsupportedFileFormat =>
      _kUnsupportedFileFormat;
  static Map<String, String> get student => _kStudent;
  static Map<String, String> get payNow => _kPayNow;
  static Map<String, String> get childPresence => _kChildPresence;
  static Map<String, String> get studentName => _kStudentName;
  static Map<String, String> get monthlyRecap => _kMonthlyRecap;
  static Map<String, String> get attendanceRate => _kAttendanceRate;
  static Map<String, String> get presenceHistory => _kPresenceHistory;
  static Map<String, String> get noPresenceData => _kNoPresenceData;
  static Map<String, String> get forMonth => _kForMonth;
  static Map<String, String> get loadingPresenceData => _kLoadingPresenceData;
  static Map<String, String> get financialManagement => _kFinancialManagement;
  static Map<String, String> get monthlyIncome => _kMonthlyIncome;
  static Map<String, String> get pendingVerification => _kPendingVerification;
  static Map<String, String> get deletePaymentType => _kDeletePaymentType;

  // ── Settings, Auth/Login, Navigation, Notifications, Generic Patterns ──
  // Data lives in language_utils_settings_auth_profile.dart and
  // language_utils_settings_auth_misc.dart (parts of this library).
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
  static Map<String, String> get passwordChanged => _kPasswordChanged;
  static Map<String, String> get passwordChangeFailed => _kPasswordChangeFailed;
  static Map<String, String> get invalidPassword => _kInvalidPassword;
  static Map<String, String> get passwordTooShort => _kPasswordTooShort;
  static Map<String, String> get passwordMismatch => _kPasswordMismatch;
  static Map<String, String> get chooseLanguageTitle => _kChooseLanguageTitle;
  static Map<String, String> get english => _kEnglish;
  static Map<String, String> get indonesian => _kIndonesian;
  static Map<String, String> get selectTheme => _kSelectTheme;
  static Map<String, String> get lightTheme => _kLightTheme;
  static Map<String, String> get darkTheme => _kDarkTheme;
  static Map<String, String> get about => _kAbout;
  static Map<String, String> get version => _kVersion;
  static Map<String, String> get helpAndSupport => _kHelpAndSupport;
  static Map<String, String> get privacyPolicy => _kPrivacyPolicy;
  static Map<String, String> get termsAndConditions => _kTermsAndConditions;
  static Map<String, String> get feedback => _kFeedback;
  static Map<String, String> get feedbackSent => _kFeedbackSent;
  static Map<String, String> get feedbackSentError => _kFeedbackSentError;
  static Map<String, String> get enterYourFeedback => _kEnterYourFeedback;
  static Map<String, String> get send => _kSend;
  static Map<String, String> get notification => _kNotification;
  static Map<String, String> get notifications => _kNotifications;
  static Map<String, String> get enableNotifications => _kEnableNotifications;
  static Map<String, String> get noNotifications => _kNoNotifications;
  static Map<String, String> get invalidEmail => _kInvalidEmail;
  static Map<String, String> get emailRequired => _kEmailRequired;
  static Map<String, String> get passwordRequired => _kPasswordRequired;
  static Map<String, String> get nameRequired => _kNameRequired;
  static Map<String, String> get fieldRequired => _kFieldRequired;
  static Map<String, String> get required => _kRequired;
  static Map<String, String> get optional => _kOptional;
  static Map<String, String> get yes => _kYes;
  static Map<String, String> get no => _kNo;
  static Map<String, String> get dataSavedSuccessfully =>
      _kDataSavedSuccessfully;
  static Map<String, String> get noStudentsFoundForCriteria =>
      _kNoStudentsFoundForCriteria;
  static Map<String, String> get noTeachingSubjects => _kNoTeachingSubjects;
  static Map<String, String> get noClassesForSubject => _kNoClassesForSubject;
  static Map<String, String> get noActiveClasses => _kNoActiveClasses;
  static Map<String, String> get noChapters => _kNoChapters;
  static Map<String, String> get noStudentsInClass => _kNoStudentsInClass;
  static Map<String, String> get noAnnouncementsMatchSearch =>
      _kNoAnnouncementsMatchSearch;
  static Map<String, String> get noAnnouncementsAvailable =>
      _kNoAnnouncementsAvailable;
  static Map<String, String> get failedToSaveReportCard =>
      _kFailedToSaveReportCard;
  static Map<String, String> get failedToLoadMaterial => _kFailedToLoadMaterial;
  static Map<String, String> get failedToGenerateMaterial =>
      _kFailedToGenerateMaterial;
  static Map<String, String> get justNow => _kJustNow;
  static Map<String, String> get minutesAgo => _kMinutesAgo;
  static Map<String, String> get hoursAgo => _kHoursAgo;
  static Map<String, String> get daysAgo => _kDaysAgo;
  static Map<String, String> get allNotificationsWillAppear =>
      _kAllNotificationsWillAppear;
  static Map<String, String> get failedToSave => _kFailedToSave;
  static Map<String, String> get unsavedChanges => _kUnsavedChanges;
  static Map<String, String> get unsavedChangesConfirm =>
      _kUnsavedChangesConfirm;
  static Map<String, String> get leave => _kLeave;
  static Map<String, String> get failedToLoadDetail => _kFailedToLoadDetail;
  static Map<String, String> get finalizeReportCard => _kFinalizeReportCard;
  static Map<String, String> get finalizeReportCardConfirm =>
      _kFinalizeReportCardConfirm;
  static Map<String, String> get yesFinalize => _kYesFinalize;
  static Map<String, String> get achievements => _kAchievements;
  static Map<String, String> get failedToImport => _kFailedToImport;
  static Map<String, String> get failedToLoadInitialData =>
      _kFailedToLoadInitialData;
  static Map<String, String> get failedToProcess => _kFailedToProcess;
}
